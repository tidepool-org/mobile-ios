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

class EventGroupTableCellButton: UIButton {
    var photoUrl = ""
}

class EventGroupRowCollectionCell: UICollectionViewCell {
    
    static let cellReuseID = "EventGroupRowCollectionCell"
    private var photoView: UIImageView?
    var photoUrl = ""

    func configureCell(photoUrl: String) {
        if (photoView != nil) {
            photoView?.removeFromSuperview();
            photoView = nil;
        }
        self.photoUrl = photoUrl
        var imageFrame = self.bounds
        // leave a gap between photos
        imageFrame.size.width -= 3.0
        photoView = UIImageView(frame: imageFrame)
        photoView!.contentMode = .ScaleAspectFill
        photoView!.backgroundColor = UIColor.clearColor()
        NutUtils.loadImage(photoUrl, imageView: photoView!)
        self.addSubview(photoView!)
    }
}

class EventGroupTableViewCell: BaseUITableViewCell {

    var eventItem: NutEventItem?
    
    @IBOutlet weak var favoriteStarContainer: UIView!
    @IBOutlet weak var titleString: NutshellUILabel!
    @IBOutlet weak var timeString: NutshellUILabel!
    @IBOutlet weak var photoCollectionViewContainer: UIView!
    @IBOutlet weak var photoCollectView: UICollectionView!
    private var photoUrls: [String] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }

    override func setHighlighted(highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated:animated)
        
        // Configure the view for the highlighted state
        titleString.highlighted = highlighted
        timeString.highlighted = highlighted
    }

    private var photoContainerHeight: CGFloat = 79.0
    func configureCell(eventItem: NutEventItem) {
        titleString.text = eventItem.notes
        timeString.text = NutUtils.standardUIDateString(eventItem.time, relative: true)
        self.eventItem = eventItem

        favoriteStarContainer.hidden = !eventItem.nutCracked

        photoUrls = eventItem.photoUrlArray()
    
        let photoCount = photoUrls.count
        if photoCount > 0 {
            photoCollectView.reloadData()
        }
        
        photoCollectionViewContainer.hidden = photoCount == 0
        // collapse photo container if there are no photos...
        for c in photoCollectionViewContainer.constraints {
            if c.firstAttribute == NSLayoutAttribute.Height {
                if c.constant != 0.0 {
                    photoContainerHeight = c.constant
                }
                c.constant = photoCount > 0 ? photoContainerHeight : 0.0
                break
            }
        }
        for c in photoCollectionViewContainer.constraints {
            // let the width shrink if there is only one photo, so tapping past the one photo will segue to the detail view...
            if c.firstAttribute == NSLayoutAttribute.Width {
                c.priority = photoCount == 1 ? 751 : 749
                break
            }
        }
    }
}

extension EventGroupTableViewCell: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photoUrls.count
    }
    
    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(EventGroupRowCollectionCell.cellReuseID, forIndexPath: indexPath) as! EventGroupRowCollectionCell
            
            // index determines center time...
            let photoIndex = indexPath.row
            if photoIndex < photoUrls.count {
                cell.configureCell(photoUrls[photoIndex])
            }
            return cell
    }
}

extension EventGroupTableViewCell: UICollectionViewDelegate {
    
}

extension EventGroupTableViewCell: UICollectionViewDelegateFlowLayout {
    
    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat
    {
        return 0.0
    }
}

