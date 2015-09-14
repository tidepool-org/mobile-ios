//
//  NutshellUIView.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/13/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import UIKit

// This would be more useful if there was support for enums; right now this uses known string value to communicate the usage from the storyboard to this class, which sets the background color of the UIView based on this usage and the Styles color variables.

@IBDesignable class NutshellUIView: UIView {
    
    @IBInspectable var usage: String = "" {
        didSet {
            updateBackgroundColor()
        }
    }
    
    private func updateBackgroundColor() {
        if let backColor = Styles.usageToColor[usage] {
            self.backgroundColor = backColor
        }
    }
}

