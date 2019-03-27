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

func DDLogVerbose(_ str: String) { TPUploader.sharedInstance?.config.logVerbose(str) }
func DDLogInfo(_ str: String) { TPUploader.sharedInstance?.config.logInfo(str) }
func DDLogDebug(_ str: String) { TPUploader.sharedInstance?.config.logDebug(str) }
func DDLogError(_ str: String) { TPUploader.sharedInstance?.config.logError(str) }

public class TPUploader {
    
    /// Nil if not instance not configured yet...
    public static var sharedInstance: TPUploader? 
    
    /// Configures framework
    public init(_ config: TPUploaderConfigInfo) {
        // fail if already configured!
        self.config = config
        self.service = TPUploaderServiceAPI(config)
        // configure this last, it might use the service to send up an initial timezone...
        self.tzTracker = TPTimeZoneTracker()
        TPUploader.sharedInstance = self
    }
    var config: TPUploaderConfigInfo
    var service: TPUploaderServiceAPI
    var tzTracker: TPTimeZoneTracker
    
    /// Disables HealthKit for current user
    ///
    /// Note: This does not NOT clear the current HealthKit user!
    public func disableHealthKitInterface() {
        DDLogInfo("trace")
        HealthKitConfiguration.sharedInstance?.disableHealthKitInterface()
        // clear uploadId to be safe... also for logout.
        TPUploaderServiceAPI.connector!.currentUploadId = nil
    }


}
