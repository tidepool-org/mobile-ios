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

import Foundation
import UIKit

// This would be more useful if there was support for enums; right now this uses known string value to communicate the usage from the storyboard to this class, which sets the background color of the UIView based on this usage and the Styles color variables.

@IBDesignable class NutshellUIView: UIView {
    
    @IBInspectable var usage: String = "" {
        didSet {
            updateBackgroundColor()
        }
    }
    
    fileprivate func updateBackgroundColor() {
        if let backColor = Styles.usageToBackgroundColor[usage] {
            self.backgroundColor = backColor
        }
    }
}

