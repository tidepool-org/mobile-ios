//
//  DebugLog.swift
//  TPHealthKitUploader
//
//  Created by Larry Kenyon on 3/6/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

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
