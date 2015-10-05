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

class EventListTableViewCell: NutshellUITableViewCell {

    var eventGroup: NutEvent?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func configureCell(nutEvent: NutEvent) {
        let titleLabelStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        titleLabelStyle.alignment = .Left
        titleLabelStyle.lineBreakMode = .ByTruncatingMiddle
        let titleAttrStr = NSMutableAttributedString(string: nutEvent.title, attributes: [NSFontAttributeName: Styles.mediumSemiboldFont, NSForegroundColorAttributeName: Styles.altDarkGreyColor, NSParagraphStyleAttributeName: titleLabelStyle])
        
        // Append an item count in small font if there are more than one of these
        if nutEvent.itemArray.count > 1 {
            let suffixStr = " (" + String(nutEvent.itemArray.count) + ")"
            let suffixAttrStr = NSAttributedString(string: suffixStr, attributes: [NSFontAttributeName: Styles.smallRegularFont, NSForegroundColorAttributeName: Styles.altDarkGreyColor, NSParagraphStyleAttributeName: titleLabelStyle])
            titleAttrStr.appendAttributedString(suffixAttrStr)
        }
        textLabel?.attributedText = titleAttrStr
        eventGroup = nutEvent
    }
}
