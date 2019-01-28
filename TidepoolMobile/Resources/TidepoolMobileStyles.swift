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

open class Styles: NSObject {

    // This table determines the background style design to color mapping in the UI. Setting "usage" variables in storyboards will determine color settings via this table; actual colors are defined below and can be changed globally there.
    static var usageToBackgroundColor = [
        // general usage
        "brightBackground": brightBlueColor,
        "darkBackground": darkPurpleColor,
        "lightBackground": veryLightGreyColor,
        "whiteBackground": whiteColor,
        // login & signup
        "brightBackgroundButton": brightBlueColor,
        "userDataEntry": whiteColor,
        // menu and account settings
        "rowSeparator": dimmedDarkGreyColor,
        "darkBackgroundButton": darkPurpleColor,
        // list scene
        "editButton" : UIColor.clear,
        // add/edit event scenes
        "loginButton": brightBlueColor,
    ]

    // This table is used for mapping usage to font and font color for UI elements including fonts (UITextField, UILabel, UIButton). An entry may appear here as well as in the basic color mapping table above to set both font attributes as well as background coloring.
    static var usageToFontWithColor = [
        // general usage
        "brightBackgroundButton": (largeRegularFont, whiteColor),
        "loginButton": (largeSemiboldFont, whiteColor),
        // login & signup scenes
        "userDataEntry": (largeRegularFont, blackColor),
        "dataEntryErrorFeedback": (mediumSemiboldFont, redErrorColor),
        "forgotPasswordText": (mediumRegularFont, warmGreyColor),
        "networkDisconnectText" : (largeRegularFont, whiteColor),
        // event list table scene
        "profileCellNameText": (mediumSmallRegularFont, darkPurpleColor),
        "searchPlaceholder": (mediumLightFont, blackColor),
        "editButton" : (smallRegularFont, brightBlueColor),
        "addCommentText" : (mediumSmallSemiboldFont,mediumLightGreyColor),
        "commentUserText": (smallSemiboldFont, darkGreyColor),
        "commentDateText": (smallRegularFont, altLightGreyColor),
        // grouped event list table scene
        "groupedEventCellDate": (smallRegularFont, altDarkGreyColor),
        "groupedEventToolTip": (smallRegularFont, warmGreyColor),
        // event detail view scene
        // event detail graph area
        // add/edit event scenes
        // account configuration scene
        "sidebarSettingUserName": (mediumSmallSemiboldFont, brightBlueColor),
        "sidebarSettingItemSmall": (verySmallRegularFont, altDarkGreyColor),
        "sidebarLogoutButton": (mediumSemiboldFont, darkGreyColor),
        "sidebarOtherLinks": (mediumSmallRegularFont, mediumLightGreyColor),
        "sidebarSettingHKEnable": (mediumSmallRegularFont, darkPurpleColor),
        "sidebarSettingHKMainStatus": (smallSemiboldFont, mediumLightGreyColor),
        "sidebarSettingHKMinorStatus": (smallRegularFont, mediumLightGreyColor),
        // first time tips
        "firstTimeTipText": (mediumSmallSemiboldFont, whiteColor),
        "darkBackgroundButton": (mediumVerySmallSemiboldFont, whiteColor),
    ]

    class func backgroundImageofSize(_ size: CGSize, style: String) -> UIImage? {
        if let backColor = Styles.usageToBackgroundColor[style] {
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            // draw background
            let rectanglePath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            backColor.setFill()
            rectanglePath.fill()
            let backgroundImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return backgroundImage
        } else {
            return nil
        }
    }

