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

public struct LabelingImage {
  public var image: UIImage
  public var imageUUID: String
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
  var imageIndex: Int = 0
  var additionalImageCounter: Int = 0
  
  @IBAction func handleClick(_ sender: UIButton) {
    if let selected = centerPoint,
       let jobId = labelingJob,
       let requestUser = requestingUser,
       let labelerId = Auth.auth().currentUser?.uid {
      let conn = Database.database()
      conn.reference().child("responses/" + requestUser + "/" + jobId + "/" + labelerId).setValue([
        "x": selected.x,
        "y": selected.y,
        "imageUUID": imagesForJob[imageIndex]?.imageUUID
        ])

      conn.reference().child("notification_tokens/" + labelerId + "/assignments/" + jobId).removeValue()
      if navigationController != nil {  // might not need this (due to optional below)
        navigationController?.popViewController(animated: true)
      }
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    if additionalImagesListener != nil {
      additionalImagesRef?.removeObserver(withHandle: additionalImagesListener!)
    }
  }

  override func viewDidLoad() {
    imageIndex = 0
    imageView.image = imagesForJob[imageIndex]?.image
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    objectText.text = objectToFind
    objectText.textColor = UIColor(displayP3Red: 1.0,
                                   green: 0.0,
                                   blue: 0.0,
                                   alpha: 1.0)
    additionalImagesRef = Database.database().reference(withPath: "labeling_jobs/" + labelingJob! + "/additional_images")
    additionalImagesListener = additionalImagesRef?.queryOrdered(byChild: "imageSequenceNumber").observe(DataEventType.childAdded, with: { (snapshot) in
      self.additionalImageCounter += 1
      let myAdditionalImageIndex = self.additionalImageCounter
      let jobUUID = snapshot.key
      let imageFilePath = jobUUID + ".jpg"

      if appDelegate.imageCache[imageFilePath] != nil {
        self.imagesForJob[myAdditionalImageIndex] = LabelingImage(image: appDelegate.imageCache[imageFilePath]!, imageUUID: jobUUID)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "gotNewPreviewImage"), object: nil)
      } else {
        let imageRef = Storage.storage().reference(withPath: imageFilePath)
        imageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
          if error == nil {
            let image = UIImage(data: data!)
            appDelegate.imageCache[imageFilePath] = image
            self.imagesForJob[myAdditionalImageIndex] = LabelingImage(image: image!, imageUUID: jobUUID)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "gotNewPreviewImage"), object: nil)
          }
        }
      }
    })
    addSwipe()
    NotificationCenter.default.addObserver(self, selector: #selector(self.previewImageSelected), name: NSNotification.Name(rawValue: "selectedPreviewImage"), object: nil)
    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "didSelectNewImage"), object:nil, userInfo: ["photoIndex": imageIndex])
  }
  
  @objc func previewImageSelected(notif: NSNotification) {
    imageView.image = notif.userInfo?["previewImage"] as? UIImage
    imageIndex = notif.userInfo?["previewImageIndex"] as! Int
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
      NotificationCenter.default.post(name: NSNotification.Name(rawValue: "didSelectNewImage"), object:nil, userInfo: ["photoIndex": imageIndex])
    }
    else if gesture.direction == UISwipeGestureRecognizerDirection.left {
      imageIndex = imageIndex + 1
      // I wish we could just do modulus, but it is easily not available in Swift
      if imageIndex == imagesForJob.count {
        imageIndex = 0;
      }
      imageView.image = imagesForJob[imageIndex]?.image
      NotificationCenter.default.post(name: NSNotification.Name(rawValue: "didSelectNewImage"), object:nil, userInfo: ["photoIndex": imageIndex])
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
  
  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    drawSelectionOverlay()
  }
  
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    drawSelectionOverlay()
  }
  
  private func drawSelectionOverlay() {
    let scrollViewBounds = scrollView.convert(scrollView.bounds, to:imageView)
    centerPoint = CGPoint(x:scrollViewBounds.midX, y:scrollViewBounds.midY)
    
    // 1. CREATE A IMAGE GRAPHICS CONTEXT AND DRAW LINES ON IT
    UIGraphicsBeginImageContext(imageView.image!.size)

    if let currentContext = UIGraphicsGetCurrentContext() {
      let theCenter : CGPoint = CGPoint(x: imageView.bounds.width / 2, y: imageView.bounds.height / 2)
      currentContext.setFillColor(UIColor.init(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5).cgColor)
      currentContext.addRect(CGRect(x:centerPoint!.x-10, y:centerPoint!.y-10, width:20, height:20))
      currentContext.drawPath(using: .fillStroke)
      
      // 2. CREATE AN IMAGE OF THE DRAWN LINES AND ADD TO THE BOARD
      if let linesImage : UIImage = UIGraphicsGetImageFromCurrentImageContext() {
        if addedOverlay {
          linesImageView!.image = linesImage
        } else {
          linesImageView = UIImageView(image: linesImage)
          imageView.addSubview(linesImageView!)
        }
        linesImageView!.center = theCenter
        addedOverlay = true
      }
    }
    
    // 3. END THE GRAPHICSCONTEXT
    UIGraphicsEndImageContext()
  }
}

