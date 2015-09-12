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


