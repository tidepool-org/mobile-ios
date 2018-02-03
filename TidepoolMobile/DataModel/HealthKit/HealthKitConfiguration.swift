//
//  HealthKitConfiguration.swift
//  Urchin
//
//  Created by Larry Kenyon on 3/30/16.
//  Copyright © 2016 Tidepool. All rights reserved.
//

import HealthKit
import CocoaLumberjack

class HealthKitConfiguration
{    
    // MARK: Access, availability, authorization

    fileprivate(set) var currentUserId: String?
    fileprivate var isDSAUser: Bool?
    
    func shouldShowHealthKitUI() -> Bool {
        DDLogVerbose("trace")
        
        var result = false
        if let isDSAUser = isDSAUser {
            result = HealthKitManager.sharedInstance.isHealthDataAvailable && isDSAUser
        }
        DDLogInfo("result: \(result)")
        return result
    }
    
    /// Call this whenever the current user changes, at login/logout, token refresh(?), and upon enabling or disabling the HealthKit interface.
    func configureHealthKitInterface(_ userid: String?, isDSAUser: Bool?) {
        DDLogVerbose("trace")
        
        if !HealthKitManager.sharedInstance.isHealthDataAvailable {
            DDLogInfo("HKHealthStore data is not available")
            return
        }

        currentUserId = userid
        self.isDSAUser = isDSAUser
        
        var interfaceEnabled = true
        if currentUserId != nil  {
            interfaceEnabled = healthKitInterfaceEnabledForCurrentUser()
            if !interfaceEnabled {
                DDLogInfo("disable because not enabled for current user!")
            }
        } else {
            interfaceEnabled = false
            DDLogInfo("disable because no current user!")
        }
        
        if interfaceEnabled {
            DDLogInfo("enable!")
            self.turnOnInterface()
        } else {
            DDLogInfo("disable!")
            self.turnOffInterface()
        }
    }

    //
    // MARK: - Overrides to configure!
    //

    // Override for specific HealthKit interface enabling/disabling
    func turnOnInterface() {
        DDLogVerbose("trace")

        if self.currentUserId != nil {
            // Always start uploading HealthKitBloodGlucoseUploadReader.Mode.Current samples when interface is turned on
            HealthKitBloodGlucoseUploadManager.sharedInstance.startUploading(mode: HealthKitBloodGlucoseUploadReader.Mode.Current, currentUserId: self.currentUserId!)

            // Resume uploading other samples too, if resumable
            // TODO: uploader UI - Revisit this. Do we want even the non-current mode readers/uploads to resume automatically? Or should that be behind some explicit UI
            HealthKitBloodGlucoseUploadManager.sharedInstance.resumeUploadingIfResumable(currentUserId: self.currentUserId)
        } else {
            DDLogInfo("No logged in user, unable to start uploading")
        }
    }

    func turnOffInterface() {
        DDLogVerbose("trace")

        var mode = HealthKitBloodGlucoseUploadReader.Mode.Current
        if (HealthKitBloodGlucoseUploadManager.sharedInstance.isUploading[mode]!) {
            HealthKitBloodGlucoseUploadManager.sharedInstance.stopUploading(mode: mode, reason: HealthKitBloodGlucoseUploadReader.StoppedReason.turnOffInterface)
        }
        mode = HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks
        if (HealthKitBloodGlucoseUploadManager.sharedInstance.isUploading[mode]!) {
            HealthKitBloodGlucoseUploadManager.sharedInstance.stopUploading(mode: mode, reason: HealthKitBloodGlucoseUploadReader.StoppedReason.turnOffInterface)
        }
        mode = HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll
        if (HealthKitBloodGlucoseUploadManager.sharedInstance.isUploading[mode]!) {
            HealthKitBloodGlucoseUploadManager.sharedInstance.stopUploading(mode: mode, reason: HealthKitBloodGlucoseUploadReader.StoppedReason.turnOffInterface)            
        }
    }

    //
    // MARK: - Methods needed for config UI
    //    
    
