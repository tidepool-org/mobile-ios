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
import MessageUI
import CocoaLumberjack

class DebugSettings : NSObject, MFMailComposeViewControllerDelegate {
    init(presentingViewController: UIViewController?) {
        self.presentingViewController = presentingViewController
    }
        
    func showDebugMenuActionSheet() {
        let api = APIConnector.connector()
        let actionSheet = UIAlertController(title: "Settings" + " (" + api.currentService! + ")", message: "", preferredStyle: .actionSheet)
        for serverName in api.kSortedServerNames {
            actionSheet.addAction(UIAlertAction(title: serverName, style: .default, handler: { Void in
                api.switchToServer(serverName)
            }))
        }
        
        if defaultDebugLevel == DDLogLevel.off {
            actionSheet.addAction(UIAlertAction(title: "Enable logging", style: .default, handler: { Void in
                defaultDebugLevel = DDLogLevel.verbose
                UserDefaults.standard.set(true, forKey: "LoggingEnabled");
                UserDefaults.standard.synchronize()
                
            }))
        } else {
            actionSheet.addAction(UIAlertAction(title: "Disable logging", style: .default, handler: { Void in
                defaultDebugLevel = DDLogLevel.off
                UserDefaults.standard.set(false, forKey: "LoggingEnabled");
                UserDefaults.standard.synchronize()
                self.clearLogFiles()
            }))
        }
        
        actionSheet.addAction(UIAlertAction(title: "Email logs", style: .default, handler: { Void in
            self.handleEmailLogs()
        }))

        let isBackgroundUploadNotificationEnabled = AppDelegate.testMode
        if isBackgroundUploadNotificationEnabled {
            actionSheet.addAction(UIAlertAction(title: "Disable background upload notification", style: .default, handler: {
                Void in
                self.handleEnableNotificationsForUploads(enable: false)
            }))
        } else {
            actionSheet.addAction(UIAlertAction(title: "Enable background upload notification", style: .default, handler: {
                Void in
                self.handleEnableNotificationsForUploads(enable: true)
            }))
        }
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { Void in
        }))

        self.presentingViewController?.present(actionSheet, animated: true, completion: nil)
    }
    
    fileprivate func handleEnableNotificationsForUploads(enable: Bool) {
        AppDelegate.testMode = enable
        if enable {
            UIApplication.enableLocalNotifyMessages()
        }
    }
    
    fileprivate func handleEmailLogs() {
        DDLog.flushLog()
        
        let logFilePaths = fileLogger.logFileManager.sortedLogFilePaths as [String]
        var logFileDataArray = [Data]()
        for logFilePath in logFilePaths {
            let fileURL = NSURL(fileURLWithPath: logFilePath)
            if let logFileData = try? NSData(contentsOf: fileURL as URL, options: NSData.ReadingOptions.mappedIfSafe) {
                // Insert at front to reverse the order, so that oldest logs appear first.
                logFileDataArray.insert(logFileData as Data, at: 0)
            }
        }
        
        if MFMailComposeViewController.canSendMail() {
            let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
            let composeVC = MFMailComposeViewController()
            composeVC.mailComposeDelegate = self
            composeVC.setSubject("Logs for \(appName)")
            composeVC.setMessageBody("", isHTML: false)
            
            let attachmentData = NSMutableData()
            for logFileData in logFileDataArray {
                attachmentData.append(logFileData)
            }
            composeVC.addAttachmentData(attachmentData as Data, mimeType: "text/plain", fileName: "\(appName).txt")
            self.presentingViewController?.present(composeVC, animated: true, completion: nil)
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    

    fileprivate func clearLogFiles() {
        // Clear log files
        let logFileInfos = fileLogger.logFileManager.unsortedLogFileInfos
        for logFileInfo in logFileInfos! {
            if let logFilePath = logFileInfo.filePath {
                do {
                    try FileManager.default.removeItem(atPath: logFilePath)
                    logFileInfo.reset()
                    DDLogInfo("Removed log file: \(logFilePath)")
                } catch let error as NSError {
                    DDLogError("Failed to remove log file at path: \(logFilePath) error: \(error), \(error.userInfo)")
                }
            }
        }
    }
    
    fileprivate var presentingViewController: UIViewController?;
}


