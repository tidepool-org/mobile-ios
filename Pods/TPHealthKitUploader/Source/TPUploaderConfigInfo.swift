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

/// User of the TPHealthKitUploader framework must configure the framework passing an object with this protocol which the framework will use as documented below.
public protocol TPUploaderConfigInfo {
    /// TODO: require a call instead?
    func isConnectedToNetwork() -> Bool
    /// Nil when logged out
    func sessionToken() -> String?
    /// base string to constuct url for current service.
    func baseUrlString() -> String?
    // optional?
    func trackMetric(_ metric: String)

    func currentUserId() -> String?     // current logged in user id
    func isDSAUser() -> Bool            // account for current user is a DSA
    var currentUserName: String? { get }
    var bioSex: String? { get set }
    
    // logging callbacks...
    func logVerbose(_ str: String)
    func logError(_ str: String)
    func logInfo(_ str: String)
    func logDebug(_ str: String)
}

