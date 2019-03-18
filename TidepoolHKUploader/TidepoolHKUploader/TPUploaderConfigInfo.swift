/*
 * Copyright (c) 2019, Tidepool Project
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

public protocol HKUploaderConfigInfo {
    func sessionToken() -> String?
    func baseURL() -> URL?
    func currentService() -> String
    func currentUserId() -> String?     // current logged in user id
    func isDSAUser() -> Bool            // account for current user is a DSA
    func isConnectedToNetwork() -> Bool
    // get/set variables
    var bioSex: String? { get set }
    
    func logVerbose(_ str: String)
    func logError(_ str: String)
    // optional?
    func trackMetric(_ metric: String)
}

