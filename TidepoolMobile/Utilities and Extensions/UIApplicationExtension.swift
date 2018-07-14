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

extension UIApplication {
    
    class func appVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
    
    class func appBuild() -> String {
        return Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
    }
    
    class func localNotifyMessage(_ msg: String) {
        if !AppDelegate.testMode {
            return
        }
        DDLogInfo("localNotifyMessage: \(msg)")
        let localNotificationMessage = UILocalNotification()
        localNotificationMessage.alertBody = msg
        DispatchQueue.main.async {
            UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
        }
    }
    
    class func enableLocalNotifyMessages() {
        let notifySettings = UIUserNotificationSettings(types: .alert, categories: nil)
        UIApplication.shared.registerUserNotificationSettings(notifySettings)
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
