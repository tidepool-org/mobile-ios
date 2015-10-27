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
        "whiteBackground": whiteColor,
        // login & signup
        "brightBackgroundButton": brightBlueColor,
        "inactiveButton": veryLightGreyColor,
        "userDataEntry": whiteColor,
        // menu and account settings
        "rowSeparator": mediumDarkGreyColor,
        "darkBackgroundButton": darkPurpleColor,
        // add event scenes
        "saveButton": brightBlueColor,
        "doneButton": darkPurpleColor,
    ]

    // This table is used for mapping usage to font and font color for UI elements including fonts (UITextField, UILabel, UIButton). An entry may appear here as well as in the basic color mapping table above to set both font attributes as well as background coloring.
    static var usageToFontWithColor = [
        // login & signup
        "userDataEntry": (mediumRegularFont, darkPurpleColor),
        "dataEntryErrorFeedback": (smallSemiboldFont, pinkColor),
        "brightLinkText": (mediumRegularFont, brightBlueColor),
        "inactiveButton": (largeRegularFont, altDarkGreyColor),
        "brightBackgroundButton": (largeRegularFont, whiteColor),
        // event detail view
        "healthkitEventSubtext": (smallBoldFont, pinkColor),
        // table views
        "tableHeaderTitle": (veryLargeSemiboldFont, whiteColor),
        "tableHeaderLocation": (smallSemiboldFont, whiteColor),
        "tableHeaderCount": (smallBoldFont, whiteColor),
        "searchPlaceholder": (mediumLightFont, blackColor),
        "searchText": (largeRegularFont, blackColor),
        "tableListCellTitle": (mediumSemiboldFont, altDarkGreyColor),
        "tableListCellLocation": (smallSemiboldFont, altDarkGreyColor),
        "tableListCellDate": (verySmallRegularFont, altDarkGreyColor),
        "tableListCellRepeatCount": (smallBoldFont, altDarkGreyColor),
        "tableCellTitle": (mediumSemiboldFont, darkGreyColor),
        "tableCellSubtitle": (smallRegularFont, darkMediumGreyColor),
        "tableCellLocationDate": (smallRegularFont, whiteColor),
        "saveButton": (mediumBoldFont, whiteColor),
        // account configuration views
        "accountSettingItem": (mediumRegularFont, darkGreyColor),
        "accountSettingItemSmall": (mediumSmallRegularFont, darkGreyColor),
        "largeTargetValueInactive": (veryLargeSemiboldFont, mediumLightGreyColor),
        "largeTargetLow": (veryLargeSemiboldFont, peachColor),
        "largeTargetHigh": (veryLargeSemiboldFont, purpleColor),
        "darkBackgroundButton": (largeRegularFont, whiteColor),
        // event detail view
        "notesText": (UIFont(name: "OpenSans-Semibold", size: 16.0), whiteColor),
        "dateAndLocation": (UIFont(name: "OpenSans", size: 12.0), whiteColor),
        "advisoryText": (mediumSemiboldFont, darkGreyColor),
        "advisorySubtext": (mediumRegularFont, lightDarkGreyColor),
        "greenLink": (mediumRegularFont, lightGreenColor),
        // add event scenes
        "eventTitleText": (mediumLargeBoldFont, whiteColor),
        "doneButton": (largeRegularFont, whiteColor),

    ]

    class func backgroundImageofSize(size: CGSize, style: String) -> UIImage? {
        if let backColor = Styles.usageToBackgroundColor[style] {
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            // draw background
            let rectanglePath = UIBezierPath(rect: CGRectMake(0, 0, size.width, size.height))
            backColor.setFill()
            rectanglePath.fill()
            let backgroundImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return backgroundImage
        } else {
            return nil
        }
    }

    //
    // MARK: - Fonts
    //

    //// Cache
    
    private struct FontCache {
        static let smallRegularFont: UIFont = UIFont(name: "OpenSans", size: 12.5)!
        static let mediumRegularFont: UIFont = UIFont(name: "OpenSans", size: 17.0)!
        static let mediumSmallRegularFont: UIFont = UIFont(name: "OpenSans", size: 14.0)!
        static let mediumButtonRegularFont: UIFont = UIFont(name: "OpenSans", size: 15.0)!
        static let largeRegularFont: UIFont = UIFont(name: "OpenSans", size: 20.0)!
        
        static let smallSemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 11.0)!
        static let mediumSemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 17.0)!
        static let veryLargeSemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 25.5)!
        
        static let smallBoldFont: UIFont = UIFont(name: "OpenSans-Bold", size: 12.5)!
        static let mediumBoldFont: UIFont = UIFont(name: "OpenSans-Bold", size: 16.0)!
        static let mediumLargeBoldFont: UIFont = UIFont(name: "OpenSans-Bold", size: 17.5)!
        static let navTitleBoldFont: UIFont = UIFont(name: "OpenSans-Bold", size: 20.0)!
        
        static let mediumLightFont: UIFont = UIFont(name: "OpenSans-Light", size: 17.0)!
        
        // Fonts for special graph view
        
        static let verySmallRegularFont: UIFont = UIFont(name: "OpenSans", size: 10.0)!
        static let tinyRegularFont: UIFont = UIFont(name: "OpenSans", size: 8.5)!
        static let verySmallSemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 10.0)!
        static let veryTinySemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 8.0)!
    }
    
    static let uniformDateFormat: String = "MMM d, yyyy    h:mm a"

    public class var smallRegularFont: UIFont { return FontCache.smallRegularFont }
    public class var mediumRegularFont: UIFont { return FontCache.mediumRegularFont }
    public class var mediumSmallRegularFont: UIFont { return FontCache.mediumSmallRegularFont }
    public class var mediumButtonRegularFont: UIFont { return FontCache.mediumButtonRegularFont }
    public class var largeRegularFont: UIFont { return FontCache.largeRegularFont }

    public class var smallSemiboldFont: UIFont { return FontCache.smallSemiboldFont }
    public class var mediumSemiboldFont: UIFont { return FontCache.mediumSemiboldFont }
    public class var veryLargeSemiboldFont: UIFont { return FontCache.veryLargeSemiboldFont }

    public class var smallBoldFont: UIFont { return FontCache.smallBoldFont }
    public class var mediumBoldFont: UIFont { return FontCache.mediumBoldFont }
    public class var mediumLargeBoldFont: UIFont { return FontCache.mediumLargeBoldFont }
    public class var navTitleBoldFont: UIFont { return FontCache.navTitleBoldFont }

    public class var mediumLightFont: UIFont { return FontCache.mediumLightFont }

    // Fonts for special graph view
    
    public class var verySmallRegularFont: UIFont { return FontCache.verySmallRegularFont }
    public class var tinyRegularFont: UIFont { return FontCache.tinyRegularFont }
    public class var verySmallSemiboldFont: UIFont { return FontCache.verySmallSemiboldFont }
    public class var veryTinySemiboldFont: UIFont { return FontCache.veryTinySemiboldFont }

    //
    // MARK: - Background Colors
    //

    //// Cache
    
    private struct ColorCache {
        static let darkPurpleColor: UIColor = UIColor(hex: 0x281946)
        static let brightBlueColor: UIColor = UIColor(hex: 0x627cff) 
        static let lightGreyColor: UIColor = UIColor(hex: 0xeaeff0) 
        static let veryLightGreyColor: UIColor = UIColor(hex: 0xf2f3f5) 
        static let greyColor: UIColor = UIColor(hex: 0xd0d3d4) 
        static let redColor: UIColor = UIColor(hex: 0xf66f56) 
        static let pinkColor: UIColor = UIColor(hex: 0xf58fc7)
        static let lightPurpleColor: UIColor = UIColor(hex: 0xafbcfa)
        static let purpleColor: UIColor = UIColor(hex: 0xb29ac9)
        static let darkGreyColor: UIColor = UIColor(hex: 0x4a4a4a)
        static let lightDarkGreyColor: UIColor = UIColor(hex: 0x5c5c5c) 
        static let altDarkGreyColor: UIColor = UIColor(hex: 0x4d4e4c) 
        static let darkMediumGreyColor: UIColor = UIColor(hex: 0x8e8e8e) 
        static let mediumLightGreyColor: UIColor = UIColor(hex: 0xd0d3d4) 
        static let mediumGreyColor: UIColor = UIColor(hex: 0xb8b8b8) 
        static let whiteColor: UIColor = UIColor(hex: 0xffffff) 
        static let dimmedWhiteColor: UIColor = UIColor(hex: 0xffffff, opacity: 0.30)
        static let blackColor: UIColor = UIColor(hex: 0x000000)
        static let peachColor: UIColor = UIColor(hex: 0xf88d79)
        static let peachDeleteColor: UIColor = UIColor(hex: 0xf66f56)
        static let greenColor: UIColor = UIColor(hex: 0x98ca63)
        static let lightGreenColor: UIColor = UIColor(hex: 0x4cd964) 
        static let lightBlueColor: UIColor = UIColor(hex: 0xc5e5f1) 
        static let blueColor: UIColor = UIColor(hex: 0x7aceef) 
        static let mediumBlueColor: UIColor = UIColor(hex: 0x6db7d4) 
        static let goldColor: UIColor = UIColor(hex: 0xffd382) 
        static let lineColor: UIColor = UIColor(hex: 0x281946) 
        static let goldStarColor: UIColor = UIColor(hex: 0xf8ad04) 
        static let greyStarColor: UIColor = UIColor(hex: 0xd0d3d4) 
        static let mediumDarkGreyColor: UIColor = UIColor(hex: 0x979797) 
        static let lessOpaqueDarkPurple: UIColor  = UIColor(hex: 0x281946, opacity: 0.43) 
        static let moreOpaqueDarkPurple: UIColor  = UIColor(hex: 0x281946, opacity: 0.54) 
    }

    // Nav bar:     header
    // Button:      done button in account settings
    // View:        splash screen
    public class var darkPurpleColor: UIColor { return ColorCache.darkPurpleColor }

    // Table cell:  selected event
    // Button:      signup/login active, cancel for account settings,
    // View:        event title area in event detail
     public class var brightBlueColor: UIColor { return ColorCache.brightBlueColor }
    
    // View:        graph data left side
     public class var lightGreyColor: UIColor { return ColorCache.lightGreyColor }
    
    // Table cell:  event tables
    // Table background
    // View:        graph data right side
     public class var veryLightGreyColor: UIColor { return ColorCache.veryLightGreyColor }
    
    // Needed?
     public class var greyColor: UIColor { return ColorCache.greyColor }
    
    // Table cell delete swipe background
     public class var redColor: UIColor { return ColorCache.redColor }

    //
    // MARK: - Text Colors
    //
    
    // Open Sans Semibold 11:   UILabel login error text
    // Open Sans Bold 12:       UILabel event subtext for Apple Healthkit info
    public class var pinkColor: UIColor { return ColorCache.pinkColor }

    // Open Sans Regular 17:    UILabel? login default text over white background
     public class var lightPurpleColor: UIColor { return ColorCache.lightPurpleColor }

    // Over light grey background
    // Open Sans Regular 10:    custom graph axis text
    // Open Sans Regular 8.5:    custom graph axis text
    // Open Sans Semibold 17:   UILabel table cell title text
    // Open Sans Regular 17:    UILabel account settings item description
     public class var darkGreyColor: UIColor { return ColorCache.darkGreyColor }
    
    // Open Sans Regular 17:    UILabel event detail view, missing data upload text
     public class var lightDarkGreyColor: UIColor { return ColorCache.lightDarkGreyColor }

    // Open Sans Regular 15:    UIButton inactive login button text
     public class var altDarkGreyColor: UIColor { return ColorCache.altDarkGreyColor }

    // Open Sans Regular 12.5:    UILabel table cell subtext
     public class var darkMediumGreyColor: UIColor { return ColorCache.darkMediumGreyColor }

    // Open Sans Semibold 25.5:   UILabel account settings, target level text inactive
     public class var mediumLightGreyColor: UIColor { return ColorCache.mediumLightGreyColor }

    // Over dark purple background
    // OpenSans Semibold 16:    UILabel event subtext
     public class var mediumGreyColor: UIColor { return ColorCache.mediumGreyColor }

    // Open Sans Regular 20:    (Appearance) nav bar title, UILabel event title,
    // Open Sans Semibold 16:   UILabel event subtext
    // Open Sans Semibold 17:   UILabel table row item delete text, title text in highlighted row
    // Open Sans Regular 15:    UIButton active login, sign up button text
     public class var whiteColor: UIColor { return ColorCache.whiteColor }
     public class var dimmedWhiteColor: UIColor { return ColorCache.dimmedWhiteColor }
    
    // Open Sans Regular 17:    UITextField sign up text entries
    //class var brightBlueColor: UIColor { return brightBlueColor }

    // Open Sans Light 17:      Search placeholder text
    public class var blackColor: UIColor { return ColorCache.blackColor }

    // Open Sans Semibold 10:   custom graph carb amount text
    // Open Sans Semibold 4.5:    custom graph carb amount text
    //class var darkPurpleColor: UIColor { return ColorCache.darkPurpleColor }

    // target low and high, blood glucose graph
    // Open Sans Semibold 10:   custom graph blood glucose item text
    // Open Sans Semibold 25.5:   UILabel account settings, low level active
     public class var peachColor: UIColor { return ColorCache.peachColor }
    // Row cell delete button...
     public class var peachDeleteColor: UIColor { return ColorCache.peachDeleteColor }
    // Open Sans Semibold 10:   custom graph blood glucose item text
    // Open Sans Semibold 25.5:   UILabel account settings, high level active
     public class var purpleColor: UIColor { return ColorCache.purpleColor }
    // Open Sans Semibold 10:   custom graph glucose item text
     public class var greenColor: UIColor { return ColorCache.greenColor }

    // Open Sans Regular 17:   UILabel event detail view, missing data upload link text
     public class var lightGreenColor: UIColor { return ColorCache.lightGreenColor }

    //
    // MARK: - Graph Colors
    //
    
    // background, left side/right side
    // public class var lightGreyColor: UIColor { return lightGreyColor }
    // public class var veryLightGreyColor: UIColor { return veryLightGreyColor }
    
    // axis text
    // public class var darkGreyColor: UIColor { return darkGreyColor }
    
    // insulin bar
     public class var lightBlueColor: UIColor { return ColorCache.lightBlueColor }
     public class var blueColor: UIColor { return ColorCache.blueColor }
    // Open Sans Semibold 10:   custom graph insulin amount text
     public class var mediumBlueColor: UIColor { return ColorCache.mediumBlueColor }
    
    
    // blood glucose data
    // public class var peachColor: UIColor { return peachColor }
    // public class var purpleColor: UIColor { return purpleColor }
    // public class var greenColor: UIColor { return greenColor }
    
    // event carb amount circle and vertical line
     public class var goldColor: UIColor { return ColorCache.goldColor }
     public class var lineColor: UIColor { return ColorCache.lineColor }
    
    // health event bar
    // public class var pinkColor: UIColor { return pinkColor }

    //
    // MARK: - Misc Colors
    //
    
    // Icon:    favorite star colors
     public class var goldStarColor: UIColor { return ColorCache.goldStarColor }
     public class var greyStarColor: UIColor { return ColorCache.greyStarColor }

    // View:    table row line separator
     public class var mediumDarkGreyColor: UIColor { return ColorCache.mediumDarkGreyColor }

    // View:    transparency - screen overlays top and bottom
     public class var lessOpaqueDarkPurple: UIColor  { return ColorCache.lessOpaqueDarkPurple }
     public class var moreOpaqueDarkPurple: UIColor  { return ColorCache.moreOpaqueDarkPurple }

}
