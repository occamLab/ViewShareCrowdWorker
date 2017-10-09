/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import Firebase
import FirebaseAuth
import FirebaseAuthUI
import FirebasePhoneAuthUI

class CollectionViewController: UICollectionViewController, FUIAuthDelegate {
  fileprivate let reuseIdentifier = "PhotoCell"
  fileprivate let thumbnailSize = CGSize(width: 70.0, height: 70.0)
  fileprivate let sectionInsets = UIEdgeInsets(top: 10, left: 5.0, bottom: 10.0, right: 5.0)

  fileprivate var photos = [] as Array
  @IBOutlet weak var logoutButton: UIBarButtonItem!
  var auth: Auth?
  var authUI: FUIAuth?
  var clockOffset: Double?
  var userAssignmentsRef: DatabaseReference?
  
  func authUI(_ authUI: FUIAuth, didSignInWith user: User?, error: Error?) {
    if error != nil {
      //Problem signing in
      login()
    }
  }
  
  @IBAction func handleSelect(_ sender: Any) {
    try! Auth.auth().signOut()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.auth = Auth.auth()
    self.authUI = FUIAuth.defaultAuthUI()
    registerForLoginCallbacks()
    
    if auth?.currentUser == nil {
      login()
    }
  }

  override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
    let estimatedServerTimeMs = NSDate().timeIntervalSince1970 * 1000.0 + self.clockOffset!
    if let cell = sender as? PhotoCell {
      if estimatedServerTimeMs - Double(cell.creationTimeStamp) > 120*1000 {
        // too old
        Database.database().reference().child("notification_tokens/" + (Auth.auth().currentUser?.uid)! + "/assignments/" + cell.jobUUID).removeValue()
        return false
      }
    }
    return true
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let cell = sender as? PhotoCell,
      let zoomedPhotoViewController = segue.destination as? ZoomedPhotoViewController {
      zoomedPhotoViewController.imagesForJob[0] = LabelingImage(image: cell.fullSizedImage, imageUUID: cell.jobUUID)
      zoomedPhotoViewController.objectToFind = cell.objectToFind
      zoomedPhotoViewController.labelingJob = cell.jobUUID
      zoomedPhotoViewController.requestingUser = cell.requestingUser
    }
  }

  func login() {
    authUI?.delegate = self
    authUI?.providers = [FUIPhoneAuth(authUI:authUI!)]
    let authViewController = authUI?.authViewController()
    self.present(authViewController!, animated: true, completion: nil)
  }
  
  func registerForLoginCallbacks() {
    Auth.auth().addStateDidChangeListener { auth, user in
      if user != nil {
        // User is signed in.
        Database.database().reference(withPath: "/account_mapping/" + Messaging.messaging().fcmToken!).observeSingleEvent(of: DataEventType.value, with: { (snapshot) in
          if snapshot.exists() {
            Database.database().reference(withPath: "/notification_tokens/" + (snapshot.value as! String) + "/" + Messaging.messaging().fcmToken!).removeValue()
          }
          // grab ownership of the token
          Database.database().reference(withPath: "/account_mapping/" + Messaging.messaging().fcmToken!).setValue(user!.uid)
          Database.database().reference(withPath: "/notification_tokens/" + user!.uid + "/" + Messaging.messaging().fcmToken!).setValue(true)
        });

        self.userAssignmentsRef = Database.database().reference(withPath: "/notification_tokens/" + user!.uid + "/assignments")
        let offsetRef = Database.database().reference(withPath: ".info/serverTimeOffset")
        offsetRef.observeSingleEvent(of: DataEventType.value, with: { (snapshot) in
          self.clockOffset = snapshot.value as? Double
          // get the pending assignments
          self.userAssignmentsRef!.observe(DataEventType.childAdded, with: { (snapshot) in
            let jobUUID = snapshot.key
            let childVals = snapshot.value as! NSDictionary
            let objectToFind = childVals["object_to_find"]
            let requestingUser = childVals["requesting_user"]
            let creationTime = childVals["creation_timestamp"] as! Int
            let imageRef = Storage.storage().reference(withPath: jobUUID + ".jpg")
            // Download in memory with a maximum allowed size of 1MB (1 * 1024 * 1024 bytes)
            let estimatedServerTimeMs = NSDate().timeIntervalSince1970 * 1000.0 + self.clockOffset!
            if estimatedServerTimeMs - Double(creationTime) > 120*1000 {
              // too old
              Database.database().reference().child("notification_tokens/" + (Auth.auth().currentUser?.uid)! + "/assignments/" + jobUUID).removeValue()
              return
            }
            imageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
              if error == nil {
                let image = UIImage(data: data!)
                self.photos.append(["jobUUID": jobUUID, "image": image!, "object_to_find": objectToFind, "creation_timestamp": creationTime, "requesting_user": requestingUser]);
                self.collectionView?.reloadData()
              }
            }
          })
        })
        
        self.userAssignmentsRef!.observe(DataEventType.childRemoved, with: { (snapshot) in
          // TODO: not sure this is threadsafe
          self.photos = self.photos.filter { ($0 as! NSDictionary)["jobUUID"] as! String != snapshot.key }
          self.collectionView?.reloadData()
        })
      } else {
        // No user is signed in.  Cleanup any old observers and then login
        self.userAssignmentsRef?.removeAllObservers()
        // make sure to get rid of all of the photos we may have loaded previously
        self.photos = []
        self.collectionView?.reloadData()
        self.login()
      }
    }
  }
}

// MARK: UICollectionViewDataSource
extension CollectionViewController {
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return photos.count
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PhotoCell
    let cellData = photos[indexPath.row] as! NSDictionary
    cell.fullSizedImage = cellData["image"] as! UIImage
    cell.imageView.image = cell.fullSizedImage.thumbnailOfSize(thumbnailSize)
    cell.objectToFind = cellData["object_to_find"] as! String
    cell.jobUUID = cellData["jobUUID"] as! String
    cell.creationTimeStamp = cellData["creation_timestamp"] as! Int
    cell.requestingUser = cellData["requesting_user"] as! String
    cell.indexPath = indexPath
    // todo: need to store this somehow
    return cell
  }
}

// MARK:UICollectionViewDelegateFlowLayout
extension CollectionViewController : UICollectionViewDelegateFlowLayout {
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    return thumbnailSize
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return sectionInsets
  }
}