    class func configureTidepoolBarColoring(on: Bool) {
        UINavigationBar.appearance().barTintColor = Styles.darkPurpleColor
        UINavigationBar.appearance().isTranslucent = false
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white, NSAttributedString.Key.font: Styles.navTitleFont]
    }

    //
    // MARK: - Fonts
    //

    //// Cache
    
    fileprivate struct FontCache {
        static let verySmallRegularFont: UIFont = UIFont(name: "OpenSans", size: 10.0)!
        static let smallRegularFont: UIFont = UIFont(name: "OpenSans", size: 12.5)!
        static let mediumRegularFont: UIFont = UIFont(name: "OpenSans", size: 17.0)!
        static let mediumSmallRegularFont: UIFont = UIFont(name: "OpenSans", size: 15.0)!
        static let largeRegularFont: UIFont = UIFont(name: "OpenSans", size: 19.0)!
        
        static let smallSemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 12.5)!
        static let mediumSemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 17.0)!
        static let largeSemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 19.0)!
        static let mediumSmallSemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 15.0)!
        static let mediumVerySmallSemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 14.0)!
        static let veryLargeSemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 25.5)!
        
        static let smallBoldFont: UIFont = UIFont(name: "OpenSans-Bold", size: 12.5)!
        static let mediumSmallBoldFont: UIFont = UIFont(name: "OpenSans-Bold", size: 15.0)!
        static let mediumBoldFont: UIFont = UIFont(name: "OpenSans-Bold", size: 16.0)!
        static let mediumLargeBoldFont: UIFont = UIFont(name: "OpenSans-Bold", size: 17.5)!
        static let navTitleFont: UIFont = UIFont(name: "OpenSans", size: 17.5)!
        
        static let smallLightFont: UIFont = UIFont(name: "OpenSans-Light", size: 12.5)!
        static let mediumLightFont: UIFont = UIFont(name: "OpenSans-Light", size: 17.0)!
        
        // Fonts for special graph view
        
        static let tinyRegularFont: UIFont = UIFont(name: "OpenSans", size: 8.5)!
        static let verySmallSemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 10.0)!
        static let veryTinySemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 8.0)!
    }
    
    static let uniformDateFormat: String = "MMM d, yyyy    h:mm a"

    open class var smallRegularFont: UIFont { return FontCache.smallRegularFont }
    open class var mediumRegularFont: UIFont { return FontCache.mediumRegularFont }
    open class var mediumSmallRegularFont: UIFont { return FontCache.mediumSmallRegularFont }
    open class var largeRegularFont: UIFont { return FontCache.largeRegularFont }

    open class var smallSemiboldFont: UIFont { return FontCache.smallSemiboldFont }
    open class var mediumSemiboldFont: UIFont { return FontCache.mediumSemiboldFont }
    open class var largeSemiboldFont: UIFont { return FontCache.largeSemiboldFont }
    open class var mediumSmallSemiboldFont: UIFont { return FontCache.mediumSmallSemiboldFont }
    open class var mediumVerySmallSemiboldFont: UIFont { return FontCache.mediumVerySmallSemiboldFont }
    open class var veryLargeSemiboldFont: UIFont { return FontCache.veryLargeSemiboldFont }

    open class var smallBoldFont: UIFont { return FontCache.smallBoldFont }
    open class var mediumSmallBoldFont: UIFont { return FontCache.mediumSmallBoldFont }
    open class var mediumBoldFont: UIFont { return FontCache.mediumBoldFont }
    open class var mediumLargeBoldFont: UIFont { return FontCache.mediumLargeBoldFont }
    open class var navTitleFont: UIFont { return FontCache.navTitleFont }

    open class var smallLightFont: UIFont { return FontCache.smallLightFont }
    open class var mediumLightFont: UIFont { return FontCache.mediumLightFont }

    // Fonts for special graph view
    
    open class var verySmallRegularFont: UIFont { return FontCache.verySmallRegularFont }
    open class var tinyRegularFont: UIFont { return FontCache.tinyRegularFont }
    open class var verySmallSemiboldFont: UIFont { return FontCache.verySmallSemiboldFont }
    open class var veryTinySemiboldFont: UIFont { return FontCache.veryTinySemiboldFont }

    //
    // MARK: - Background Colors
    //

    //// Cache
    
    fileprivate struct ColorCache {
        static let darkPurpleColor: UIColor = UIColor(hex: 0x281946)
        static let darkPurple75Color: UIColor = UIColor(hex: 0x281946, opacity: 0.75)
        static let lightGreyColor: UIColor = UIColor(hex: 0xeaeff0)
        static let altLightGreyColor: UIColor = UIColor(hex: 0xc9c9c9)
        static let alt2LightGreyColor: UIColor = UIColor(hex: 0xe2e3e4)
        static let veryLightGreyColor: UIColor = UIColor(hex: 0xF7F7F8)
        static let redErrorColor: UIColor = UIColor(hex: 0xff354e)
        static let pinkColor: UIColor = UIColor(hex: 0xf58fc7, opacity: 0.75)
        static let purpleColor: UIColor = UIColor(hex: 0xb29ac9)
        static let darkGreyColor: UIColor = UIColor(hex: 0x4a4a4a)
        static let lightDarkGreyColor: UIColor = UIColor(hex: 0x5c5c5c)//
        static let altDarkGreyColor: UIColor = UIColor(hex: 0x4d4e4c) 
        static let alt2DarkGreyColor: UIColor = UIColor(hex: 0x58595b)//
        static let dimmedDarkGreyColor: UIColor = UIColor(hex: 0x9da2a7
            , opacity: 0.5)
        static let warmGreyColor: UIColor = UIColor(hex: 0x9b9b9b)
        static let mediumLightGreyColor: UIColor = UIColor(hex: 0x7e7e7e)
        static let whiteColor: UIColor = UIColor(hex: 0xffffff)
        static let dimmedWhiteColor: UIColor = UIColor(hex: 0xffffff, opacity: 0.30)
        static let blackColor: UIColor = UIColor(hex: 0x000000)
        static let blackishColor: UIColor = UIColor(hex: 0x3c3c3c)
        static let peachColor: UIColor = UIColor(hex: 0xf88d79)
        static let greenColor: UIColor = UIColor(hex: 0x98ca63)
        static let lightBlueColor: UIColor = UIColor(hex: 0xc5e5f1)
        static let blueColor: UIColor = UIColor(hex: 0x7aceef) 
        static let mediumBlueColor: UIColor = UIColor(hex: 0x6db7d4) 
        static let brightBlueColor: UIColor = UIColor(hex: 0x627cff)
        static let goldColor: UIColor = UIColor(hex: 0xffd382)
    }

    open class var darkPurpleColor: UIColor { return ColorCache.darkPurpleColor }
    open class var darkPurple75Color: UIColor { return ColorCache.darkPurple75Color }
    open class var brightBlueColor: UIColor { return ColorCache.brightBlueColor }
    open class var lightGreyColor: UIColor { return ColorCache.lightGreyColor }
    open class var altLightGreyColor: UIColor { return ColorCache.altLightGreyColor }
    open class var alt2LightGreyColor: UIColor { return ColorCache.alt2LightGreyColor }
    open class var veryLightGreyColor: UIColor { return ColorCache.veryLightGreyColor }

    //
    // MARK: - Text Colors
    //
    
    open class var pinkColor: UIColor { return ColorCache.pinkColor }
    open class var redErrorColor: UIColor { return ColorCache.redErrorColor }
    open class var darkGreyColor: UIColor { return ColorCache.darkGreyColor }
    open class var lightDarkGreyColor: UIColor { return ColorCache.lightDarkGreyColor }
    open class var altDarkGreyColor: UIColor { return ColorCache.altDarkGreyColor }
    open class var alt2DarkGreyColor: UIColor { return ColorCache.alt2DarkGreyColor }
    open class var warmGreyColor: UIColor { return ColorCache.warmGreyColor }
    open class var mediumLightGreyColor: UIColor { return ColorCache.mediumLightGreyColor }
    open class var whiteColor: UIColor { return ColorCache.whiteColor }
    open class var dimmedWhiteColor: UIColor { return ColorCache.dimmedWhiteColor }
    open class var blackColor: UIColor { return ColorCache.blackColor }
    open class var blackishColor: UIColor { return ColorCache.blackishColor }
    open class var peachColor: UIColor { return ColorCache.peachColor }
    open class var purpleColor: UIColor { return ColorCache.purpleColor }
    open class var greenColor: UIColor { return ColorCache.greenColor }

    //
    // MARK: - Graph Colors
    //
    
    
    // insulin bar
    open class var lightBlueColor: UIColor { return ColorCache.lightBlueColor }
    open class var blueColor: UIColor { return ColorCache.blueColor }
    // Open Sans Semibold 10:   custom graph insulin amount text
    open class var mediumBlueColor: UIColor { return ColorCache.mediumBlueColor }
    
    // event carb amount circle
    open class var goldColor: UIColor { return ColorCache.goldColor }
    
    //
    // MARK: - Misc Colors
    //
    
    // View:    table row line separator
    open class var dimmedDarkGreyColor: UIColor { return ColorCache.dimmedDarkGreyColor }

    //
    // MARK: - Strings
    //
    
    open class var placeholderTitleString: String { return "Meal name" }
    open class var titleHintString: String { return "Simple and repeatable" }
    open class var placeholderNotesString: String { return "Notes" }
    open class var noteHintString: String { return "Sides, dessert, anything else?" }
    open class var placeholderLocationString: String { return "Location" }
    
}
