//
//  ConstantsAndStyle.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/8/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

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

// MARK: - UIFont constants

/*
Username label (NoteCell)
*/

let listItemFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 17)!

/*
Username label (NoteCell)
*/
let eventItemTitleFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 16)!

/*
Username label (NoteCell)
*/
let eventItemSubtitleFont: UIFont = UIFont(name: "OpenSans-Regular", size: 12.5)!


// MARK: - UIColor constants
// TODO: decide whether to go this route, or the generated colors from PaintCode...

let basicTableBackgroundColor: UIColor = UIColor(hex: 0xf2f3f5)

// MARK: - API Connector
// ------------ API Connector ------------

let unknownError: String = NSLocalizedString("Unknown Error Occurred", comment: "unknownError")
let unknownErrorMessage: String = NSLocalizedString("An unknown error occurred. We are working hard to resolve this issue.", comment: "unknownErrorMessage")
/*
(Change the server)
*/
var baseURL: String = servers["Production"]!
let servers: [String: String] = [
    "Production": "https://api.tidepool.io",
    "Development": "https://devel-api.tidepool.io",
    "Staging": "https://staging-api.tidepool.io"
]


