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

class TidepoolMobileUIViewWithHighlight: UIView {

    @IBInspectable var normalBackground: String = "" {
        didSet {
            if let backColor = Styles.usageToBackgroundColor[normalBackground] {
                updateNormalBackColor(backColor)
            }
        }
    }
    
    @IBInspectable var selectedBackground: String = "" {
        didSet {
            if let backColor = Styles.usageToBackgroundColor[selectedBackground] {
                updateSelectedBackColor(backColor)
            }
        }
    }

    @IBInspectable var highlightedBackground: String = "" {
        didSet {
            if let backColor = Styles.usageToBackgroundColor[highlightedBackground] {
                updateHighliteBackColor(backColor)
            }
        }
    }
    
    fileprivate var normalBackColor: UIColor?
    fileprivate var highliteBackColor: UIColor?
    fileprivate var selectedBackColor: UIColor?
    fileprivate func updateNormalBackColor(_ color: UIColor) {
        normalBackColor = color
        //self.backgroundColor = color
    }
    fileprivate func updateHighliteBackColor(_ color: UIColor) {
        highliteBackColor = color
    }
    fileprivate func updateSelectedBackColor(_ color: UIColor) {
        selectedBackColor = color
    }

    var highlighted: Bool = false {
        didSet {
            // Configure the view for the highlighted state
            if (highlighted) {
                if let highliteBackColor = highliteBackColor {
                    self.backgroundColor = highliteBackColor
                }
            } else if selected && selectedBackColor != nil {
                self.backgroundColor = selectedBackColor!
            } else {
                if let normalBackColor = normalBackColor {
                    self.backgroundColor = normalBackColor
                }
            }
        }
    }
    
    var selected: Bool = false {
        didSet {
            // Configure the view for the selected state, letting highlight take precedence
            if highlighted {
                return
            }
            if selected && selectedBackColor != nil {
                self.backgroundColor = selectedBackColor!
                return
            } else if let normalBackColor = normalBackColor {
                self.backgroundColor = normalBackColor
            }
        }
    }

}
