/*
* Copyright (c) 2015, Tidepool Project
*
* This program is free software; you can redistribute it and/or modify it under
* the terms of the associated License, which is identical to the BSD 2-Clause
* License as published by the Open Source Initiative at opensource.org.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the License for more details.
*
* You should have received a copy of the License along with this program; if
* not, you can obtain one from Tidepool Project at tidepool.org.
*/

import UIKit

/// UICollectionView supporting full-view sized photos, with optional page control.
class EventPhotoCollectView: UIControl {

    var photoURLs: [String] = []
    var photoDisplayMode: UIViewContentMode = .ScaleAspectFit
    var imageIndex: Int = 0
    var pageControl: UIPageControl?
    var delegate: EventPhotoCollectViewDelegate?
    private var photoCollectionView: UICollectionView?
    private var currentViewHeight: CGFloat = 0.0

    func reloadData() {
        photoCollectionView?.reloadData()
    }
    
    func configurePhotoCollection() {
        if photoURLs.count == 0 {
            if photoCollectionView != nil {
                if let pageControl = pageControl {
                    pageControl.hidden = true
                }
                photoCollectionView?.removeFromSuperview()
                photoCollectionView = nil
            }
            return
        }
        
        if photoCollectionView != nil {
            if currentViewHeight == self.bounds.height {
                reloadData()
                configurePageControl()
                return
            }
            // size has changed, need to redo...
            photoCollectionView?.removeFromSuperview()
            photoCollectionView = nil
        }
        
        let flow = UICollectionViewFlowLayout()
        flow.itemSize = self.bounds.size
        flow.scrollDirection = UICollectionViewScrollDirection.Horizontal
        photoCollectionView = UICollectionView(frame: self.bounds, collectionViewLayout: flow)
        if let photoCollectionView = photoCollectionView {
            photoCollectionView.backgroundColor = UIColor.clearColor()
            photoCollectionView.showsHorizontalScrollIndicator = false
            photoCollectionView.showsVerticalScrollIndicator = false
            photoCollectionView.dataSource = self
            photoCollectionView.delegate = self
            photoCollectionView.pagingEnabled = true
            photoCollectionView.registerClass(EventPhotoCollectionCell.self, forCellWithReuseIdentifier: EventPhotoCollectionCell.cellReuseID)
            // scroll to current photo...
            photoCollectionView.scrollToItemAtIndexPath(NSIndexPath(forRow: imageIndex, inSection: 0), atScrollPosition: UICollectionViewScrollPosition.CenteredHorizontally, animated: false)
            self.insertSubview(photoCollectionView, atIndex: 0)
            if let pageControl = pageControl {
                pageControl.hidden = false
                self.bringSubviewToFront(pageControl)
            }
            photoCollectionView.reloadData()
            configurePageControl()
        }
    }

    func currentCellIndex() -> NSIndexPath? {
        if let collectView = photoCollectionView {
            let centerPoint = collectView.center
            let pointInCell = CGPoint(x: centerPoint.x + collectView.contentOffset.x, y: centerPoint.y + collectView.contentOffset.y)
            return collectView.indexPathForItemAtPoint(pointInCell)
        }
        return nil
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        if let pageControl = pageControl {
            if let curIndexPath = currentCellIndex() {
                
                if curIndexPath.row > pageControl.currentPage {
                    APIConnector.connector().trackMetric("Swiped Left on a Photo (Photo Screen)")
                } else if curIndexPath.row < pageControl.currentPage {
                    APIConnector.connector().trackMetric("Swiped Right on a Photo (Photo Screen)")
                }

                pageControl.currentPage = curIndexPath.row
            }
        }
    }

    private func configurePageControl() {
        if let pageControl = pageControl {
            pageControl.hidden = photoURLs.count <= 1
            pageControl.numberOfPages = photoURLs.count
            pageControl.currentPage = imageIndex
        }
    }

}

class EventPhotoCollectionCell: UICollectionViewCell, UIScrollViewDelegate {
    
    static let cellReuseID = "EventPhotoCollectionCell"
    var scrollView: UIScrollView?
    var photoView: UIImageView?
    var photoUrl = ""
    var photoDisplayMode: UIViewContentMode = .ScaleAspectFit
    
    func configureCell(photoUrl: String) {
        if (photoView != nil) {
            photoView?.removeFromSuperview();
            photoView = nil
        }
        if (scrollView != nil) {
            scrollView?.removeFromSuperview()
            scrollView = nil
        }
        self.scrollView = UIScrollView(frame: self.bounds)
        self.addSubview(scrollView!)
        self.scrollView?.minimumZoomScale = 1.0
        self.scrollView?.maximumZoomScale = 4.0
        self.scrollView?.delegate = self
        
        self.photoUrl = photoUrl
        photoView = UIImageView(frame: self.bounds)
        photoView!.contentMode = photoDisplayMode
        photoView!.backgroundColor = UIColor.clearColor()
        NutUtils.loadImage(photoUrl, imageView: photoView!)
        self.scrollView!.addSubview(photoView!)
    }
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return self.photoView
    }
}

protocol EventPhotoCollectViewDelegate {
    func didSelectItemAtIndexPath(indexPath: NSIndexPath)
}

extension EventPhotoCollectView: UICollectionViewDelegate {
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        delegate?.didSelectItemAtIndexPath(indexPath)
    }
    
}

extension EventPhotoCollectView: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photoURLs.count
    }
    
    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(EventPhotoCollectionCell.cellReuseID, forIndexPath: indexPath) as! EventPhotoCollectionCell
            
            // index determines center time...
            let photoIndex = indexPath.row
            if photoIndex < photoURLs.count {
                cell.photoDisplayMode = self.photoDisplayMode
                cell.configureCell(photoURLs[photoIndex])
            }
            return cell
    }
}

extension EventPhotoCollectView: UICollectionViewDelegateFlowLayout {
    
    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat
    {
        return 0.0
    }
}


