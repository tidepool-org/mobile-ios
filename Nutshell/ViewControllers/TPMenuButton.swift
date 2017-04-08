//
//  TPMenuButton.swift
//  Nutshell
//
//  Created by Larry Kenyon on 4/8/17.
//  Copyright © 2017 Tidepool. All rights reserved.
//

import UIKit

/// Custom button class: creates a button with a rectangular image and an indented title overlayed on that image. Set styling and title in Interface Builder. Control colors of image and text in normal and highlighted states in the config lookups below.
@IBDesignable class TPMenuButton: UIButton {

    private enum ButtonTypeEnum {
        case unknownItem
        // Buttons
        case blueTextMenuButton
        case greyTextMenuButton
        case greyAddCommentButton
    }
    
    private let buttonTypeStringToEnum: [String: ButtonTypeEnum] = [
        "blueTextMenuButton": .blueTextMenuButton,
        "greyTextMenuButton": .greyTextMenuButton,
        "greyAddCommentButton": .greyAddCommentButton,
        ]

    private let buttonTypeToTextNormalColor: [ButtonTypeEnum: UIColor] = [
        .blueTextMenuButton: Styles.brightBlueColor,
        .greyTextMenuButton: Styles.mediumLightGreyColor,
        .greyAddCommentButton: Styles.mediumLightGreyColor,
    ]
    
    private let buttonTypeToTextHighlightColor: [ButtonTypeEnum: UIColor] = [
        .blueTextMenuButton: Styles.whiteColor,
        .greyTextMenuButton: Styles.whiteColor,
        .greyAddCommentButton: Styles.whiteColor,
    ]

    private let buttonTypeToBackgroundNormalColor: [ButtonTypeEnum: UIColor] = [
        .blueTextMenuButton: UIColor.clear,
        .greyTextMenuButton: UIColor.clear,
        .greyAddCommentButton: UIColor.clear,
    ]
    
    private let buttonTypeToBackgroundHighlightColor: [ButtonTypeEnum: UIColor] = [
        .blueTextMenuButton: Styles.brightBlueColor,
        .greyTextMenuButton: Styles.brightBlueColor,
        .greyAddCommentButton: Styles.brightBlueColor,
    ]

    private let buttonTypeToTextAlignment: [ButtonTypeEnum: NSTextAlignment] = [
        .blueTextMenuButton: .left,
        .greyTextMenuButton: .left,
        .greyAddCommentButton: .center,
        ]

    @IBInspectable var buttonStyling: String = "" {
        didSet {
            stylingEnum = buttonTypeStringToEnum[buttonStyling]!
            #if TARGET_INTERFACE_BUILDER
                updateStyle()
            #endif
        }
    }
    
    @IBInspectable var buttonTitle: String = "" {
        didSet {
            #if TARGET_INTERFACE_BUILDER
                updateStyle()
            #endif
        }
    }

    private var stylingEnum: ButtonTypeEnum = .unknownItem
    private var styledToSize: CGSize?
    
    override func checkAdjustSizing() {
        if styledToSize == nil || styledToSize! != self.bounds.size {
            updateStyle()
        }
    }
    
    func updateStyle() {
        if let textColor = buttonTypeToTextNormalColor[stylingEnum], let backColor = buttonTypeToBackgroundNormalColor[stylingEnum], let textAlign = buttonTypeToTextAlignment[stylingEnum] {
            if let image = imageForButton(textColor: textColor, backColor: backColor, textAlign: textAlign) {
                self.setImage(image, for: UIControlState.normal)
            }
        }
        
        if let textColor = buttonTypeToTextHighlightColor[stylingEnum], let backColor = buttonTypeToBackgroundHighlightColor[stylingEnum], let textAlign = buttonTypeToTextAlignment[stylingEnum] {
            if let image = imageForButton(textColor: textColor, backColor: backColor, textAlign: textAlign) {
                self.setImage(image, for: UIControlState.highlighted)
            }
        }
        styledToSize = self.bounds.size
    }
    
    private func imageForButton(textColor: UIColor, backColor: UIColor, textAlign: NSTextAlignment) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0)
        drawRectShape(self.bounds.size, textColor: textColor, backColor: backColor, textAlign: textAlign)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

//    private func drawRoundRectShape(_ size: CGSize, fillColor: UIColor, radius: CGFloat) {
//        let backgroundPath = UIBezierPath(roundedRect: CGRect(x:0, y:0, width:size.width, height:size.height), cornerRadius: radius)
//        fillColor.setFill()
//        backgroundPath.fill()
//    }

    private let titleIndent: CGFloat = 18.0
    private func drawRectShape(_ size: CGSize, textColor: UIColor, backColor: UIColor, textAlign: NSTextAlignment) {
        let context = UIGraphicsGetCurrentContext()!
        let rectangleRect = CGRect(x:0, y:0, width:size.width, height:size.height)
        let rectangleInset = CGRect(x:titleIndent, y:0, width:size.width-titleIndent, height:size.height)
        let rectanglePath = UIBezierPath(rect: rectangleRect)
        backColor.setFill()
        rectanglePath.fill()
        
        let rectangleTextContent = buttonTitle
        let rectangleStyle = NSMutableParagraphStyle()
        rectangleStyle.alignment = textAlign
        let rectangleFontAttributes = [NSFontAttributeName: Styles.mediumSmallRegularFont, NSForegroundColorAttributeName: textColor, NSParagraphStyleAttributeName: rectangleStyle]
        
        let rectangleTextHeight: CGFloat = rectangleTextContent.boundingRect(with: CGSize(width: rectangleInset.width, height: CGFloat.infinity), options: .usesLineFragmentOrigin, attributes: rectangleFontAttributes, context: nil).height
        context.saveGState()
        context.clip(to: rectangleInset)
        rectangleTextContent.draw(in: CGRect(x: rectangleInset.minX, y: rectangleInset.minY + (rectangleInset.height - rectangleTextHeight) / 2, width: rectangleInset.width, height: rectangleTextHeight), withAttributes: rectangleFontAttributes)

    }
}
