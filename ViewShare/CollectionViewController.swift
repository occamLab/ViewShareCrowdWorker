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
import FirebaseUI


/// The purpose of the `CollectionViewController` class is to provide an interface where a user can view available jobs and to handle signing in with FirebaseAuth.
class CollectionViewController: UICollectionViewController, FUIAuthDelegate {
  
  /// Not sure yet what reuseIdentifier actually does
  fileprivate let reuseIdentifier = "PhotoCell"
  
  /// Defines the size of a thumbnail
  fileprivate let thumbnailSize = CGSize(width: 70.0, height: 70.0)
  
  /// Defines the margins of the thumbnails
  fileprivate let sectionInsets = UIEdgeInsets(top: 10, left: 5.0, bottom: 10.0, right: 5.0)

  /// Declare array of photos, corresponding to a job. Each element will be a dictionary containing the UUID of the job, an image, the object to find, the timestamp, and the ID of the requester.
  fileprivate var photos = [] as Array
  
  @IBOutlet weak var logoutButton: UIBarButtonItem!
  
  /// This is something related to Firebase and I am unsure what it is.
  ///
  /// - TODO: Clarify/understand
  var auth: Auth?
  
  /// This is something related to Firebase and I am unsure what it is.
  ///
  /// - TODO: Clarify/understand
  var authUI: FUIAuth?
  
  /// I am unsure what this is.
  ///
  /// - TODO: Clarify/understand
  var clockOffset: Double?
  
  /// I am unsure what this is.
  ///
  /// - TODO: Clarify/understand
  var userAssignmentsRef: DatabaseReference?
  
  /// Reloads the login UI if there was a problem signing in
  ///
  /// - Parameters:
  ///   - authUI: Firebase view controller for login
  ///   - user: Firebase auth user
  ///   - error: Error that occurred
  func authUI(_ authUI: FUIAuth, didSignInWith user: User?, error: Error?) {
    if error != nil {
      //Problem signing in
      print("ERROR is not nil", error!)
      login()
    }
  }
  
  /// Triggers log out with Firebase Auth
  ///
  /// - Parameter sender: The logout button in the toolbar
  @IBAction func handleSelect(_ sender: Any) {
    try! Auth.auth().signOut()
  }

  
  
  /// Add Firebase configuration and call `registerForLoginCallbacks()`
  override func viewDidLoad() {
    super.viewDidLoad()
    self.auth = Auth.auth()
    self.authUI = FUIAuth.defaultAuthUI()
    self.authUI?.delegate = self
    let providers: [FUIAuthProvider] = [
      FUIPhoneAuth.init(authUI: FUIAuth.defaultAuthUI()!)
      ]
    self.authUI?.providers = providers
    registerForLoginCallbacks()
  }
  
  /// If user is not logged in, call `login()`
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    if auth?.currentUser == nil {
      login()
    }
  }

  /// Determines whether to open a job (segue to `ZoomedPhotoViewController`) or not.
  ///
  /// If a job is more than 2 minutes old, it is removed from the database and the segue is not performed. Otherwise, the segue is performed and the job is opened.
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

  /// Configures new `ZoomedPhotoViewController` with data about the job.
  ///
  /// Data: the first image, the object to find, the job UUID, and the requesting user.
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let cell = sender as? PhotoCell, let zoomedPhotoViewController = segue.destination as? ZoomedPhotoViewController {
      zoomedPhotoViewController.imagesForJob[0] = LabelingImage(image: cell.fullSizedImage, imageUUID: cell.jobUUID)
      zoomedPhotoViewController.objectToFind = cell.objectToFind
      zoomedPhotoViewController.labelingJob = cell.jobUUID
      zoomedPhotoViewController.requestingUser = cell.requestingUser
    }
  }

  /// Presents the Firebase Auth view controller for login
  func login() {
    let authViewController = authUI?.authViewController()
    self.present(authViewController!, animated: true)
  }
  
  /// Performs callbacks once logged in.
  ///
  /// - TODO: Not sure if reloading collection view when job is removed is threadsafe.
  ///
  /// Actions performed in callbacks:
  /// * Remove an old notification token, if it exists
  /// * Set user as value to the Firebase cloud messaging token associated with the user's device
  /// * Set a new notification token for this user
  /// * Get pending assignments
  ///   * Check if too old (older than 2 minutes)
  ///   * Download associated images
  /// * Reload collection if a job is removed
  /// * If no user is signed in, cleanup all observers and go to login
  func registerForLoginCallbacks() {
    Auth.auth().addStateDidChangeListener { auth, user in
      if let activeUser = user, let fcmToken = Messaging.messaging().fcmToken {
        // User is signed in.
        Database.database().reference(withPath: "/account_mapping/" + fcmToken).observeSingleEvent(of: DataEventType.value, with: { (snapshot) in
          if snapshot.exists() {
            Database.database().reference(withPath: "/notification_tokens/" + (snapshot.value as! String) + "/" + fcmToken).removeValue()
          }
          // grab ownership of the token
          Database.database().reference(withPath: "/account_mapping/" + fcmToken).setValue(activeUser.uid)
          Database.database().reference(withPath: "/notification_tokens/" + activeUser.uid + "/" + fcmToken).setValue(true)
        });

        self.userAssignmentsRef = Database.database().reference(withPath: "/notification_tokens/" + activeUser.uid + "/assignments")
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
  
  /// Assigns the data from one element from the `photos` array of dictionaries to be associated with a cell in the `collectionView`, according to the index of the element in `photos`.
  ///
  /// Each element contains the following (key: value):
  /// * `jobUUID`: the UUID for this job assigned by Firebase
  /// * `image`: the `UIImage` object of this job
  /// * `object_to_find`: the `String` representing the object to find in this job
  /// * `creation_timestamp`: the time the job was created
  /// * `requesting_user`: the UUID of the requesting user
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
    return cell
  }
}

// MARK: UICollectionViewDelegateFlowLayout
extension CollectionViewController : UICollectionViewDelegateFlowLayout {
  
  /// Sets the size of a cell to `thumbnailSize`.
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    return thumbnailSize
  }
  
  /// Sets the margins for each cell to `sectionInsets`
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return sectionInsets
  }
}
