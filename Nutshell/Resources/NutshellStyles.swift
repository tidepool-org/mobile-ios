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

extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((hex & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(hex & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}

// Experiment with IBDesignables. This would be more useful if there was support for enums; right now this uses a series of booleans, but at most one will have any effect.

@IBDesignable class BackgroundUIView: UIView {
    
    private enum Placement: String {
        case unspecified = "unspecified"
        case darkScene = "dark scene"
        case lightTable = "light table"
    }
    
    @IBInspectable var isDarkScene: Bool = false {
        didSet {
            if (isDarkScene) {
                self.placement = Placement.darkScene
            }
         }
    }

    @IBInspectable var isLightTable: Bool = false {
        didSet {
            if (isLightTable) {
                self.placement = Placement.lightTable
            }
        }
    }

    private var placement: Placement! {
        didSet {
            updateBackgroundColor()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.placement = Placement.unspecified
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.placement = Placement.unspecified
    }
    
    private func updateBackgroundColor() {
        switch self.placement! {
        case Placement.darkScene:
            self.backgroundColor = Styles.darkBackground
        case Placement.lightTable:
            self.backgroundColor = Styles.tableLightBkgndColor
        case Placement.unspecified:
            self.backgroundColor = UIColor.clearColor()
        }
     }
}

public class Styles: NSObject {

    
    //// Cache

    private struct Cache {
        static var darkBackground: UIColor = UIColor(red: 0.157, green: 0.098, blue: 0.275, alpha: 1.000)
        static var brightBackground: UIColor = UIColor(red: 0.384, green: 0.486, blue: 1.000, alpha: 1.000)
        static var listItemDeleteBackground: UIColor = UIColor(red: 0.965, green: 0.435, blue: 0.337, alpha: 1.000)
        static var tableLightBkgndColor: UIColor = UIColor(red: 0.949, green: 0.953, blue: 0.961, alpha: 1.000)
    }

    //// Colors

    class var darkBackground: UIColor { return Cache.darkBackground }
    class var brightBackground: UIColor { return Cache.brightBackground }
    class var listItemDeleteBackground: UIColor { return Cache.listItemDeleteBackground }
    class var tableLightBkgndColor: UIColor { return Cache.tableLightBkgndColor }

}
