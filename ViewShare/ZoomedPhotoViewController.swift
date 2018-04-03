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
import FirebaseAuth
import Firebase

public class LabelingImage {
  init(image imageInput: UIImage, imageUUID imageUUIDInput: String) {
    image = imageInput
    imageUUID = imageUUIDInput
    labeled = false
  }
  
  public var image: UIImage
  public var imageUUID: String
  public var labeled: Bool
}

class ZoomedPhotoViewController: UIViewController {
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageViewLeadingConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!
  @IBOutlet weak var objectText: UILabel!
  @IBOutlet weak var previewView: UIView!
  
  var addedOverlay : Bool = false
  var linesImageView : UIImageView?
  var imagesForJob = [Int: LabelingImage]()
  var objectToFind: String?
  var centerPoint: CGPoint?
  var labelingJob: String?
  var requestingUser: String?
  var additionalImagesListener: UInt?
  var additionalImagesRef: DatabaseReference?
  var jobStatusListener: UInt?
  var jobStatusRef: DatabaseReference?
  var waitForResponseTimer: Timer?
  var needAdditionalImage: Bool = false;

  var imageIndex: Int = 0
  var additionalImageCounter: Int = 0
  
  func handleLocated(location: CGPoint) {
    if let jobId = labelingJob,
      let requestUser = requestingUser,
      let labelerId = Auth.auth().currentUser?.uid {
      let conn = Database.database()
      // append a UUID to the response to allow multiple responses by a user TODO: it might be better change the key here to a UUID, and then have the labelerId as a field inside
      conn.reference().child("responses/" + requestUser + "/" + jobId + "/" + labelerId + "_" + UUID().uuidString).setValue([
        "x": location.x,
        "y": location.y,
        "imageUUID": imagesForJob[imageIndex]?.imageUUID ?? ""
        ])
      imagesForJob[imageIndex]?.labeled = true
      grayOutImageIfSelected()
      let sv = ZoomedPhotoViewController.displaySpinner(onView: self.view)
      needAdditionalImage = false
      waitForResponseTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false, block: { (timer) in
        ZoomedPhotoViewController.removeSpinner(spinner: sv)
        if !self.needAdditionalImage {
          conn.reference().child("notification_tokens/" + labelerId + "/assignments/" + jobId).removeValue()
          self.navigationController?.popViewController(animated: true)
        }
      })
    }
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    if additionalImagesListener != nil {
      additionalImagesRef?.removeObserver(withHandle: additionalImagesListener!)
      jobStatusRef?.removeObserver(withHandle: jobStatusListener!)
    }
  }

  override func viewDidLoad() {
    imageIndex = 0
    imageView.image = imagesForJob[imageIndex]?.image
    grayOutImageIfSelected()

    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    objectText.text = objectToFind
    objectText.textColor = UIColor(displayP3Red: 1.0,
                                   green: 0.0,
                                   blue: 0.0,
                                   alpha: 1.0)
    jobStatusRef = Database.database().reference(withPath: "labeling_jobs/" + labelingJob!)
    jobStatusListener = jobStatusRef?.observe(DataEventType.childChanged, with: { (snapshot) in
      guard snapshot.key == "job_status" && snapshot.value != nil else {
        return
      }
      if snapshot.key == "job_status" {
        if snapshot.value as? String == "waitingForAdditionalReponse" {
          // prevent us from segue
          self.needAdditionalImage = true
        }
      }
      self.waitForResponseTimer?.fire()
    })
    
    
    additionalImagesRef = Database.database().reference(withPath: "labeling_jobs/" + labelingJob! + "/additional_images")
    additionalImagesListener = additionalImagesRef?.queryOrdered(byChild: "imageSequenceNumber").observe(DataEventType.childAdded, with: { (snapshot) in
      self.additionalImageCounter += 1
      let myAdditionalImageIndex = self.additionalImageCounter
      let jobUUID = snapshot.key
      let imageFilePath = jobUUID + ".jpg"

      if appDelegate.imageCache[imageFilePath] != nil {
        self.imagesForJob[myAdditionalImageIndex] = appDelegate.imageCache[imageFilePath]!
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "gotNewPreviewImage"), object: nil)
      } else {
        let imageRef = Storage.storage().reference(withPath: imageFilePath)
        imageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
          if error == nil {
            let image = UIImage(data: data!)
            self.imagesForJob[myAdditionalImageIndex] = LabelingImage(image: image!, imageUUID: jobUUID)
            appDelegate.imageCache[imageFilePath] = self.imagesForJob[myAdditionalImageIndex]

            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "gotNewPreviewImage"), object: nil)
          }
        }
      }
    })
    addSwipe()
    NotificationCenter.default.addObserver(self, selector: #selector(self.previewImageSelected), name: NSNotification.Name(rawValue: "selectedPreviewImage"), object: nil)
    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "didSelectNewImage"), object:nil, userInfo: ["photoIndex": imageIndex])
    let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(ZoomedPhotoViewController.handleLongPress(_:)))
    longPressGesture.cancelsTouchesInView = false
    scrollView.addGestureRecognizer(longPressGesture)
  }
  
  @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer){
    if gesture.state == .ended && !imagesForJob[imageIndex]!.labeled {
      let touchLocation = gesture.location(in: scrollView)
      let locationCoordinate = scrollView.convert(touchLocation, to: imageView)
      handleLocated(location: locationCoordinate)
    }
  }

  @objc func previewImageSelected(notif: NSNotification) {
    imageView.image = notif.userInfo?["previewImage"] as? UIImage
    imageIndex = notif.userInfo?["previewImageIndex"] as! Int
    grayOutImageIfSelected()
  }

  func addSwipe() {
    let directions: [UISwipeGestureRecognizerDirection] = [.right, .left]
    for direction in directions {
      let gesture = UISwipeGestureRecognizer(target: self, action: #selector(handleGesture))
      gesture.direction = direction
      self.view.addGestureRecognizer(gesture)
    }
  }
  
  @objc func handleGesture(gesture: UISwipeGestureRecognizer) -> Void {
    if gesture.direction == UISwipeGestureRecognizerDirection.right {
      imageIndex = imageIndex - 1
      if imageIndex < 0 {
        imageIndex = imagesForJob.count - 1
      }
      
      imageView.image = imagesForJob[imageIndex]?.image
      grayOutImageIfSelected()

      NotificationCenter.default.post(name: NSNotification.Name(rawValue: "didSelectNewImage"), object:nil, userInfo: ["photoIndex": imageIndex])
    }
    else if gesture.direction == UISwipeGestureRecognizerDirection.left {
      imageIndex = imageIndex + 1
      // I wish we could just do modulus, but it is easily not available in Swift
      if imageIndex == imagesForJob.count {
        imageIndex = 0;
      }
      imageView.image = imagesForJob[imageIndex]?.image
      grayOutImageIfSelected()

      NotificationCenter.default.post(name: NSNotification.Name(rawValue: "didSelectNewImage"), object:nil, userInfo: ["photoIndex": imageIndex])
    }
  }
  
  func grayOutImageIfSelected() {
    guard let jobFrame = imagesForJob[imageIndex] else {
      return
    }
    if jobFrame.labeled {
      imageView.image = jobFrame.image.tint(with: UIColor.red)
    }
  }
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    updateMinZoomScaleForSize(view.bounds.size)
  }
  
  fileprivate func updateMinZoomScaleForSize(_ size: CGSize) {
    let widthScale = size.width / imageView.bounds.width
    let heightScale = size.height / imageView.bounds.height
    let minScale = min(widthScale, heightScale)*0.75
    
    scrollView.minimumZoomScale = minScale
    scrollView.zoomScale = minScale
    // allow user to zoom in a lot so the selection is at the center of the view
    scrollView.maximumZoomScale = 10
  }
}

