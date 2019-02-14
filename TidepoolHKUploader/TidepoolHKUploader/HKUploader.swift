//
//  HKUploader.swift
//  TidepoolHKUploader
//
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

func DDLogVerbose(_ str: String) {}
func DDLogInfo(_ str: String) {}
func DDLogDebug(_ str: String) {}
func DDLogError(_ str: String) {}

public class HKUploader {
    
    public let sharedInstance = HKUploader()
    
    /// Disables HealthKit for current user
    ///
    /// Note: This does not NOT clear the current HealthKit user!
    func disableHealthKitInterface() {
        DDLogInfo("trace")
        HealthKitConfiguration.sharedInstance?.disableHealthKitInterface()
        // clear uploadId to be safe... also for logout.
        TPUploaderServiceAPI.connector!.currentUploadId = nil
    }


}
