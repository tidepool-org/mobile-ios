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
    static var configDebugger: TPUploaderConfigInfo?
    
    //
    // MARK: - public enums
    //
    public enum Mode: String {
        case Current = "Current"
        case HistoricalAll = "HistoricalAll"
    }
    
    public enum StoppedReason {
        case error(error: Error)
        case backgroundTimeExpired
        case interfaceTurnedOff
        case uploadingComplete
    }

    /// Configures framework
    public init(_ config: TPUploaderConfigInfo) {
        debugConfig = config // special copy to get debug output during init!
        DDLogInfo("TPUploader init - version 1.0.0")
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
    let settings = HKGlobalSettings.sharedInstance
    
    let hkUploadMgr: HealthKitUploadManager
    let hkMgr: HealthKitManager
    let hkConfig: HealthKitConfiguration
    
    //
    // MARK: - public methods
    //
    
    /**
     Call this whenever the current user changes, after login/logout, token refresh(?), connectivity changes, etc.
    */
    public func configure() {
        hkConfig.configureHealthKitInterface()
    }
    
    /**
     Does this device support HealthKit and is current logged in user account a DSA account?
    */
    public func shouldShowHealthKitUI() -> Bool {
        //DDLogVerbose("\(#function)")
        return hkMgr.isHealthDataAvailable && config.isDSAUser()
    }

    /**
     Have we already requested authorization for HK uploading?
    */
    public func authorizationRequestedForHKUpload() -> Bool {
        //DDLogVerbose("\(#function)")
        return hkMgr.authorizationRequestedForUploaderSamples()
    }

    /**
     Disables HealthKit for current user.
     
     Note: This does not NOT clear the current HealthKit user!
    */
    public func disableHealthKitInterface() {
        DDLogInfo("\(#function)")
        hkConfig.disableHealthKitInterface()
        // clear uploadId to be safe... also for logout.
        TPUploaderServiceAPI.connector!.currentUploadId = nil
    }

    /**
     Healthstore authorization is requested, and if successful, HealthKit is enabled for the current user.
     
     Note: If the currentUserId is not the same as the last healthkit user (i.e., HK user has been switched), a complete reset of the interface will be done as a side effect of the enable: global and mode-specific persistent variables will be reset, as well as current state.
     
     To Do: This API should take a completion routine as the call to Healthstore is asychronous.
    */
    public func enableHealthKitInterface() {
        DDLogInfo("\(#function)")
        hkConfig.enableHealthKitInterface()
    }

    /**
     Returns true only if the HealthKit interface is enabled and configured for the current user.
    */
    public func healthKitInterfaceEnabledForCurrentUser() -> Bool {
        DDLogInfo("\(#function)")
        return hkConfig.healthKitInterfaceEnabledForCurrentUser()
    }
    
    /**
     Returns true if the HealthKit interface has been configured for a tidepool id different from the current user - ignores whether the interface is currently enabled.
    */
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

    public func uploaderProgress() -> TPUploaderGlobalStats {
        return settings.currentProgress()
    }

    public func historicalUploadStats() -> [TPUploaderStats] {
        return hkUploadMgr.statsForMode(TPUploader.Mode.HistoricalAll)
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
    
    /**
     Resets persistent state for an upload mode (current or historical).
     
     Before calling this, ensure stopUploading for this mode has been called! For historical uploads, a reset followed by startUploading will start uploads at the previous current/historical time boundary. If .current is reset, the current/historical time boundary will be sent to kCurrentStartTimeInPast before the current time.
     
     - parameter mode: Either .current or .historical.
     */
    public func resetPersistentStateForMode(_ mode: TPUploader.Mode) {
        hkUploadMgr.resetPersistentStateForMode(mode)
    }
    
    public var hasPresentedSyncUI: Bool {
        get {
            return settings.hasPresentedSyncUI.value
        }
        set {
            settings.hasPresentedSyncUI.value = newValue
        }
    }

}
