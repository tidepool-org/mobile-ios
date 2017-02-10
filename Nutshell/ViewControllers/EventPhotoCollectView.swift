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
    var photoDisplayMode: UIViewContentMode = .scaleAspectFit
    var imageIndex: Int = 0
    var pageControl: UIPageControl?
    var delegate: EventPhotoCollectViewDelegate?
    fileprivate var photoCollectionView: UICollectionView?
    fileprivate var currentViewHeight: CGFloat = 0.0

    func reloadData() {
        photoCollectionView?.reloadData()
    }
    
    func configurePhotoCollection() {
        if photoURLs.count == 0 {
            if photoCollectionView != nil {
                if let pageControl = pageControl {
                    pageControl.isHidden = true
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
        flow.scrollDirection = UICollectionViewScrollDirection.horizontal
        photoCollectionView = UICollectionView(frame: self.bounds, collectionViewLayout: flow)
        if let photoCollectionView = photoCollectionView {
            photoCollectionView.backgroundColor = UIColor.clear
            photoCollectionView.showsHorizontalScrollIndicator = false
            photoCollectionView.showsVerticalScrollIndicator = false
            photoCollectionView.dataSource = self
            photoCollectionView.delegate = self
            photoCollectionView.isPagingEnabled = true
            photoCollectionView.register(EventPhotoCollectionCell.self, forCellWithReuseIdentifier: EventPhotoCollectionCell.cellReuseID)
            // scroll to current photo...
            photoCollectionView.scrollToItem(at: IndexPath(row: imageIndex, section: 0), at: UICollectionViewScrollPosition.centeredHorizontally, animated: false)
            self.insertSubview(photoCollectionView, at: 0)
            if let pageControl = pageControl {
                pageControl.isHidden = false
                self.bringSubview(toFront: pageControl)
            }
            photoCollectionView.reloadData()
            configurePageControl()
        }
    }

    func currentCellIndex() -> IndexPath? {
        if let collectView = photoCollectionView {
            let centerPoint = collectView.center
            let pointInCell = CGPoint(x: centerPoint.x + collectView.contentOffset.x, y: centerPoint.y + collectView.contentOffset.y)
            return collectView.indexPathForItem(at: pointInCell)
        }
        return nil
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
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

    fileprivate func configurePageControl() {
        if let pageControl = pageControl {
            pageControl.isHidden = photoURLs.count <= 1
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
    var photoDisplayMode: UIViewContentMode = .scaleAspectFit
    
    func configureCell(_ photoUrl: String) {
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
        photoView!.backgroundColor = UIColor.clear
        NutUtils.loadImage(photoUrl, imageView: photoView!)
        self.scrollView!.addSubview(photoView!)
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.photoView
    }
}

protocol EventPhotoCollectViewDelegate {
    func didSelectItemAtIndexPath(_ indexPath: IndexPath)
}

extension EventPhotoCollectView: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectItemAtIndexPath(indexPath)
    }
    
}

extension EventPhotoCollectView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photoURLs.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EventPhotoCollectionCell.cellReuseID, for: indexPath) as! EventPhotoCollectionCell
            
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
    
    func collectionView(_ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int) -> CGFloat
    {
        return 0.0
    }
}


