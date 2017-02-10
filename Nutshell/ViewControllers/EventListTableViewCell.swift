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

class EventListTableViewCell: BaseUITableViewCell {

    var eventGroup: NutEvent?

    @IBOutlet weak var titleLabel: NutshellUILabel!
    @IBOutlet weak var locationLabel: NutshellUILabel!
    @IBOutlet weak var repeatCountLabel: NutshellUILabel!
    @IBOutlet weak var nutCrackedStar: UIImageView!
    @IBOutlet weak var placeIconView: UIImageView!

    static var _highlightedPlaceIconImage: UIImage?
    class var highlightedPlaceIconImage: UIImage {
        if _highlightedPlaceIconImage == nil {
            _highlightedPlaceIconImage = UIImage(named: "placeSmallIcon")!.withRenderingMode(UIImageRenderingMode.alwaysOriginal)
        }
        return _highlightedPlaceIconImage!
    }
 
    static var _defaultPlaceIconImage: UIImage?
    class var defaultPlaceIconImage: UIImage {
        if _defaultPlaceIconImage == nil {
            _defaultPlaceIconImage = UIImage(named: "placeSmallIcon")!.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        }
        return _defaultPlaceIconImage!
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated:animated)
        
        // Configure the view for the highlighted state
        titleLabel.isHighlighted = highlighted
        locationLabel?.isHighlighted = highlighted
        repeatCountLabel.isHighlighted = highlighted
        nutCrackedStar.isHighlighted = highlighted
        placeIconView?.isHighlighted = highlighted
    }

    func configureCell(_ nutEvent: NutEvent) {
        titleLabel.text = nutEvent.title
        repeatCountLabel.text = "x " + String(nutEvent.itemArray.count)
        eventGroup = nutEvent
        nutCrackedStar.isHidden = true
        
        if !nutEvent.location.isEmpty {
            locationLabel.text = nutEvent.location
            placeIconView.isHidden = false
            placeIconView.image = EventListTableViewCell.defaultPlaceIconImage
            placeIconView.highlightedImage = EventListTableViewCell.highlightedPlaceIconImage
            placeIconView.tintColor = Styles.altDarkGreyColor
        }
        
        for item in nutEvent.itemArray {
            if item.nutCracked {
                nutCrackedStar.isHidden = false
                break
            }
        }
    }
}
