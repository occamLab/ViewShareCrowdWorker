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
 * THE SOFWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import UserNotifications
import Firebase
import FirebaseAuth
import FirebaseAuthUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  var apnsId: String?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()
    registerForPushNotifications()
  
    // Check if launched from notification (note: currently I don't know that this is actually working)
    if let notification = launchOptions?[.remoteNotification] as? [String: AnyObject] {
      print(notification)
    }
    return true
  }
  
  func respondToNotification(notificationPayload: [AnyHashable : Any]) {
    let rootViewController = self.window!.rootViewController as! UINavigationController;
    if rootViewController.topViewController is ZoomedPhotoViewController {
      return
    }
    let jobUUID = notificationPayload["gcm.notification.labeling_job_id"] as! String
    // make sure we have actually been assigned this job.  If we have used multiple different accounts with the
    // same app instance, we will wind up potentially receiving notifications not meant for us.
    let ref = Database.database().reference().child("labeling_jobs/" + jobUUID)

    ref.observeSingleEvent(of: .value, with: { snapshot in
      if !snapshot.exists() { return }
      let value = snapshot.value as? NSDictionary

      if value != nil {
        let imageRef = Storage.storage().reference(withPath: jobUUID + ".jpg")
        // Download in memory with a maximum allowed size of 1MB (1 * 1024 * 1024 bytes)
        imageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
          if error == nil {
            let image = UIImage(data: data!)
            // Access the storyboard and fetch an instance of the view controller
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let viewController: ZoomedPhotoViewController = storyboard.instantiateViewController(withIdentifier: "PhotoViewController") as! ZoomedPhotoViewController
            viewController.imageToLoad = image
            viewController.objectToFind = value!["object_to_find"] as? String
            viewController.labelingJob = jobUUID
            // Then push that view controller onto the navigation stack
            rootViewController.pushViewController(viewController, animated: true);
          }
        }
      }
    })
  }
  
  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable : Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    respondToNotification(notificationPayload: userInfo)
  }
  
  
  func registerForPushNotifications() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
      (granted, error) in
      print("Permission granted: \(granted)")
      guard granted else { return }
      self.getNotificationSettings()
    }
  }
  
  func getNotificationSettings() {
    UNUserNotificationCenter.current().getNotificationSettings { (settings) in
      print("Notification settings: \(settings)")
      guard settings.authorizationStatus == .authorized else { return }
      UIApplication.shared.registerForRemoteNotifications()
    }
  }
  func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
  }
  
  func application(_ application: UIApplication,
                   didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register: \(error)")
  }
  
  
  
  @available(iOS 9.0, *)
  func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
    let sourceApplication = options[UIApplicationOpenURLOptionsKey.sourceApplication] as! String?
    return self.handleOpenUrl(url, sourceApplication: sourceApplication)
  }
  
  @available(iOS 8.0, *)
  func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
    return self.handleOpenUrl(url, sourceApplication: sourceApplication)
  }
  
  
  func handleOpenUrl(_ url: URL, sourceApplication: String?) -> Bool {
    if FUIAuth.defaultAuthUI()?.handleOpen(url, sourceApplication: sourceApplication) ?? false {
      return true
    }
    // other URL handling goes here.
    return false
  }
}

