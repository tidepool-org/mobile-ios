/*
* Copyright (c) 2015, Tidepool Project
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

import UIKit
import CoreData
import CocoaLumberjack
import HealthKit
import Bugsee

var fileLogger: DDFileLogger!

/// Set up health kit configuration singleton, specialized version of HealthKitConfiguration
let appHealthKitConfiguration = TidepoolMobileHealthKitConfiguration(healthKitUploadTypes: [
    HealthKitUploadTypeBloodGlucose(),
    HealthKitUploadTypeCarb(),
    HealthKitUploadTypeInsulin(),
    ])

/// AppDelegate deals with app startup, restart, termination:
/// - Switches UI between login and event controllers.
/// - Initializes the UI appearance defaults.
/// - Initializes data model and api connector.

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    fileprivate var didBecomeActiveAtLeastOnce = false
    fileprivate var needSetUpForLogin = false
    fileprivate var needSetUpForLoginSuccess = false
    fileprivate var needRefreshTokenOnDidBecomeActive = false
    // one shot, UI should put up dialog letting user know we are in test mode!
    static var testModeNotification = false
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
    {
        if let logger = BugseeLogger.sharedInstance() as? DDLogger {
            DDLog.add(logger)
        } else {
            DDLogError("Bugsee Logger NOT ADDED!")
        }

        // Only enable Bugsee for TestFlight betas and debug builds, not for iTunes App Store releases (at least for now)
        let isRunningTestFlightBeta = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        if isRunningTestFlightBeta {
            Bugsee.launch(token:"d3170420-a6f0-4db3-970c-c4c571e5d31a")
        }
        DDLogVerbose("trace")

        let applicationState = UIApplication.shared.applicationState
        let message = "didFinishLaunchingWithOptions, state: \(String(describing: applicationState.rawValue))"
        DDLogInfo(message)
        UIApplication.localNotifyMessage(message)

        // Override point for customization after application launch.
        Styles.configureTidepoolBarColoring(on: true)
        
        // Initialize database by referencing username. This must be done before using the APIConnector!
        let name = TidepoolMobileDataController.sharedInstance.currentUserName
        if !name.isEmpty {
            DDLogInfo("Initializing TidepoolMobileDataController, found and set user \(name)")
        }

        // Set up the API connection
        let api = APIConnector.connector().configure()
        if api.sessionToken == nil {
            DDLogInfo("No token available, clear any data in case user did not log out normally")
            api.logout() {
                if self.didBecomeActiveAtLeastOnce {
                    self.setupUIForLogin()
                } else {
                    self.needSetUpForLogin = true
                }
            }
        } else {
            if api.isConnectedToNetwork() {
                var message = "AppDelegate attempting to refresh token"
                DDLogInfo(message)
                UIApplication.localNotifyMessage(message)
                
                api.refreshToken() { (succeeded, responseStatusCode) in
                    if succeeded {
                        message = "Refresh token succeeded, statusCode: \(responseStatusCode)"
                        DDLogInfo(message)
                        if AppDelegate.testMode  {
                            UIApplication.localNotifyMessage(message)
                        }
                        
                        let dataController = TidepoolMobileDataController.sharedInstance
                        dataController.checkRestoreCurrentViewedUser {
                            dataController.configureHealthKitInterface()
                            if self.didBecomeActiveAtLeastOnce {
                                self.setupUIForLoginSuccess()
                            } else {
                                self.needSetUpForLoginSuccess = true
                            }
                        }
                    } else {
                        let shouldLogout = responseStatusCode > 0 // Only logout if error is from server, not client side
                        if shouldLogout {
                            message = "Refresh token failed, need to log in normally, statusCode: \(responseStatusCode)"
                            DDLogInfo(message)
                            UIApplication.localNotifyMessage(message)
                            api.logout() {
                                if self.didBecomeActiveAtLeastOnce {
                                    self.setupUIForLogin()
                                } else {
                                    self.needSetUpForLogin = true
                                }
                            }
                        } else {
                            message = "Refresh token failed, no status code"
                            DDLogError(message)
                            UIApplication.localNotifyMessage(message)

                            if self.didBecomeActiveAtLeastOnce {
                                api.logout() {
                                    self.setupUIForLogin()
                                }
                            } else {
                                message = "Try to use current user and token if refresh token failed in background due to client side error"
                                DDLogError(message)
                                UIApplication.localNotifyMessage(message)
                                
                                let dataController = TidepoolMobileDataController.sharedInstance
                                dataController.checkRestoreCurrentViewedUser {
                                    dataController.configureHealthKitInterface()
                                }

                                self.needRefreshTokenOnDidBecomeActive = true
                            }
                        }
                    }
                }
            } else {
                self.needRefreshTokenOnDidBecomeActive = true
            }
        }
        
        DDLogInfo("did finish launching")
        return true
        
        // Note: for non-background launches, this will continue in applicationDidBecomeActive...
    }
    
    static var testMode: Bool {
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: kTestModeSettingKey)
            UserDefaults.standard.synchronize()
            _testMode = nil
        }
        get {
            if _testMode == nil {
                _testMode = UserDefaults.standard.bool(forKey: kTestModeSettingKey)
            }
            return _testMode!
        }
    }
    static let kTestModeSettingKey = "kTestModeSettingKey"
    static var _testMode: Bool?

    func setupUIForLogin() {
        let sb = UIStoryboard(name: "Login", bundle: nil)
        if let vc = sb.instantiateInitialViewController() {
            self.window?.rootViewController = vc
        }
    }
    
    func logout() {
        APIConnector.connector().logout() {
            self.setupUIForLogin()
        }
    }
    
    func setupUIForLoginSuccess() {
        // Upon login success, switch over to the EventView storyboard flow. This starts with a nav controller, and all other controllers are pushed/popped from that.
        let sb = UIStoryboard(name: "EventView", bundle: nil)
        if let vc = sb.instantiateInitialViewController() {
            self.window?.rootViewController = vc
        }
    }
    
    fileprivate var deviceIsLocked = false
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        DDLogInfo("Device unlocked!")
        deviceIsLocked = false
    }
    
    func applicationProtectedDataWillBecomeUnavailable(_ application: UIApplication) {
        DDLogInfo("Device locked!")
        deviceIsLocked = true
    }
    
    // Support for background fetch
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        DDLogVerbose("trace")
        
        if HealthKitBloodGlucosePusher.sharedInstance.enabled {
            // if device is locked, bail now because we can't read HealthKit data
            if deviceIsLocked {
                UIApplication.localNotifyMessage("TidepoolMobile skipping background fetch: device is locked!")
                completionHandler(.failed)
                return
            }
            
            // next make sure we are logged in and have connectivity
            let api = APIConnector.connector()
            if api.sessionToken == nil {
                DDLogInfo("No token available, user will need to log in!")
                // Use local notifications to test background activity...
                UIApplication.localNotifyMessage("TidepoolMobile was unable to download items from Tidepool: log in required!")
                completionHandler(.failed)
                return
            }
            
            if !api.isConnectedToNetwork() {
                DDLogInfo("No network available!")
                // Use local notifications to test background activity...
                UIApplication.localNotifyMessage("TidepoolMobile was unable to download items from Tidepool: no network available!")
                
                completionHandler(.failed)
                return
            }
            
            DispatchQueue.main.async {
                // make sure HK interface is configured...
                // Note: this can kick off a lot of activity!
                // Note: configureHealthKitInterface is somewhat background-aware...
                TidepoolMobileDataController.sharedInstance.configureHealthKitInterface()
                // then call it...
                HealthKitBloodGlucosePusher.sharedInstance.backgroundFetch { (fetchResult) -> Void in
                    completionHandler(fetchResult)
                }
            }
        } else {
            completionHandler(.noData)
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        DDLogVerbose("trace")
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        DDLogVerbose("trace")
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

        // Only the HealthKitUploadReader.Mode.Current uploads should continue in background
        HealthKitUploadManager.sharedInstance.stopUploading(reason: HealthKitUploadReader.StoppedReason.background)
        HealthKitUploadManager.sharedInstance.resumeUploadingIfResumable(mode: HealthKitUploadReader.Mode.Current, currentUserId: appHealthKitConfiguration.currentUserId)

        // Re-enable idle timer (screen locking) when the app enters background. (May have been disabled during sync/upload.)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        DDLogInfo("applicationWillEnterForeground")
        
        if !self.needSetUpForLogin && !self.needSetUpForLoginSuccess {
            checkConnection()
        }
    }
    
    func checkConnection() {
        DDLogVerbose("trace")
        
        let api = APIConnector.connector()
        var doCheck = refreshTokenNextActive
        if let lastError = api.lastNetworkError {
            if lastError == 401 || lastError == 403 {
                DDLogError("AppDelegate: last network error is \(lastError)")
                doCheck = true
            }
        }
        if doCheck {
             if api.isConnectedToNetwork() {
                refreshTokenNextActive = false
                api.lastNetworkError = nil
                DDLogInfo("AppDelegate: attempting to refresh token in checkConnection")
                api.refreshToken() { (succeeded, responseStatusCode) in
                    if !succeeded {
                        DDLogInfo("Refresh token failed, need to log in normally, statusCode: \(responseStatusCode)")
                        api.logout() {
                            self.setupUIForLogin()
                        }
                    }
                }
            }
        }
    }
    fileprivate var refreshTokenNextActive: Bool = false
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        DDLogVerbose("trace")
        
        self.didBecomeActiveAtLeastOnce = true
        
        if self.needSetUpForLoginSuccess {
            self.needSetUpForLoginSuccess = false
            self.setupUIForLoginSuccess()
        } else if self.needSetUpForLogin {
            self.needSetUpForLogin = false
            self.setupUIForLogin()
        } else if self.needRefreshTokenOnDidBecomeActive  {
            self.needRefreshTokenOnDidBecomeActive = false

            let api = APIConnector.connector()
            if api.isConnectedToNetwork() {
                var message = "AppDelegate attempting to refresh token"
                DDLogInfo(message)
                
                api.refreshToken() { (succeeded, responseStatusCode) in
                    if succeeded {
                        message = "Refresh token succeeded, statusCode: \(responseStatusCode)"
                        DDLogInfo(message)
                        
                        let dataController = TidepoolMobileDataController.sharedInstance
                        dataController.checkRestoreCurrentViewedUser {
                            dataController.configureHealthKitInterface()
                            self.setupUIForLoginSuccess()
                        }
                    } else {
                        message = "Refresh token failed, need to log in normally, statusCode: \(responseStatusCode)"
                        DDLogInfo(message)
                        api.logout() {
                            self.setupUIForLogin()
                        }
                    }
                }
            }
        }
        
        // TODO: uploader UI - Revisit this. Do we want even the non-current mode readers/uploaders to resume automatically? Or should that be behind some explicit UI
        HealthKitUploadManager.sharedInstance.resumeUploadingIfResumable(currentUserId: appHealthKitConfiguration.currentUserId)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        DDLogVerbose("trace")

        UIApplication.localNotifyMessage("applicationWillTerminate")
        
        TidepoolMobileDataController.sharedInstance.appWillTerminate()
    }
}