    /// Enables HealthKit for current user
    ///
    /// Note: This sets the current tidepool user as the HealthKit user!
    func enableHealthKitInterface(_ username: String?, userid: String?, isDSAUser: Bool?, needsGlucoseReads: Bool, needsGlucoseWrites: Bool, needsWorkoutReads: Bool) {
        DDLogVerbose("trace")
 
        currentUserId = userid
        self.isDSAUser = isDSAUser

        guard let _ = currentUserId else {
            DDLogError("No logged in user at enableHealthKitInterface!")
            return
        }
        
        func configureCurrentHealthKitUser() {
            DDLogVerbose("trace")

            let defaults = UserDefaults.standard
            defaults.set(true, forKey: HealthKitSettings.InterfaceEnabledKey)
            if !self.healthKitInterfaceEnabledForCurrentUser() {
                if self.healthKitInterfaceConfiguredForOtherUser() {
                    // Switching healthkit users, reset HealthKitBloodGlucoseUploadManager
                    HealthKitBloodGlucoseUploadManager.sharedInstance.resetPersistentState()
                }
                defaults.setValue(currentUserId!, forKey: HealthKitSettings.InterfaceUserIdKey)
                // may be nil...
                defaults.setValue(username, forKey: HealthKitSettings.InterfaceUserNameKey)
            }
            UserDefaults.standard.synchronize()
        }
        
        HealthKitManager.sharedInstance.authorize(shouldAuthorizeBloodGlucoseSampleReads: needsGlucoseReads, shouldAuthorizeBloodGlucoseSampleWrites: needsGlucoseWrites, shouldAuthorizeWorkoutSamples: needsWorkoutReads) {
            success, error -> Void in
            
            DDLogVerbose("trace")
            
            DispatchQueue.main.async(execute: {
                if (error == nil) {
                    configureCurrentHealthKitUser()
                    self.configureHealthKitInterface(self.currentUserId, isDSAUser: self.isDSAUser)
                } else {
                    DDLogVerbose("Error authorizing health data \(String(describing: error)), \(error!.userInfo)")
                }
            })
        }
    }
    
    /// Disables HealthKit for current user
    ///
    /// Note: This does NOT clear the current HealthKit user!
    func disableHealthKitInterface() {
        DDLogVerbose("trace")

        UserDefaults.standard.set(false, forKey: HealthKitSettings.InterfaceEnabledKey)
        UserDefaults.standard.synchronize()
        configureHealthKitInterface(self.currentUserId, isDSAUser: self.isDSAUser)
    }
    
    /// Returns true only if the HealthKit interface is enabled and configured for the current user
    func healthKitInterfaceEnabledForCurrentUser() -> Bool {
        if healthKitInterfaceEnabled() == false {
            return false
        }
        if let curHealthKitUserId = healthKitUserTidepoolId(), let curId = currentUserId {
            if curId == curHealthKitUserId {
                return true
            }
        }
        return false
    }
    
    /// Returns true if the HealthKit interface has been configured for a tidepool id different from the current user - ignores whether the interface is currently enabled.
    func healthKitInterfaceConfiguredForOtherUser() -> Bool {
        if let curHealthKitUserId = healthKitUserTidepoolId() {
            if let curId = currentUserId {
                if curId != curHealthKitUserId {
                    return true
                }
            } else {
                DDLogError("No logged in user at healthKitInterfaceEnabledForOtherUser!")
                return true
            }
        }
        return false
    }
    
    /// Returns whether authorization for HealthKit has been requested, and the HealthKit interface is currently enabled, regardless of user it is enabled for.
    ///
    /// Note: separately, we may enable/disable the current interface to HealthKit.
    fileprivate func healthKitInterfaceEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: HealthKitSettings.InterfaceEnabledKey)
    }
    
    /// If HealthKit interface is enabled, returns associated Tidepool account id
    func healthKitUserTidepoolId() -> String? {
        let result = UserDefaults.standard.string(forKey: HealthKitSettings.InterfaceUserIdKey)
        return result
    }
    
    /// If HealthKit interface is enabled, returns associated Tidepool account id
    func healthKitUserTidepoolUsername() -> String? {
        let result = UserDefaults.standard.string(forKey: HealthKitSettings.InterfaceUserNameKey)
        return result
    }
}
