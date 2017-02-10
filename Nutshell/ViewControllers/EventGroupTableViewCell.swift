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

class EventGroupRowCollectionCell: UICollectionViewCell {
    
    static let cellReuseID = "EventGroupRowCollectionCell"
    
    var photoUrl = ""
    var eventItem: NutEventItem?
    
    fileprivate var photoView: UIImageView?

    func configureCell(_ photoUrl: String, eventItem: NutEventItem?) {
        if (photoView != nil) {
            photoView?.removeFromSuperview();
            photoView = nil;
        }
        self.eventItem = eventItem
        self.photoUrl = photoUrl
        var imageFrame = self.bounds
        // leave a gap between photos
        imageFrame.size.width -= 3.0
        photoView = UIImageView(frame: imageFrame)
        photoView!.contentMode = .scaleAspectFill
        photoView!.backgroundColor = UIColor.clear
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
    fileprivate var photoUrls: [String] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated:animated)
        
        // Configure the view for the highlighted state
        titleString.isHighlighted = highlighted
        timeString.isHighlighted = highlighted
    }

    fileprivate var photoContainerHeight: CGFloat = 79.0
    func configureCell(_ eventItem: NutEventItem) {
        titleString.text = eventItem.notes
        NutUtils.setFormatterTimezone(eventItem.tzOffsetSecs)
        timeString.text = NutUtils.standardUIDateString(eventItem.time)
        self.eventItem = eventItem

        favoriteStarContainer.isHidden = !eventItem.nutCracked

        photoUrls = eventItem.photoUrlArray()
    
        let photoCount = photoUrls.count
        if photoCount > 0 {
            photoCollectView.reloadData()
        }
        
        photoCollectionViewContainer.isHidden = photoCount == 0
        // collapse photo container if there are no photos...
        for c in photoCollectionViewContainer.constraints {
            if c.firstAttribute == NSLayoutAttribute.height {
                if c.constant != 0.0 {
                    photoContainerHeight = c.constant
                }
                c.constant = photoCount > 0 ? photoContainerHeight : 0.0
                break
            }
        }
        for c in photoCollectionViewContainer.constraints {
            // let the width shrink if there is only one photo, so tapping past the one photo will segue to the detail view...
            if c.firstAttribute == NSLayoutAttribute.width {
                c.priority = photoCount == 1 ? 751 : 749
                break
            }
        }
    }
}

extension EventGroupTableViewCell: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photoUrls.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EventGroupRowCollectionCell.cellReuseID, for: indexPath) as! EventGroupRowCollectionCell
            
            // index determines center time...
            let photoIndex = indexPath.row
            if photoIndex < photoUrls.count {
                cell.configureCell(photoUrls[photoIndex], eventItem: eventItem)
            }
            return cell
    }
}

extension EventGroupTableViewCell: UICollectionViewDelegate {
    
}

extension EventGroupTableViewCell: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int) -> CGFloat
    {
        return 0.0
    }
}

