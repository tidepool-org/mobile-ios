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
import HealthKit
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

        
        let isTreatingAllBloodGlucoseSourceTypesAsDexcom = UserDefaults.standard.bool(forKey: HealthKitSettings.TreatAllBloodGlucoseSourceTypesAsDexcomKey)
        if isTreatingAllBloodGlucoseSourceTypesAsDexcom {
            actionSheet.addAction(UIAlertAction(title: "Don't treat all sources as Dexcom", style: .default, handler: {
                Void in
                self.handleTreatAllBloodGlucoseSourceTypesAsDexcom(treatAllAsDexcom: false)
            }))
        } else {
            actionSheet.addAction(UIAlertAction(title: "Treat all sources as Dexcom", style: .default, handler: {
                Void in
                self.handleTreatAllBloodGlucoseSourceTypesAsDexcom(treatAllAsDexcom: true)
            }))
        }

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
        
//        actionSheet.addAction(UIAlertAction(title: "Email export of HealthKit blood glucose data", style: .default, handler: {
//            Void in
//            self.handleEmailExportOfBloodGlucoseData()
//        }))
//
//        actionSheet.addAction(UIAlertAction(title: "Count HealthKit Blood Glucose Samples", style: .default, handler: {
//            Void in
//            self.handleCountBloodGlucoseSamples()
//        }))
//        actionSheet.addAction(UIAlertAction(title: "Find date range for blood glucose samples", style: .default, handler: {
//            Void in
//            self.handleFindDateRangeBloodGlucoseSamples()
//        }))
//        actionSheet.addAction(UIAlertAction(title: "Write 60 days of non-Dexcom test CBG data to HealthKit", style: .default, handler: {
//            Void in
//            self.handleWriteLotsOfNonDexcomCBGTestDataToHealthKit()
//        }))
//        actionSheet.addAction(UIAlertAction(title: "Write one new non-Dexcom test CBG samples to HealthKit", style: .default, handler: {
//            Void in
//            self.handleWriteNonDexcomCBGTestDataToHealthKit()
//        }))

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { Void in
        }))

        self.presentingViewController?.present(actionSheet, animated: true, completion: nil)
    }
    
    fileprivate func handleEnableNotificationsForUploads(enable: Bool) {
        AppDelegate.testMode = enable
        let notifySettings = UIUserNotificationSettings(types: .alert, categories: nil)
        UIApplication.shared.registerUserNotificationSettings(notifySettings)
    }
    
    fileprivate func handleTreatAllBloodGlucoseSourceTypesAsDexcom(treatAllAsDexcom: Bool) {
        UserDefaults.standard.set(treatAllAsDexcom, forKey: HealthKitSettings.TreatAllBloodGlucoseSourceTypesAsDexcomKey);
        UserDefaults.standard.synchronize()
    }
    
    fileprivate func handleEmailExportOfBloodGlucoseData() {
        let sampleType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) {
            (query, samples, error) -> Void in
            
            if error == nil && samples != nil && samples!.count > 0 {
                // Write header row
                let rows = NSMutableString()
                rows.append("sequence,sourceBundleId,UUID,date,value,units\n")
                
                // Write rows
                let dateFormatter = DateFormatter()
                var sequence = 0
                for sample in samples! {
                    sequence += 1
                    let sourceBundleId = sample.sourceRevision.source.bundleIdentifier
                    let UUIDString = sample.uuid.uuidString
                    let date = dateFormatter.isoStringFromDate(sample.startDate, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
                    
                    if let quantitySample = sample as? HKQuantitySample {
                        let units = "mg/dL"
                        let unit = HKUnit(from: units)
                        let value = quantitySample.quantity.doubleValue(for: unit)
                        rows.append("\(sequence),\(sourceBundleId),\(UUIDString),\(date),\(value),\(units)\n")
                    } else {
                        rows.append("\(sequence),\(sourceBundleId),\(UUIDString)\n")
                    }
                }
                
                // Send mail
                if MFMailComposeViewController.canSendMail() {
                    let composeVC = MFMailComposeViewController()
                    composeVC.mailComposeDelegate = self
                    composeVC.setSubject("HealthKit blood glucose samples")
                    composeVC.setMessageBody("", isHTML: false)
                    
                    if let attachmentData = rows.data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false) {
                        composeVC.addAttachmentData(attachmentData, mimeType: "text/csv", fileName: "HealthKit Samples.csv")
                    }
                    self.presentingViewController?.present(composeVC, animated: true, completion: nil)
                }
                
            } else {
                var alert: UIAlertController?
                let title = "Error"
                let message = "Unable to export HealthKit blood glucose data. Maybe you haven't connected to Health yet. Please login and connect to Health and try again. Or maybe there is no blood glucose data in Health."
                DDLogInfo(message)
                alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert!.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                DispatchQueue.main.async(execute: {
                    self.presentingViewController?.present(alert!, animated: true, completion: nil)
                })
            }
        }
        
        HKHealthStore().execute(sampleQuery)
    }

    fileprivate func handleCountBloodGlucoseSamples() {
        HealthKitManager.sharedInstance.countBloodGlucoseSamples {
            (error: Error?, totalSamplesCount: Int, totalDexcomSamplesCount: Int) in
            
            var alert: UIAlertController?
            let title = "HealthKit Blood Glucose Sample Count"
            var message = ""
            if error == nil {
                message = "There are \(totalSamplesCount) blood glucose samples and \(totalDexcomSamplesCount) Dexcom samples in HealthKit"
            } else if HealthKitManager.sharedInstance.authorizationRequestedForBloodGlucoseSamples() {
                message = "Error counting samples: \(String(describing: error))"
            } else {
                message = "Unable to count sample. Maybe you haven't connected to Health yet. Please login and connect to Health and try again."
            }
            DDLogInfo(message)
            alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert!.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            DispatchQueue.main.async(execute: {
                self.presentingViewController?.present(alert!, animated: true, completion: nil)
            })
        }
    }
    
    fileprivate func handleFindDateRangeBloodGlucoseSamples() {
        let sampleType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!
        HealthKitManager.sharedInstance.findSampleDateRange(sampleType: sampleType) {
            (error: Error?, startDate: Date?, endDate: Date?) in
            
            var alert: UIAlertController?
            let title = "Date range for blood glucose samples"
            var message = ""
            if error == nil && startDate != nil && endDate != nil {
                let days = startDate!.differenceInDays(endDate!) + 1
                message = "Start date: \(startDate!), end date: \(endDate!). Total days: \(days)"
            } else {
                message = "Unable to find date range for blood glucose samples, maybe you haven't connected to Health yet, please login and connect to Health and try again. Or maybe there are no samples in HealthKit."
            }
            DDLogInfo(message)
            alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert!.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            DispatchQueue.main.async(execute: {
                self.presentingViewController?.present(alert!, animated: true, completion: nil)
            })
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
    
    fileprivate func handleWriteLotsOfNonDexcomCBGTestDataToHealthKit() {
        var itemsToPush = [HKQuantitySample]()
        let calendar = Calendar.current
        var sampleTime = calendar.date(byAdding: .day, value: -60, to: Date())
        var bgValue = 50
        for _ in 1...60 {
            for j in 1...2 {
                for _ in 1...144 {
                    let bgType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
                    let bgQuantity = HKQuantity(unit: HKUnit(from: "mg/dL"), doubleValue: Double(bgValue))
                    let bgSample = HKQuantitySample(type: bgType!, quantity: bgQuantity, start: sampleTime!, end: sampleTime!, metadata: nil)
                    itemsToPush.append(bgSample)
                    sampleTime = sampleTime?.addingTimeInterval(60 * 5) // 5 minutes
                    if j == 1 {
                        bgValue += 1
                    } else {
                        bgValue -= 1
                    }
                }
            }
        }
        HealthKitManager.sharedInstance.healthStore!.save(itemsToPush, withCompletion: { (success, error) -> Void in
            if( error != nil ) {
                DDLogError("Error pushing \(itemsToPush.count) glucose samples to HealthKit: \(error!.localizedDescription)")
            } else {
                DDLogVerbose("\(itemsToPush.count) Blood glucose samples pushed to HealthKit successfully!")
            }
        })
    }
    
    fileprivate func handleWriteNonDexcomCBGTestDataToHealthKit() {
        var itemsToPush = [HKQuantitySample]()
        let sampleTime = Date()
        let bgValue = 125
        let bgType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
        let bgQuantity = HKQuantity(unit: HKUnit(from: "mg/dL"), doubleValue: Double(bgValue))
        let bgSample = HKQuantitySample(type: bgType!, quantity: bgQuantity, start: sampleTime, end: sampleTime, metadata: nil)
        itemsToPush.append(bgSample)
        HealthKitManager.sharedInstance.healthStore!.save(itemsToPush, withCompletion: { (success, error) -> Void in
            if( error != nil ) {
                DDLogError("Error pushing \(itemsToPush.count) glucose samples to HealthKit: \(error!.localizedDescription)")
            } else {
                DDLogVerbose("\(itemsToPush.count) Blood glucose samples pushed to HealthKit successfully!")
            }
        })

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


