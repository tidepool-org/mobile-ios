//
//  ShowPhotoViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 10/28/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class ShowPhotoViewController: UIViewController {

    var editAllowed = false
    var photoURLs: [String] = []
    var imageIndex: Int = 0
    
    @IBOutlet weak var photoCollectionContainerView: NutshellUIView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    private var photoCollectionView: UICollectionView?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // We use a custom back button so we can hide the photo to minimizing flashing. This tweaks the arrow positioning to match the iOS back arrow position. TODO: -> actually turned off right now!
        self.navigationItem.leftBarButtonItem?.imageInsets = UIEdgeInsetsMake(0.0, -8.0, -1.0, 0.0)
        if editAllowed {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Trash, target: self, action: "deleteButtonHandler:")
        }
        configurePageControl()
    }

    override func viewDidLayoutSubviews() {
        configurePhotoCollectionIfNil()
    }

    private func configurePageControl() {
        pageControl.hidden = photoURLs.count <= 1
        pageControl.numberOfPages = photoURLs.count
        pageControl.currentPage = imageIndex
    }
    
    private func removeCurrentPhoto() {
        if let photoCollectionView = photoCollectionView {
            if let curPhotoIndex = currentCellIndex(photoCollectionView) {
                let curImageIndex = curPhotoIndex.row
                photoURLs.removeAtIndex(curImageIndex)
                if photoURLs.count == 0 {
                    self.performSegueWithIdentifier(EventViewStoryboard.SegueIdentifiers.UnwindSegueFromShowPhoto, sender: self)
                } else {
                    configurePageControl()
                    photoCollectionView.reloadData()
                }
            }
        }
    }
    
    private func configurePhotoCollectionIfNil() {
        if photoCollectionView != nil || photoURLs.count == 0 {
            return
        }
        let flow = UICollectionViewFlowLayout()
        flow.itemSize = photoCollectionContainerView.bounds.size
        flow.scrollDirection = UICollectionViewScrollDirection.Horizontal
        photoCollectionView = UICollectionView(frame: photoCollectionContainerView.bounds, collectionViewLayout: flow)
        if let photoCollectionView = photoCollectionView {
            photoCollectionView.backgroundColor = UIColor.clearColor()
            photoCollectionView.showsHorizontalScrollIndicator = false
            photoCollectionView.showsVerticalScrollIndicator = false
            photoCollectionView.dataSource = self
            photoCollectionView.delegate = self
            photoCollectionView.pagingEnabled = true
            photoCollectionView.registerClass(PhotoViewCollectionCell.self, forCellWithReuseIdentifier: PhotoViewCollectionCell.cellReuseID)
            // scroll to current photo...
            photoCollectionView.scrollToItemAtIndexPath(NSIndexPath(forRow: imageIndex, inSection: 0), atScrollPosition: UICollectionViewScrollPosition.CenteredHorizontally, animated: false)
            photoCollectionContainerView.addSubview(photoCollectionView)
            photoCollectionContainerView.bringSubviewToFront(pageControl)
            photoCollectionView.reloadData()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        NSLog("Segue from Photo viewer!")
        if let photoCollectionView = photoCollectionView {
            let currentPhotoIndex = currentCellIndex(photoCollectionView)
            if let currentPhotoIndex = currentPhotoIndex {
                imageIndex = currentPhotoIndex.row
            } else {
                imageIndex = 0
            }
        }
    }
    
    @IBAction func backButtonHandler(sender: AnyObject) {
        //photoImageView.hidden = true
        self.performSegueWithIdentifier(EventViewStoryboard.SegueIdentifiers.UnwindSegueFromShowPhoto, sender: self)
    }

    @IBAction func deleteButtonHandler(sender: AnyObject) {
        // removing items from url array sets up the EventAddOrEditVC to delete the photos when edits are saved...
        // TODO: is this dialog really necessary and if so, is wording ok? The photos are not really deleted until you return to the edit scene and tap save. 
        if photoURLs.isEmpty {
            return
        }
        let alert = UIAlertController(title: NSLocalizedString("discardPhotoAlertTitle", comment:"Discard photo?"), message: NSLocalizedString("discardPhotoAlertMessage", comment:"If you discard this photo, your photo will be lost."), preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("discardAlertCancel", comment:"Cancel"), style: .Cancel, handler: { Void in
            return
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("discardAlertOkay", comment:"Discard"), style: .Default, handler: { Void in
            self.removeCurrentPhoto()
        }))
        self.presentViewController(alert, animated: true, completion: nil)
       
    }

    func currentCellIndex(collectView: UICollectionView?) -> NSIndexPath? {
        if let collectView = collectView {
            let centerPoint = collectView.center
            let pointInCell = CGPoint(x: centerPoint.x + collectView.contentOffset.x, y: centerPoint.y + collectView.contentOffset.y)
            return collectView.indexPathForItemAtPoint(pointInCell)
        }
        return nil
    }

    func scrollViewDidScroll(scrollView: UIScrollView) {
        if let photoCollectView = scrollView as? UICollectionView {
            if let curIndexPath = currentCellIndex(photoCollectView) {
                pageControl.currentPage = curIndexPath.row
            }
        }
    }
    
//    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
//        if let photoCollectionView = photoCollectionView {
//            if let cellIndexPath = currentCellIndex(photoCollectionView) {
//                if let cell = photoCollectionView.cellForItemAtIndexPath(cellIndexPath) as? PhotoViewCollectionCell {
//                    return cell.photoView
//                }
//            }
//        }
//        return nil
//    }
    
}

class PhotoViewCollectionCell: UICollectionViewCell {
    
    static let cellReuseID = "PhotoViewCollectionCell"
    var photoView: UIImageView?
    var photoUrl = ""
    
    func configureCell(photoUrl: String) {
        if (photoView != nil) {
            photoView?.removeFromSuperview();
            photoView = nil;
        }
        self.photoUrl = photoUrl
        photoView = UIImageView(frame: self.bounds)
        photoView!.contentMode = .ScaleAspectFit
        photoView!.backgroundColor = UIColor.clearColor()
        NutUtils.loadImage(photoUrl, imageView: photoView!)
        self.addSubview(photoView!)
    }
}

extension ShowPhotoViewController: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photoURLs.count
    }
    
    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(PhotoViewCollectionCell.cellReuseID, forIndexPath: indexPath) as! PhotoViewCollectionCell
            
            // index determines center time...
            let photoIndex = indexPath.row
            if photoIndex < photoURLs.count {
                cell.configureCell(photoURLs[photoIndex])
            }
            return cell
    }
}

extension ShowPhotoViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat
    {
        return 0.0
    }
}

