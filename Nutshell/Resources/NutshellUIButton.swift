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

// This intermediate class is used to enable UITextField views in storyboards to have fonts and backgrounds determined by NutshellStyles data.

@IBDesignable class NutshellSimpleUIButton: UIButton {
    
    @IBInspectable var usage: String = "" {
        didSet {
            updateStyling()
        }
    }
    
    fileprivate func updateStyling() {
        if let (font, textColor) = Styles.usageToFontWithColor[usage] {
            if let titleLabel = titleLabel {
                titleLabel.textColor = textColor
                titleLabel.font = font
            }
        }
    }
}

@IBDesignable class NutshellUIButton: UIButton {
    
    @IBInspectable var usage: String = "" {
        didSet {
            updateStyling()
        }
    }
    
    fileprivate func updateStyling() {
        if let image = Styles.backgroundImageofSize(self.bounds.size, style: usage) {
            self.setBackgroundImage(image, for: UIControlState())
            self.setBackgroundImage(image, for: UIControlState.disabled)
        }
        // Really shouldn't know about actual colors here, but shortcut to put in a reversed background color when button is pressed. Note this only supports 2 background colors!
        let reversedUsage = usage == "darkBackgroundButton" ? "brightBackgroundButton" : "darkBackgroundButton"
        if let image = Styles.backgroundImageofSize(self.bounds.size, style: reversedUsage) {
            self.setBackgroundImage(image, for: UIControlState.highlighted)
        }
        if let (font, textColor) = Styles.usageToFontWithColor[usage] {
            if let titleLabel = titleLabel {
                titleLabel.textColor = textColor
                titleLabel.font = font
                // Shortcut: this means the button only works with a single font color for disabled buttons: dimmedWhiteColor!
                if let titleStr = titleLabel.text {
                    let disabledTitle = NSAttributedString(string: titleStr, attributes:[NSFontAttributeName: titleLabel.font, NSForegroundColorAttributeName: Styles.dimmedWhiteColor])
                    self.setAttributedTitle(disabledTitle, for: UIControlState.disabled)
                }
            }
        }
    }
}
