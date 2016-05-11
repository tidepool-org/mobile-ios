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
    
//    static let sharedInstance = HealthKitConfiguration()
//    private init() {
//        DDLogVerbose("trace")
//    }

    private var currentUserId: String?
    private var isDSAUser: Bool?
    
    func shouldShowHealthKitUI() -> Bool {
        if let isDSAUser = isDSAUser {
            return HealthKitManager.sharedInstance.isHealthDataAvailable && isDSAUser
        }
        return false
    }
    
    /// Call this whenever the current user changes, at login/logout, token refresh(?), and upon enabling or disabling the HealthKit interface.
    func configureHealthKitInterface(userid: String?, isDSAUser: Bool?) {
        DDLogVerbose("trace")
        
        if !HealthKitManager.sharedInstance.isHealthDataAvailable {
            return
        }

        currentUserId = userid
        self.isDSAUser = isDSAUser
        
        var interfaceEnabled = true
        if currentUserId != nil  {
            interfaceEnabled = healthKitInterfaceEnabledForCurrentUser()
            if !interfaceEnabled {
                DDLogVerbose("disable because not enabled for current user!")
            }
        } else {
            interfaceEnabled = false
            DDLogVerbose("disable because no current user!")
        }
        
        if interfaceEnabled {
            DDLogVerbose("enable!")
            self.turnOnInterface()
        } else {
            DDLogVerbose("disable!")
            self.turnOffInterface()
        }
    }

    //
    // MARK: - Overrides to configure!
    //

    // Override for specific HealthKit interface enabling/disabling
    func turnOnInterface() {
        DDLogVerbose("trace")

        HealthKitDataUploader.sharedInstance.startUploading(currentUserId: currentUserId)
    }

    func turnOffInterface() {
        DDLogVerbose("trace")

        HealthKitDataUploader.sharedInstance.stopUploading()
    }

    //
    // MARK: - Methods needed for config UI
    //
    
    private let kHealthKitInterfaceEnabledKey = "kHealthKitInterfaceEnabledKey"
    private let kHealthKitInterfaceUserIdKey = "kUserIdForHealthKitInterfaceKey"
    private let kHealthKitInterfaceUserNameKey = "kUserNameForHealthKitInterfaceKey"
    
    
    /// Enables HealthKit for current user
    ///
    /// Note: This sets the current tidepool user as the HealthKit user!
    func enableHealthKitInterface(username: String?, userid: String?, isDSAUser: Bool?, needsGlucoseReads: Bool, needsGlucoseWrites: Bool, needsWorkoutReads: Bool) {
        DDLogVerbose("trace")
 
        currentUserId = userid
        self.isDSAUser = isDSAUser

        guard let _ = currentUserId else {
            DDLogError("No logged in user at enableHealthKitInterface!")
            return
        }
        
        func configureCurrentHealthKitUser() {
            DDLogVerbose("trace")

            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setBool(true, forKey:self.kHealthKitInterfaceEnabledKey)
            if !self.healthKitInterfaceEnabledForCurrentUser() {
                if self.healthKitInterfaceConfiguredForOtherUser() {
                    // switching healthkit users! reset anchors!
                    HealthKitDataUploader.sharedInstance.resetHealthKitUploaderForNewUser()
                }
                defaults.setValue(currentUserId!, forKey: kHealthKitInterfaceUserIdKey)
                // may be nil...
                defaults.setValue(username, forKey: kHealthKitInterfaceUserNameKey)
            }
            NSUserDefaults.standardUserDefaults().synchronize()
        }
        
        HealthKitManager.sharedInstance.authorize(shouldAuthorizeBloodGlucoseSampleReads: needsGlucoseReads, shouldAuthorizeBloodGlucoseSampleWrites: needsGlucoseWrites, shouldAuthorizeWorkoutSamples: needsWorkoutReads) {
            success, error -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                if (error == nil) {
                    configureCurrentHealthKitUser()
                    self.configureHealthKitInterface(self.currentUserId, isDSAUser: self.isDSAUser)
                } else {
                    DDLogVerbose("Error authorizing health data \(error), \(error!.userInfo)")
                }
            })
        }
    }
    
    /// Disables HealthKit for current user
    ///
    /// Note: This does NOT clear the current HealthKit user!
    func disableHealthKitInterface() {
        DDLogVerbose("trace")

        NSUserDefaults.standardUserDefaults().setBool(false, forKey:kHealthKitInterfaceEnabledKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        configureHealthKitInterface(self.currentUserId, isDSAUser: self.isDSAUser)
    }
    
    /// Returns true only if the HealthKit interface is enabled and configured for the current user
    func healthKitInterfaceEnabledForCurrentUser() -> Bool {
        if healthKitInterfaceEnabled() == false {
            return false
        }
        if let curHealthKitUserId = healthKitUserTidepoolId(), curId = currentUserId {
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
    private func healthKitInterfaceEnabled() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey(kHealthKitInterfaceEnabledKey)
    }
    
    /// If HealthKit interface is enabled, returns associated Tidepool account id
    func healthKitUserTidepoolId() -> String? {
        let result = NSUserDefaults.standardUserDefaults().stringForKey(kHealthKitInterfaceUserIdKey)
        return result
    }
    
    /// If HealthKit interface is enabled, returns associated Tidepool account id
    func healthKitUserTidepoolUsername() -> String? {
        let result = NSUserDefaults.standardUserDefaults().stringForKey(kHealthKitInterfaceUserNameKey)
        return result
    }
}