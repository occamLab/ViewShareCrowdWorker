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
import Alamofire
import SwiftyJSON

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  var apnsId: String?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    print("attached")

    registerForPushNotifications()
    // Check if launched from notification (note: currently I don't know that this is actually working)
    if let notification = launchOptions?[.remoteNotification] as? [String: AnyObject] {
      print(notification)
    }
    return true
  }
  
  func respondToNotification(notificationPayload: [AnyHashable : Any]) {
    print(notificationPayload)
    let parameters: Parameters = [
      "label_request": notificationPayload["labeling_job_id"] as! Int,
      ]
    print("attempting to get image")
    Alamofire.request("https://damp-chamber-71992.herokuapp.com/get_labeling_job", method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON
      { response in
        if let json:NSDictionary = response.result.value as? NSDictionary,
           let image_data_array:[String] = json.value(forKeyPath: "data.image") as? [String],
           !image_data_array.isEmpty,
           let dataDecoded : Data = Data(base64Encoded: image_data_array[0], options: .ignoreUnknownCharacters),
           let decodedImage = UIImage(data: dataDecoded) {
          
          print("successfully decoded image")
          // Access the storyboard and fetch an instance of the view controller
          let storyboard = UIStoryboard(name: "Main", bundle: nil)
          let viewController: ZoomedPhotoViewController = storyboard.instantiateViewController(withIdentifier: "PhotoViewController") as! ZoomedPhotoViewController
          viewController.imageToLoad = decodedImage
          
          let object_to_find_as_array:[String] = json.value(forKeyPath: "data.object_to_find")! as! [String]
          viewController.objectToFind = object_to_find_as_array[0]
          
          let labeling_job_id_as_array:[Int] = json.value(forKeyPath: "data.label_request")! as! [Int]
          viewController.labelingJob = labeling_job_id_as_array[0]
          viewController.apnsId = self.apnsId
          // Then push that view controller onto the navigation stack
          let rootViewController = self.window!.rootViewController as! UINavigationController;
          rootViewController.pushViewController(viewController, animated: true);
        }
    }
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
    let tokenParts = deviceToken.map { data -> String in
      return String(format: "%02.2hhx", data)
    }
    
    apnsId = tokenParts.joined()
    print("Device Token: \(apnsId!)")
    let parameters: Parameters = [
      "apnsId": apnsId!,
      ]
    Alamofire.request("https://damp-chamber-71992.herokuapp.com/dologin", method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON
      { response in
        debugPrint("Successfully logged in", response)
    }
  }
  
  func application(_ application: UIApplication,
                   didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register: \(error)")
  }
}

