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

func DDLogVerbose(_ str: String) {}
func DDLogInfo(_ str: String) {}
func DDLogDebug(_ str: String) {}
func DDLogError(_ str: String) {}

public class HKUploader {
    
    /// Nil if not instance not configured yet...
    public static var sharedInstance: HKUploader?
    
    /// Configures framework
    public init(_ config: HKUploaderConfigInfo) {
        // fail if already configured!
        self.config = config
        
        HKUploader.sharedInstance = self
    }
    private var config: HKUploaderConfigInfo
    
    /// Disables HealthKit for current user
    ///
    /// Note: This does not NOT clear the current HealthKit user!
    public func disableHealthKitInterface() {
        DDLogInfo("trace")
        HealthKitConfiguration.sharedInstance?.disableHealthKitInterface()
        // clear uploadId to be safe... also for logout.
        HKUploaderServiceAPI.connector!.currentUploadId = nil
    }


}
