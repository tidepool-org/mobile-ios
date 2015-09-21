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

class EventGroupTableViewCell: NutshellUITableViewCell {

    var eventItem: NutMeal?
    
    @IBOutlet weak var favoriteStar: UIImageView!
    @IBOutlet weak var titleString: UILabel!
    @IBOutlet weak var timeString: UILabel!
    @IBOutlet weak var locationString: UILabel!
    @IBOutlet weak var photoImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    private var df: NSDateFormatter?
    private func dateFormatter() -> NSDateFormatter {
        if let df = self.df {
            return df
        } else {
            let df = NSDateFormatter()
            df.dateFormat = uniformDateFormat
            self.df = df
            return df
        }
    }
    
    func configureCell(eventItem: NutMeal) {
        titleString.text = eventItem.notes
        let df = NSDateFormatter()
        df.dateFormat = uniformDateFormat
        timeString.text = dateFormatter().stringFromDate(eventItem.time)
        locationString.text = eventItem.location
        self.eventItem = eventItem
    }
}
