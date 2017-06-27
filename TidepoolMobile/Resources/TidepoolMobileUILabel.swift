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

// This intermediate class is used to enable UITextField views in storyboards to have fonts and backgrounds determined by TidepoolMobileStyles data.

@IBDesignable class TidepoolMobileUILabel: UILabel {
    
    @IBInspectable var usage: String = "" {
        didSet {
            updateStyling()
        }
    }
    
    fileprivate func updateStyling() {
        if let backColor = Styles.usageToBackgroundColor[usage] {
            self.backgroundColor = backColor
        }
        if let (font, textColor) = Styles.usageToFontWithColor[usage] {
            self.font = font
            self.textColor = textColor
        }
    }
}
