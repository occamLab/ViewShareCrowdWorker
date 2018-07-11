//
//  PreviewCollectionViewController.swift
//  View Share
//
//  Created by Paul Ruvolo on 9/28/17.
//  Copyright © 2017 occamlab. All rights reserved.
//

import Foundation
import UIKit

/// Provides an interface for viewing the other available photos in a CollectionView that appears as a bottom bar when viewing a job.
class PreviewCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
  
  /// I am unsure what this does
  /// In fact, does this even get used anywhere
  var imageTest: UIImage?
  
  /// I am unsure what this does
  fileprivate let reuseIdentifier = "PreviewPhotoCell"
  
  /// Defines the size of a thumbnail
  fileprivate let thumbnailSize = CGSize(width: 42, height: 75)
  
  /// Defines the margins of a cell
  fileprivate let sectionInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
  
  /// A list of images to label, held in a `LabelingImage` class.
  var imageJobs: [LabelingImage] = []
  
  ///
  var previousIndexPath: IndexPath?
  
  /// Listen for notifications from `ZoomedPhotoViewController`.
  override func viewDidLoad() {
    NotificationCenter.default.addObserver(self, selector: #selector(self.gotNewPreviewImage), name: NSNotification.Name(rawValue: "gotNewPreviewImage"), object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(self.imageSelected), name: NSNotification.Name(rawValue: "didSelectNewImage"), object: nil)
  }
  
  /// Draw borders around the correct image in the collection if received a notification from `ZoomedPhotoViewController` that the user swiped left or right.
  ///
  /// - Parameter notif: notification
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
  
  /// Reloads the collection of images if received a notification from `ZoomedPhotoViewController` that a new preview image was received.
  ///
  /// - Parameter notif: notification
  @objc func gotNewPreviewImage(notif: NSNotification) {
    // invalidate any borders that were added
    removeSelectionBorder()
    collectionView?.reloadData()
  }

  /// Set number of sections in this collection view to 1.
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  /// Set number of items in this collection view to the number of images in the `imagesForJob` dictionary.
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return (parent as! ZoomedPhotoViewController).imagesForJob.count
  }
  
  /// Provides data for the cell at this index from the `imagesForJob` dictionary and draws a border.
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

  /// Sets size of image to `thumbnailSize`.
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    return thumbnailSize
  }
  
  /// Sets margins of image to `sectionInsets`.
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return sectionInsets
  }
  
  /// Removes border from the previously selected cell in the collection view.
  func removeSelectionBorder() {
    if previousIndexPath != nil {
      let previouslySelected = collectionView?.cellForItem(at: previousIndexPath!) as? PreviewPhotoCell
      previouslySelected?.layer.borderWidth = 0
    }
  }
  
  /// Draws a custom border and notifies `ZoomedPhotoViewController` when an item is selected.
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
