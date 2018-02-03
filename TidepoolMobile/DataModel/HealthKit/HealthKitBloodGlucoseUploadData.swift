/*
 * Copyright (c) 2017, Tidepool Project
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
import CocoaLumberjack
import CryptoSwift

class HealthKitBloodGlucoseUploadData: NSObject {
    init(newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, currentUserId: String) {
        DDLogVerbose("trace")
        
        super.init()
        
        self.currentUserId = currentUserId
        
        if let newSamples = newSamples {
            updateSamples(samples: newSamples)
            updateBatchMetadata()
            
            if newSamples.count > 0 {
                self.newOrDeletedSamplesWereDelivered = true
            }
        }
        
        if deletedSamples != nil && deletedSamples!.count > 0 {
            self.newOrDeletedSamplesWereDelivered = true
        }
    }

    fileprivate(set) var filteredSamples = [HKSample]()
    fileprivate(set) var earliestSampleTime = Date.distantFuture
    fileprivate(set) var latestSampleTime = Date.distantPast
    fileprivate(set) var batchMetadata = [String: AnyObject]()
    fileprivate(set) var newOrDeletedSamplesWereDelivered = false

    // MARK: Private
    
    fileprivate func updateSamples(samples: [HKSample]) {
        DDLogVerbose("trace")
        
        // Sort by sample date
        let sortedSamples = samples.sorted(by: {x, y in
            return x.startDate.compare(y.startDate) == .orderedAscending
        })
        
        // Filter out non-Dexcom data and compute latest sample time for batch
        var filteredSamples = [HKSample]()
        var earliestSampleTime = Date.distantFuture
        var latestSampleTime = Date.distantPast
        for sample in sortedSamples {
            let sourceRevision = sample.sourceRevision
            let source = sourceRevision.source
            let treatAllBloodGlucoseSourceTypesAsDexcom = UserDefaults.standard.bool(forKey: HealthKitSettings.TreatAllBloodGlucoseSourceTypesAsDexcomKey)
            if source.name.lowercased().range(of: "dexcom") == nil && !treatAllBloodGlucoseSourceTypesAsDexcom {
                DDLogInfo("Ignoring non-Dexcom glucose data from source: \(source.name)")
                continue
            }
            
            filteredSamples.append(sample)
            
            if sample.startDate.compare(earliestSampleTime) == .orderedAscending {
                earliestSampleTime = sample.startDate
            }
            
            if sample.startDate.compare(latestSampleTime) == .orderedDescending {
                latestSampleTime = sample.startDate
            }
        }
        
        self.filteredSamples = filteredSamples
        self.earliestSampleTime = earliestSampleTime
        self.latestSampleTime = latestSampleTime
    }
    
    fileprivate func updateBatchMetadata() {
        DDLogVerbose("trace")
        
        guard self.filteredSamples.count > 0 else {
            DDLogInfo("No samples available for batch")
            return
        }
        
        let firstSample = self.filteredSamples[0]
        let sourceRevision = firstSample.sourceRevision
        let source = sourceRevision.source
        let sourceBundleIdentifier = source.bundleIdentifier
        let deviceModel = deviceModelForSourceBundleIdentifier(sourceBundleIdentifier)
        let deviceId = "\(deviceModel)_\(UIDevice.current.identifierForVendor!.uuidString)"
        let timeZoneOffset = NSCalendar.current.timeZone.secondsFromGMT() / 60
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let appBuild = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        let appBundleIdentifier = Bundle.main.bundleIdentifier!
        let version = "\(appBundleIdentifier):\(appVersion)-\(appBuild)"
        let dateFormatter = DateFormatter()
        let now = Date()
        let time = DateFormatter().isoStringFromDate(now)
        let guid = UUID().uuidString
        let uploadIdSuffix = "\(deviceId)_\(time)_\(guid)"
        let uploadIdSuffixMd5Hash = uploadIdSuffix.md5()
        let uploadId = "upid_\(uploadIdSuffixMd5Hash)"
        
        var batchMetadata = [String: AnyObject]()
        batchMetadata["type"] = "upload" as AnyObject
        batchMetadata["uploadId"] = uploadId as AnyObject
        batchMetadata["computerTime"] = dateFormatter.isoStringFromDate(now, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateNoTimeZone) as AnyObject
        batchMetadata["time"] = time as AnyObject
        batchMetadata["timezoneOffset"] = timeZoneOffset as AnyObject
        batchMetadata["timezone"] = TimeZone.autoupdatingCurrent.identifier as AnyObject
        batchMetadata["timeProcessing"] = "none" as AnyObject
        batchMetadata["version"] = version as AnyObject
        batchMetadata["guid"] = guid as AnyObject
        batchMetadata["byUser"] = self.currentUserId as AnyObject
        batchMetadata["deviceTags"] = ["cgm"] as AnyObject
        batchMetadata["deviceManufacturers"] = ["Dexcom"] as AnyObject
        batchMetadata["deviceSerialNumber"] = "" as AnyObject
        batchMetadata["deviceModel"] = deviceModel as AnyObject
        batchMetadata["deviceId"] = deviceId as AnyObject
        
        self.batchMetadata = batchMetadata
    }
    
    fileprivate func deviceModelForSourceBundleIdentifier(_ sourceBundleIdentifier: String) -> String {
        var deviceModel = ""
        
        // TODO: uploader - what about G6? others?
        if sourceBundleIdentifier.lowercased().range(of: "com.dexcom.cgm") != nil {
            deviceModel = "DexG5"
        } else if sourceBundleIdentifier.lowercased().range(of: "com.dexcom.share2") != nil {
            deviceModel = "DexG4"
        } else {
            DDLogError("Unknown Dexcom sourceBundleIdentifier: \(sourceBundleIdentifier)")
            deviceModel = "DexUnknown: \(sourceBundleIdentifier)"
        }
        
        return "HealthKit_\(deviceModel)"
    }

    fileprivate var currentUserId = ""
}
