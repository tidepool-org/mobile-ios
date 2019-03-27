/*
 * Copyright (c) 2018, Tidepool Project
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

import HealthKit

class HealthKitConfiguration
{
    static var sharedInstance: HealthKitConfiguration!
    init(_ config: TPUploaderConfigInfo, healthKitUploadTypes: [HealthKitUploadType]) {
        self.healthKitUploadTypes = healthKitUploadTypes
        self.config = config
        HealthKitConfiguration.sharedInstance = self
    }

    let settings = GlobalSettings.sharedInstance
    
    // MARK: Access, availability, authorization

    private(set) var config: TPUploaderConfigInfo
    private(set) var healthKitUploadTypes: [HealthKitUploadType]
    
    /// Call this whenever the current user changes, at login/logout, token refresh(?), and upon enabling or disabling the HealthKit interface.
    func configureHealthKitInterface() {
        DDLogVerbose("\(#function)")
        
        if !HealthKitManager.sharedInstance.isHealthDataAvailable {
            DDLogInfo("HKHealthStore data is not available")
            return
        }
        
        var interfaceEnabled = true
        if config.currentUserId() != nil  {
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
            if turningOnHKInterface {
                DDLogError("Ignoring turn on HK interface, already in progress!")
                return
            }
            // set flag to prevent reentrancy!
            turningOnHKInterface = true
            TPUploaderServiceAPI.connector?.configureUploadId() {
                // if we are still turning on the HK interface after fetch of upload id, continue!
                if self.turningOnHKInterface {
                    if TPUploaderServiceAPI.connector?.currentUploadId != nil {
                        self.turnOnInterface()
                    }
                    self.turningOnHKInterface = false
                }
            }
        } else {
            DDLogInfo("disable!")
            turningOnHKInterface = false
            self.turnOffInterface()
        }
    }
    // flag to prevent reentry as part of this method may finish asynchronously...
    private var turningOnHKInterface = false

    /// Turn on HK interface: start/resume uploading if possible...
    private func turnOnInterface() {
        DDLogVerbose("\(#function)")

        if let currentUserId = config.currentUserId() {
            // Always start uploading TPUploader.Mode.Current samples when interface is turned on
            HealthKitUploadManager.sharedInstance.startUploading(mode: TPUploader.Mode.Current, currentUserId: currentUserId)

            // Resume uploading other samples too, if resumable
            // TODO: uploader UI - Revisit this. Do we want even the non-current mode readers/uploads to resume automatically? Or should that be behind some explicit UI
            HealthKitUploadManager.sharedInstance.resumeUploadingIfResumable(currentUserId: currentUserId)
            
            // Really just a one-time check to upload biological sex if Tidepool does not have it, but we can get it from HealthKit.
            TPUploaderServiceAPI.connector?.updateProfileBioSexCheck()
        } else {
            DDLogInfo("No logged in user, unable to start uploading")
        }
    }

    private func turnOffInterface() {
        DDLogVerbose("\(#function)")

        HealthKitUploadManager.sharedInstance.stopUploading(reason: TPUploader.StoppedReason.turnOffInterface)
    }

    //
    // MARK: - Methods needed for config UI
    //    
    
    /// Enables HealthKit for current user
    ///
    /// Note: This sets the current tidepool user as the HealthKit user!
    func enableHealthKitInterface() {
        
        DDLogVerbose("\(#function)")
        
        let needsUploaderReads = true
        let username = self.config.currentUserName
        
        guard self.config.currentUserId() != nil else {
            DDLogError("No logged in user at enableHealthKitInterface!")
            return
        }
        
        func configureCurrentHealthKitUser() {
            DDLogVerbose("\(#function)")
            
            settings.updateBoolForKey(.interfaceEnabledKey, value: true)
            if !self.healthKitInterfaceEnabledForCurrentUser() {
                if self.healthKitInterfaceConfiguredForOtherUser() {
                    // Switching healthkit users, reset HealthKitUploadManager
                    HealthKitUploadManager.sharedInstance.resetPersistentState(switchingHealthKitUsers: true)
                    // Also clear any persisted timezone data so an initial tz reading will be sent for this new user
                    TPTimeZoneTracker.tracker?.clearTzCache()
                }
                // force refetch of upload id because it may have changed for the new user...
                TPUploaderServiceAPI.connector?.currentUploadId = nil
                settings.updateStringForKey(.interfaceUserIdKey, value: config.currentUserId()!)
                settings.updateStringForKey(.interfaceUserNameKey, value: username)
            }
        }
        
        HealthKitManager.sharedInstance.authorize() {
            success, error -> Void in
            
            DDLogVerbose("\(#function)")
            
            DispatchQueue.main.async(execute: {
                if (error == nil) {
                    configureCurrentHealthKitUser()
                    self.configureHealthKitInterface()
                } else {
                    DDLogError("Error authorizing health data \(String(describing: error)), \(error!.userInfo)")
                }
            })
        }
    }
    
    /// Disables HealthKit for current user
    ///
    /// Note: This does NOT clear the current HealthKit user!
    func disableHealthKitInterface() {
        DDLogVerbose("\(#function)")
        settings.updateBoolForKey(.interfaceEnabledKey, value: false)
        configureHealthKitInterface()
    }
    
    /// Returns true only if the HealthKit interface is enabled and configured for the current user
    func healthKitInterfaceEnabledForCurrentUser() -> Bool {
        if healthKitInterfaceEnabled() == false {
            return false
        }
        if let curHealthKitUserId = healthKitUserTidepoolId(), let curId = config.currentUserId() {
            if curId == curHealthKitUserId {
                return true
            }
        }
        return false
    }
    
    /// Returns true if the HealthKit interface has been configured for a tidepool id different from the current user - ignores whether the interface is currently enabled.
    func healthKitInterfaceConfiguredForOtherUser() -> Bool {
        if let curHealthKitUserId = healthKitUserTidepoolId() {
            if let curId = config.currentUserId() {
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
        return settings.boolForKey(.interfaceEnabledKey)
    }
    
    /// If HealthKit interface is enabled, returns associated Tidepool account id
    func healthKitUserTidepoolId() -> String? {
        return settings.stringForKey(.interfaceUserIdKey)

    }

    /// If HealthKit interface is enabled, returns associated Tidepool account id
    func healthKitUserTidepoolUsername() -> String? {
        return settings.stringForKey(.interfaceUserNameKey)
    }
}
