//
//  NutshellUITableViewCell.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/13/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

// This intermediate class is used to enable UITableView views in storyboards to show backgrounds with NutshellStyles coloring.

@IBDesignable class NutshellUITableViewCell: UITableViewCell {
    
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