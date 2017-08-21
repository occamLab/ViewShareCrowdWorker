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
import Alamofire
import SwiftyJSON

class ZoomedPhotoViewController: UIViewController {
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageViewLeadingConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!
  @IBOutlet weak var objectText: UILabel!
  
  var addedOverlay : Bool = false
  var linesImageView : UIImageView?
  var photoName: String?
  var imageToLoad: UIImage?
  var objectToFind: String?
  var centerPoint: CGPoint?
  var labelingJob: Int?
  var apnsId : String?

  @IBAction func handleClick(_ sender: UIButton) {
    if let selected = centerPoint,
       let jobId = labelingJob,
       let labelerId = apnsId {
      let parameters: Parameters = [
        "labeler_id" : labelerId,
        "labeling_job" : jobId,
        "x": selected.x,
        "y": selected.y
      ]
      Alamofire.request("https://damp-chamber-71992.herokuapp.com/addlabel", method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON { response in
            debugPrint(response)
        
            if let json = response.result.value {
              print("JSON: \(json)")
            }
          }
      if navigationController != nil {
        navigationController?.popViewController(animated: true)
      }
    }
  }
  
  func add_labeling_job_to_db(image : UIImage) {
    //Now use image to create into NSData format
    let imageData:Data? = UIImageJPEGRepresentation(image, 1.0)!
    let strBase64 = imageData!.base64EncodedString(options: .lineLength64Characters)
    let parameters: Parameters = [
      "object_to_find": "Dummy object",
      "image": strBase64
    ]
    print("attempting to get image")
    Alamofire.request("https://damp-chamber-71992.herokuapp.com/add_labeling_job", method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON
      { response in
        print(response)
    }
  }
  
  override func viewDidLoad() {
    if let imageOverride = imageToLoad {
      imageView.image = imageOverride
      // clear the loaded image so we don't use it next time
      imageToLoad = nil
    } else if let photoName = photoName {
      imageView.image = UIImage(named: photoName)
    }
    objectText.text = objectToFind
    objectText.textColor = UIColor(displayP3Red: 1.0,
                                   green: 0.0,
                                   blue: 0.0,
                                   alpha: 1.0)
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    updateMinZoomScaleForSize(view.bounds.size)
  }
  
  fileprivate func updateMinZoomScaleForSize(_ size: CGSize) {
    let widthScale = size.width / imageView.bounds.width
    let heightScale = size.height / imageView.bounds.height
    let minScale = min(widthScale, heightScale)
    
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
    updateConstraintsForSize(view.bounds.size)
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
  
  fileprivate func updateConstraintsForSize(_ size: CGSize) {
    let yOffset = max(0, (size.height - imageView.frame.height) / 2)
    imageViewTopConstraint.constant = yOffset
    imageViewBottomConstraint.constant = yOffset
    
    let xOffset = max(0, (size.width - imageView.frame.width) / 2)
    imageViewLeadingConstraint.constant = xOffset
    imageViewTrailingConstraint.constant = xOffset
    
    view.layoutIfNeeded()
  }
}

