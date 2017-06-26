//
//  UIViewExtension.swift
//  Nutshell
//
//  Copyright © 2017 Tidepool. All rights reserved.
//

import UIKit

extension UIView {
    // Use for common override, resizable views will override
    func checkAdjustSizing() {
    }
    
    // Adjust all resizable views in this view and its subview hierarchy
    // Mainly needed for resizable views with static text that is not updated after ViewDidLoad, to give them a chance to set their correct sizing
    func checkAdjustSubviewSizing() {
        for view in self.subviews {
            view.checkAdjustSubviewSizing()
        }
        self.checkAdjustSizing()
    }
}

