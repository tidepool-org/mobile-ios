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

@IBDesignable class NutshellUITextField: UITextField {
    
    @IBInspectable var usage: String = "" {
        didSet {
            updateStyling()
        }
    }
    
    private func updateStyling() {
        if let backColor = Styles.usageToBackgroundColor[usage] {
            self.backgroundColor = backColor
        }
        if let (font, textColor) = Styles.usageToFontWithColor[usage] {
            self.font = font
            self.textColor = textColor
        }
        if usage == "userDataEntry" {
            paddingLeft = 20.0
        } else {
            paddingLeft = 0.0
        }
    }
    
    var paddingLeft: CGFloat = 0.0
    
    override func textRectForBounds(bounds: CGRect) -> CGRect {
        return self.newBounds(bounds)
    }
    
    override func placeholderRectForBounds(bounds: CGRect) -> CGRect {
        return self.newBounds(bounds)
    }
    
    override func editingRectForBounds(bounds: CGRect) -> CGRect {
        return self.newBounds(bounds)
    }
    
    private func newBounds(bounds: CGRect) -> CGRect {
        
        var newBounds = bounds
        newBounds.origin.x += paddingLeft
        newBounds.size.width -= paddingLeft
        return newBounds
    }
}