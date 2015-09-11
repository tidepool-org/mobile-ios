//  Copyright (c) 2015, Tidepool Project
//  All rights reserved.
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//  1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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


