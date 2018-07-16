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

import Foundation
import UIKit
import CocoaLumberjack
import UserNotifications

extension UIApplication {
    
    class func appVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
    
    class func appBuild() -> String {
        return Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
    }
    
    /// Use local notifications for debugging background operations. Call this to register a message to be notified to user immediately. Ignored if app is in the foreground, or if testMode is not set.
    static var localNotifyCount: Int = 0
    class func localNotifyMessage(_ msg: String) {
        if !AppDelegate.testMode {
            return
        }
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .active {
                DDLogInfo("localNotifyMessage with app in foreground: \(msg)")
                return
            }
            UIApplication.localNotifyCount += 1
            let content = UNMutableNotificationContent()
            content.body = msg
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
            let identifier = String("Tidepool \(UIApplication.localNotifyCount)")
            let request = UNNotificationRequest(identifier: identifier,
                                                content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error) in
                if let error = error {
                    DDLogInfo("failed: \(error.localizedDescription)")
                } else {
                    DDLogInfo("sent: \(msg)")
                }
            })
        }
    }
    
    class func enableLocalNotifyMessages() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) {
            (granted, error) in
            print("Permission granted: \(granted)")
        }
    }

//    class func versionBuildServer() -> String {
//        let version = appVersion(), build = appBuild()
//        
//        var serverName: String = ""
//        for server in servers {
//            if (server.1 == baseURL) {
//                serverName = server.0
//                break
//            }
//        }
//    
//        return serverName.isEmpty ? "v.\(version) (\(build))" : "v.\(version) (\(build)) on \(serverName)"
//    }
}
