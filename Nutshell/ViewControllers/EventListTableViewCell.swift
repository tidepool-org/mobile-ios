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
    @IBOutlet weak var dateLabel: NutshellUILabel!
    @IBOutlet weak var repeatCountLabel: NutshellUILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    override func setHighlighted(highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated:animated)
        
        // Configure the view for the highlighted state
        titleLabel.highlighted = highlighted
        locationLabel.highlighted = highlighted
        dateLabel.highlighted = highlighted
        repeatCountLabel.highlighted = highlighted
    }

    func configureCell(nutEvent: NutEvent) {
        titleLabel.text = nutEvent.title
        locationLabel.text = nutEvent.location
        dateLabel.text = NutUtils.standardUIDateString(nutEvent.mostRecent, relative: true)
        repeatCountLabel.text = "x " + String(nutEvent.itemArray.count)
        eventGroup = nutEvent
        
       
    }
}
