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
    convenience init(hex: UInt, opacity: Float) {
        self.init(
            red: CGFloat((hex & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((hex & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(hex & 0x0000FF) / 255.0,
            alpha: CGFloat(opacity)
        )
    }
    convenience init(hex: UInt) {
        self.init(hex: hex, opacity: 1.0)
    }
}

public class Styles: NSObject {

    // This table determines the background style design to color mapping in the UI. Setting "usage" variables in storyboards will determine color settings via this table; actual colors are defined below and can be changed globally there.
    static var usageToBackgroundColor = [
        "brightBackground": brightBlueColor,
        "darkBackground": darkPurpleColor,
        "lightBackground": veryLightGreyColor,
        // login & signup
        "activeLoginButton": brightBlueColor,
        "inactiveLoginButton": veryLightGreyColor,
        "userDataEntry": whiteColor,
        // menu and account settings
        "rowSeparator": mediumDarkGreyColor,
        "darkBackgroundButton": darkPurpleColor,
    ]

    // This table is used for mapping usage to font and font color for UI elements including fonts (UITextField, UILabel, UIButton). An entry may appear here as well as in the basic color mapping table above to set both font attributes as well as background coloring.
    static var usageToFontWithColor = [
        // login & signup
        "userDataEntry": (mediumRegularFont, brightBlueColor),
        "dataEntryErrorFeedback": (smallSemiboldFont, pinkColor),
        "brightLinkText": (mediumRegularFont, brightBlueColor),
        "inactiveLoginButton": (mediumButtonRegularFont, altDarkGreyColor),
        "activeLoginButton": (largeRegularFont, whiteColor),
        // event detail view
        "healthkitEventSubtext": (smallBoldFont, pinkColor),
        // table views
        "tableCellTitle": (mediumRegularFont, darkGreyColor),
        "tableCellSubtitle": (smallRegularFont, darkMediumGreyColor),
        // account configuration views
        "accountSettingItem": (mediumRegularFont, darkGreyColor),
        "accountSettingItemSmall": (mediumSmallRegularFont, darkGreyColor),
        "largeTargetValueInactive": (veryLargeSemiboldFont, mediumLightGreyColor),
        "largeTargetLow": (veryLargeSemiboldFont, peachColor),
        "largeTargetHigh": (veryLargeSemiboldFont, purpleColor),
        "darkBackgroundButton": (largeRegularFont, whiteColor),
        // graph view
        "advisoryText": (mediumSemiboldFont, darkGreyColor),
        "advisorySubtext": (mediumRegularFont, lightDarkGreyColor),
        "greenLink": (mediumRegularFont, lightGreenColor),
    ]

    //
    // MARK: - Fonts
    //
    class var smallRegularFont: UIFont { return UIFont(name: "OpenSans", size: 12.5)! }
    class var mediumRegularFont: UIFont { return UIFont(name: "OpenSans", size: 17.0)! }
    class var mediumSmallRegularFont: UIFont { return UIFont(name: "OpenSans", size: 14.0)! }
    class var mediumButtonRegularFont: UIFont { return UIFont(name: "OpenSans", size: 15.0)! }
    class var largeRegularFont: UIFont { return UIFont(name: "OpenSans", size: 22.0)! }

    class var smallSemiboldFont: UIFont { return UIFont(name: "OpenSans-Semibold", size: 11.0)! }
    class var mediumSemiboldFont: UIFont { return UIFont(name: "OpenSans-Semibold", size: 17.0)! }
    class var veryLargeSemiboldFont: UIFont { return UIFont(name: "OpenSans-Semibold", size: 25.5)! }

    class var smallBoldFont: UIFont { return UIFont(name: "OpenSans-Bold", size: 12.0)! }

    // Fonts for special graph view
    
    class var verySmallRegularFont: UIFont { return UIFont(name: "OpenSans", size: 10.0)! }
    class var tinyRegularFont: UIFont { return UIFont(name: "OpenSans", size: 8.5)! }
    class var verySmallSemiboldFont: UIFont { return UIFont(name: "OpenSans-Semibold", size: 10.0)! }
    class var veryTinySemiboldFont: UIFont { return UIFont(name: "OpenSans-Semibold", size: 4.5)! }

    //
    // MARK: - Background Colors
    //
    
    // Nav bar:     header
    // Button:      done button in account settings
    // View:        splash screen
    static var darkPurpleColor: UIColor { return UIColor(hex: 0x281946) }

    // Table cell:  selected event
    // Button:      signup/login active, cancel for account settings,
    // View:        event title area in event detail
    class var brightBlueColor: UIColor { return UIColor(hex: 0x627cff) }
    
    // View:        graph data left side
    class var lightGreyColor: UIColor { return UIColor(hex: 0xeaeff0) }
    
    // Table cell:  event tables
    // Table background
    // View:        graph data right side
    class var veryLightGreyColor: UIColor { return UIColor(hex: 0xf2f3f5) }
    
    // Needed?
    class var greyColor: UIColor { return UIColor(hex: 0xd0d3d4) }
    
    // Table cell delete swipe background
    class var redColor: UIColor { return UIColor(hex: 0xf66f56) }

    //
    // MARK: - Text Colors
    //
    
    // Open Sans Semibold 11:   UILabel login error text
    // Open Sans Bold 12:       UILabel event subtext for Apple Healthkit info
    class var pinkColor: UIColor { return UIColor(hex: 0xf58fc7) }

    // Open Sans Regular 17:    UILabel? login default text over white background
    class var lightPurpleColor: UIColor { return UIColor(hex: 0xafbcfa) }

    // Over light grey background
    // Open Sans Regular 10:    custom graph axis text
    // Open Sans Regular 8.5:    custom graph axis text
    // Open Sans Semibold 17:   UILabel table cell title text
    // Open Sans Regular 17:    UILabel account settings item description
    class var darkGreyColor: UIColor { return UIColor(hex: 0x4a4a4a) }
    
    // Open Sans Regular 17:    UILabel event detail view, missing data upload text
    class var lightDarkGreyColor: UIColor { return UIColor(hex: 0x5c5c5c) }

    // Open Sans Regular 15:    UIButton inactive login button text
    class var altDarkGreyColor: UIColor { return UIColor(hex: 0x4d4e4c) }

    // Open Sans Regular 12.5:    UILabel table cell subtext
    class var darkMediumGreyColor: UIColor { return UIColor(hex: 0x8e8e8e) }

    // Open Sans Semibold 25.5:   UILabel account settings, target level text inactive
    class var mediumLightGreyColor: UIColor { return UIColor(hex: 0xd0d3d4) }

    // Open Sans Semibold 10:   custom graph insulin amount text
    class var mediumBlueColor: UIColor { return UIColor(hex: 0x6db7d4) }

    // Over dark purple background
    // OpenSans Semibold 16:    UILabel event subtext
    class var mediumGreyColor: UIColor { return UIColor(hex: 0xb8b8b8) }

    // Open Sans Regular 20:    (Appearance) nav bar title, UILabel event title,
    // Open Sans Semibold 16:   UILabel event subtext
    // Open Sans Semibold 17:   UILabel table row item delete text, title text in highlighted row
    // Open Sans Regular 15:    UIButton active login, sign up button text
    class var whiteColor: UIColor { return UIColor(hex: 0xffffff) }
    // Open Sans Regular 17:    UITextField sign up text entries
    //class var brightBlueColor: UIColor { return UIColor(hex: 0x627cff) }
    
    // Open Sans Semibold 10:   custom graph carb amount text
    // Open Sans Semibold 4.5:    custom graph carb amount text
    //class var darkPurpleColor: UIColor { return UIColor(hex: 0x281946) }

    // target low and high, blood glucose graph
    // Open Sans Semibold 10:   custom graph blood glucose item text
    // Open Sans Semibold 25.5:   UILabel account settings, low level active
    class var peachColor: UIColor { return UIColor(hex: 0xf88d79) }
    // Open Sans Semibold 10:   custom graph blood glucose item text
    // Open Sans Semibold 25.5:   UILabel account settings, high level active
    class var purpleColor: UIColor { return UIColor(hex: 0xb29ac9) }
    // Open Sans Semibold 10:   custom graph glucose item text
    class var greenColor: UIColor { return UIColor(hex: 0x98ca63) }

    // Open Sans Regular 17:   UILabel event detail view, missing data upload link text
    class var lightGreenColor: UIColor { return UIColor(hex: 0x4cd964) }

    //
    // MARK: - Graph Colors
    //
    
    // background, left side/right side
    //class var lightGreyColor: UIColor { return UIColor(hex: 0xeaeff0) }
    //class var veryLightGreyColor: UIColor { return UIColor(hex: 0xf2f3f5) }
    
    // axis text
    //class var darkGreyColor: UIColor { return UIColor(hex: 0x4a4a4a) }
    
    // insulin bar
    class var lightBlueColor: UIColor { return UIColor(hex: 0xc5e5f1) }
    class var blueColor: UIColor { return UIColor(hex: 0x7aceef) }
    //class var mediumBlueColor: UIColor { return UIColor(hex: 0x6db7d4) }
    
    // blood glucose data
    //class var peachColor: UIColor { return UIColor(hex: 0xf88d79) }
    //class var purpleColor: UIColor { return UIColor(hex: 0xb29ac9) }
    //class var greenColor: UIColor { return UIColor(hex: 0x98ca63) }
    
    // event carb amount circle and vertical line
    class var goldColor: UIColor { return UIColor(hex: 0xffd382) }
    class var lineColor: UIColor { return UIColor(hex: 0x281946) }
    
    // health event bar
    //class var pinkColor: UIColor { return UIColor(hex: 0xf58fc7) }

    //
    // MARK: - Misc Colors
    //
    
    // Icon:    favorite star colors
    class var goldStarColor: UIColor { return UIColor(hex: 0xf8ad04) }
    class var greyStarColor: UIColor { return UIColor(hex: 0xd0d3d4) }

    // View:    table row line separator
    class var mediumDarkGreyColor: UIColor { return UIColor(hex: 0x979797) }

    // View:    transparency - screen overlays top and bottom
    class var lessOpaqueDarkPurple: UIColor  { return UIColor(hex: 0x281946, opacity: 0.43) }
    class var moreOpaqueDarkPurple: UIColor  { return UIColor(hex: 0x281946, opacity: 0.54) }

}
