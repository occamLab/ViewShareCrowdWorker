//
//  PreviewCollectionViewController.swift
//  FindIt
//
//  Created by Paul Ruvolo on 9/28/17.
//  Copyright © 2017 occamlab. All rights reserved.
//

import Foundation
import UIKit

class PreviewCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
  var imageTest: UIImage?
  fileprivate let reuseIdentifier = "PreviewPhotoCell"
  fileprivate let thumbnailSize = CGSize(width: 42, height: 75)
  fileprivate let sectionInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
  var imageJobs: [LabelingImage] = []
  var previousIndexPath : IndexPath?
  
  override func viewDidLoad() {
    NotificationCenter.default.addObserver(self, selector: #selector(self.gotNewPreviewImage), name: NSNotification.Name(rawValue: "gotNewPreviewImage"), object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(self.imageSelected), name: NSNotification.Name(rawValue: "didSelectNewImage"), object: nil)
  }
  
  @objc func imageSelected(notif: NSNotification) {
    // invalidate any borders that were added
    removeSelectionBorder()
    let imageIndex = notif.userInfo?["photoIndex"] as? Int
    
    if imageIndex != nil {
      previousIndexPath = IndexPath(row: imageIndex!, section: 0)
      let cell = collectionView?.cellForItem(at: previousIndexPath!) as? PreviewPhotoCell
      cell?.layer.borderWidth = 2
      cell?.layer.borderColor = UIColor.red.cgColor
    }
  }
  
  @objc func gotNewPreviewImage(notif: NSNotification) {
    // invalidate any borders that were added
    removeSelectionBorder()
    collectionView?.reloadData()
  }

  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return (parent as! ZoomedPhotoViewController).imagesForJob.count
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PreviewPhotoCell
    if indexPath == previousIndexPath {
      // add the border
      cell.layer.borderWidth = 2
      cell.layer.borderColor = UIColor.red.cgColor
    }
    let p = parent as! ZoomedPhotoViewController
    cell.imageView.image = p.imagesForJob[indexPath.row]?.image
    return cell
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    return thumbnailSize
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return sectionInsets
  }
  func removeSelectionBorder() {
    if previousIndexPath != nil {
      let previouslySelected = collectionView?.cellForItem(at: previousIndexPath!) as? PreviewPhotoCell
      previouslySelected?.layer.borderWidth = 0
    }
  }
  
  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    print("indexPath", indexPath)
    removeSelectionBorder()
    
    let cell = collectionView.cellForItem(at: indexPath) as! PreviewPhotoCell
    previousIndexPath = indexPath
    cell.layer.borderWidth = 2
    cell.layer.borderColor = UIColor.red.cgColor
    
    guard let selectedImage = cell.imageView?.image else {
      return
    }
    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "selectedPreviewImage"), object:nil, userInfo: ["previewImage": selectedImage, "previewImageIndex": indexPath.row])
  }
}
