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

public class TPUploader {
    
    /// Nil if not instance not configured yet...
    static var sharedInstance: TPUploader? 
    
    //
    // MARK: - public enums
    //
    public enum Mode: String {
        case Current = "Current"
        case HistoricalAll = "HistoricalAll"
    }
    
    public enum StoppedReason {
        case error(error: Error)
        case background
        case turnOffInterface
        case noResultsFromQuery
    }

    /// Configures framework
    public init(_ config: TPUploaderConfigInfo) {
        DDLogInfo("TPUploader init - version 1.0.0")
        // TODO: fail if already configured! Should probably just have the init private, and provide access via a connector() method like other singletons that require initialization data.
        self.config = config
        self.service = TPUploaderServiceAPI(config)
        // configure this last, it might use the service to send up an initial timezone...
        self.tzTracker = TPTimeZoneTracker()
        // TODO: allow this to be passed in as array of enums!
        self.hkConfig = HealthKitConfiguration.init(config, healthKitUploadTypes: [
            HealthKitUploadTypeBloodGlucose(),
            HealthKitUploadTypeCarb(),
            HealthKitUploadTypeInsulin(),
            HealthKitUploadTypeWorkout(),
            ])
        self.hkUploadMgr = HealthKitUploadManager.sharedInstance
        self.hkMgr = HealthKitManager.sharedInstance
        TPUploader.sharedInstance = self
    }
    var config: TPUploaderConfigInfo
    var service: TPUploaderServiceAPI
    var tzTracker: TPTimeZoneTracker
    let settings = GlobalSettings.sharedInstance
    
    let hkUploadMgr: HealthKitUploadManager
    let hkMgr: HealthKitManager
    let hkConfig: HealthKitConfiguration
    
    public func version() -> String {
        return "1.0.0-alpha"
    }
    
    //
    // MARK: - public methods
    //
    
    /// Call this whenever the current user changes, after login/logout, token refresh(?), ...
    public func configure() {
        hkConfig.configureHealthKitInterface()
    }
    
    /// Does this device support HealthKit and is current logged in user account a DSA account?
    public func shouldShowHealthKitUI() -> Bool {
        //DDLogVerbose("\(#function)")
        return hkMgr.isHealthDataAvailable && config.isDSAUser()
    }

    /// Have we already requested authorization for HK uploading?
    public func authorizationRequestedForHKUpload() -> Bool {
        //DDLogVerbose("\(#function)")
        return hkMgr.authorizationRequestedForUploaderSamples()
    }

    /// Disables HealthKit for current user
    ///
    /// Note: This does not NOT clear the current HealthKit user!
    public func disableHealthKitInterface() {
        DDLogInfo("\(#function)")
        hkConfig.disableHealthKitInterface()
        // clear uploadId to be safe... also for logout.
        TPUploaderServiceAPI.connector!.currentUploadId = nil
    }

    /// Enable HealthKit for current user.
    ///
    /// Note: This will force switch of HK user if necessary!
    public func enableHealthKitInterface() {
        DDLogInfo("\(#function)")
        hkConfig.enableHealthKitInterface()
    }

    /// Returns true only if the HealthKit interface is enabled and configured for the current user
    public func healthKitInterfaceEnabledForCurrentUser() -> Bool {
        DDLogInfo("\(#function)")
        return hkConfig.healthKitInterfaceEnabledForCurrentUser()
    }
    
    /// Returns true if the HealthKit interface has been configured for a tidepool id different from the current user - ignores whether the interface is currently enabled.
    public func healthKitInterfaceConfiguredForOtherUser() -> Bool {
        DDLogInfo("\(#function)")
        return hkConfig.healthKitInterfaceConfiguredForOtherUser()
    }

    public func curHKUserName() -> String? {
        return hkConfig.healthKitUserTidepoolUsername()
    }
    
    public func currentUploadStats() -> [TPUploaderStats] {
        return hkUploadMgr.statsForMode(TPUploader.Mode.Current)
    }

    public func historicalUploadStats() -> [TPUploaderStats] {
        return hkUploadMgr.statsForMode(TPUploader.Mode.HistoricalAll)
    }
    
    public func lastHistoricalUploadStats() -> (current: Int?, total: Int?, type: String?, date: Date?) {
        let historicalStats = historicalUploadStats()
        var current: Int?
        var total: Int?
        var lastUpload: Date?
        var lastType: String?
        for stat in historicalStats {
            // For now just return stats for the last type uploaded...
            if stat.hasSuccessfullyUploaded {
                if current == nil || total == nil || lastUpload == nil {
                    current = stat.currentDayHistorical
                    total = stat.totalDaysHistorical
                    lastUpload = stat.lastSuccessfulUploadTime
                    lastType = stat.typeName
                } else {
                    if lastUpload!.compare(stat.lastSuccessfulUploadTime) == .orderedAscending {
                        current = stat.currentDayHistorical
                        total = stat.totalDaysHistorical
                        lastUpload = stat.lastSuccessfulUploadTime
                    }
                }
            }
        }
        return (current: current, total: total, type: lastType, date: lastUpload)
    }
    
    public func lastCurrentUploadStats() -> (lastType: String?, lastTime: Date?) {
        var lastUploadTime: Date?
        var lastType: String?
        
        let currentStats = currentUploadStats()
        for stat in currentStats {
            if stat.hasSuccessfullyUploaded {
                if lastType == nil || lastUploadTime == nil {
                    lastUploadTime = stat.lastSuccessfulUploadTime
                    lastType = stat.typeName
                } else {
                    if stat.lastSuccessfulUploadTime.compare(lastUploadTime!) == .orderedDescending {
                        lastUploadTime = stat.lastSuccessfulUploadTime
                        lastType = stat.typeName
                    }
                }
            }
        }
        return (lastType: lastType, lastTime: lastUploadTime)
    }
    
    public func isUploadInProgressForMode(_ mode: TPUploader.Mode) -> Bool {
        return hkUploadMgr.isUploadInProgressForMode(mode)
    }
    
    public func startUploading(_ mode: TPUploader.Mode) {
        if let currentId = config.currentUserId() {
            hkUploadMgr.startUploading(mode: mode, currentUserId: currentId)
        } else {
            DDLogVerbose("ERR: startUploading ignored, no current user!")
        }
    }
    
    public func stopUploading(mode: TPUploader.Mode, reason: TPUploader.StoppedReason) {
        hkUploadMgr.stopUploading(mode: mode, reason: reason)
    }
    
    public func resetPersistentStateForMode(_ mode: TPUploader.Mode) {
        hkUploadMgr.resetPersistentStateForMode(mode)
    }
    
    public var hasPresentedSyncUI: Bool {
        get {
            return settings.boolForKey(.hasPresentedSyncUI)
        }
        set {
            settings.updateBoolForKey(.hasPresentedSyncUI, value: newValue)
        }
    }

}
