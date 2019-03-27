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

/// Include these here to translate debug functions into protocol calls
func DDLogInfo(_ message: @autoclosure () -> String,  file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    TPUploader.sharedInstance?.config.logInfo(String("HKUploader[\(function):\(line)] \(message())"))
}

func DDLogDebug(_ message: @autoclosure () -> String,  file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    TPUploader.sharedInstance?.config.logDebug(String("HKUploader[\(function):\(line)] \(message())"))
}

func DDLogError(_ message: @autoclosure () -> String,  file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    TPUploader.sharedInstance?.config.logError(String("HKUploader[\(function):\(line)] \(message())"))
}

func DDLogVerbose(_ message: @autoclosure () -> String,  file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    TPUploader.sharedInstance?.config.logVerbose(String("HKUploader[\(function):\(line)] \(message())"))
}