extension ZoomedPhotoViewController: UIScrollViewDelegate {
  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return imageView
  }
}

extension ZoomedPhotoViewController {
  class func displaySpinner(onView : UIView) -> UIView {
    let spinnerView = UIView.init(frame: onView.bounds)
    spinnerView.backgroundColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
    let ai = UIActivityIndicatorView.init(activityIndicatorStyle: .whiteLarge)
    ai.startAnimating()
    ai.center = spinnerView.center
    
    DispatchQueue.main.async {
      spinnerView.addSubview(ai)
      onView.addSubview(spinnerView)
    }
    
    return spinnerView
  }
  
  class func removeSpinner(spinner :UIView) {
    DispatchQueue.main.async {
      spinner.removeFromSuperview()
    }
  }
}

extension UIImage {
  func tint(with color: UIColor) -> UIImage
  {
    UIGraphicsBeginImageContext(self.size)
    guard let context = UIGraphicsGetCurrentContext() else { return self }
    
    // flip the image
    context.scaleBy(x: 1.0, y: -1.0)
    context.translateBy(x: 0.0, y: -self.size.height)
    
    // multiply blend mode
    context.setBlendMode(.multiply)
    
    let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
    context.clip(to: rect, mask: self.cgImage!)
    color.setFill()
    context.fill(rect)
    
    // create UIImage
    guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else { return self }
    UIGraphicsEndImageContext()
    
    return newImage
  }
}
