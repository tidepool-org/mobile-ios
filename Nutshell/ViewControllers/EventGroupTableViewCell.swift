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

class EventGroupTableViewCell: BaseUITableViewCell {

    var eventItem: NutEventItem?
    @IBOutlet weak var showPhotoButton: EventGroupTableCellButton!
    
    @IBOutlet weak var favoriteStarContainer: UIView!
    @IBOutlet weak var titleString: NutshellUILabel!
    @IBOutlet weak var timeString: NutshellUILabel!
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoContainerView: UIView!

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

    private var starViewContainerWidth: CGFloat = 53.0
    func configureCell(eventItem: NutEventItem) {
        titleString.text = eventItem.notes
        timeString.text = NutUtils.standardUIDateString(eventItem.time, relative: true)
        self.eventItem = eventItem

        // Show/hide star, sliding title/date items right to accomodate
        for c in favoriteStarContainer.constraints {
            if c.firstAttribute == NSLayoutAttribute.Width {
                if c.constant != 0.0 {
                    starViewContainerWidth = c.constant
                }
                c.constant = eventItem.nutCracked ? starViewContainerWidth : 0.0
                break
            }
        }
        favoriteStarContainer.layoutIfNeeded()

        photoContainerView.hidden = true
        if let meal = eventItem as? NutMeal {
            if !meal.photo.isEmpty {
                NutUtils.loadImage(meal.photo, imageView: photoImageView)
                photoContainerView.hidden = false
                showPhotoButton.photoUrl = meal.photo
            }
        }
    }
}
