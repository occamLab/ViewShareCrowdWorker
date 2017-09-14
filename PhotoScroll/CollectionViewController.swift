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
  var auth: Auth?
  var authUI: FUIAuth?
  var clockOffset: Double?
  var conn: Database?
  
  func authUI(_ authUI: FUIAuth, didSignInWith user: User?, error: Error?) {
    if error != nil {
      //Problem signing in
      login()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    conn = Database.database()
    self.auth = Auth.auth()
    self.authUI = FUIAuth.defaultAuthUI()
    // TODO: need to make a signout button with the code below
    // try! Auth.auth().signOut()
    checkLoggedIn()
    let offsetRef = conn?.reference(withPath: ".info/serverTimeOffset")
    offsetRef?.observeSingleEvent(of: DataEventType.value, with: { (snapshot) in
      self.clockOffset = snapshot.value as? Double
      // get the pending assignments
      self.conn?.reference(withPath: "/notification_tokens/" + (Auth.auth().currentUser?.uid)! + "/assignments").observe(DataEventType.childAdded, with: { (snapshot) in
        let jobUUID = snapshot.key
        let childVals = snapshot.value as! NSDictionary
        let objectToFind = childVals["object_to_find"]
        let creationTime = childVals["creation_timestamp"] as! Int
        let imageRef = Storage.storage().reference(withPath: jobUUID + ".jpg")
        // Download in memory with a maximum allowed size of 1MB (1 * 1024 * 1024 bytes)
        let estimatedServerTimeMs = NSDate().timeIntervalSince1970 * 1000.0 + self.clockOffset!
        if estimatedServerTimeMs - Double(creationTime) > 120*1000 {
          // too old
          self.conn?.reference().child("notification_tokens/" + (Auth.auth().currentUser?.uid)! + "/assignments/" + jobUUID).removeValue()
          return
        }
        imageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
          if error == nil {
            let image = UIImage(data: data!)
            self.photos.append(["jobUUID": jobUUID, "image": image!, "object_to_find": objectToFind, "creation_timestamp": creationTime]);
            self.collectionView?.reloadData()
          }
        }
      })
    })
    
    conn?.reference().child("/notification_tokens/" + (Auth.auth().currentUser?.uid)! + "/assignments").observe(DataEventType.childRemoved, with: { (snapshot) in
      // TODO: not sure this is threadsafe
      self.photos = self.photos.filter { ($0 as! NSDictionary)["jobUUID"] as! String != snapshot.key }
      self.collectionView?.reloadData()
    })
  }

  override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
    let estimatedServerTimeMs = NSDate().timeIntervalSince1970 * 1000.0 + self.clockOffset!
    if let cell = sender as? PhotoCell {
      if estimatedServerTimeMs - Double(cell.creationTimeStamp) > 120*1000 {
        // too old
        self.conn?.reference().child("notification_tokens/" + (Auth.auth().currentUser?.uid)! + "/assignments/" + cell.jobUUID).removeValue()
        return false
      }
    }
    return true
  }
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let cell = sender as? PhotoCell,
      let zoomedPhotoViewController = segue.destination as? ZoomedPhotoViewController {
      zoomedPhotoViewController.imageToLoad = cell.fullSizedImage
      zoomedPhotoViewController.objectToFind = cell.objectToFind
      zoomedPhotoViewController.labelingJob = cell.jobUUID
    }
  }

  func login() {
    authUI?.delegate = self
    authUI?.providers = [FUIPhoneAuth(authUI:authUI!)]
    let authViewController = authUI?.authViewController()
    self.present(authViewController!, animated: true, completion: nil)
  }
  
  func checkLoggedIn() {
    Auth.auth().addStateDidChangeListener { auth, user in
      if user != nil {
        // User is signed in.
        self.conn?.reference().child("/notification_tokens/" + user!.uid).child(Messaging.messaging().fcmToken!).setValue(true)
      } else {
        // No user is signed in.
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
    print("Getting count!", photos.count)
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
