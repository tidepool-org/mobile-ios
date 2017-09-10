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
    init(samples: [HKSample], currentUserId: String) {
        DDLogVerbose("trace")
        
        super.init()
        
        self.currentUserId = currentUserId
        updateSamples(samples: samples)
        updateBatchMetadata()
    }

    fileprivate(set) var samples = [HKSample]()
    fileprivate(set) var latestSampleTime = Date.distantPast
    fileprivate(set) var batchMetadata = [String: AnyObject]()
    
    // MARK: Private
    
    fileprivate func updateSamples(samples: [HKSample]) {
        DDLogVerbose("trace")
        
        // Sort by sample date
        let sortedSamples = samples.sorted(by: {x, y in
            return x.startDate.compare(y.startDate) == .orderedAscending
        })
        
        // Filter out non-Dexcom data and compute latest sample time for batch
        var filteredSamples = [HKSample]()
        var latestSampleTime = Date.distantPast
        for sample in sortedSamples {
            let sourceRevision = sample.sourceRevision
            let source = sourceRevision.source
            if source.name.lowercased().range(of: "dexcom") == nil {
                DDLogInfo("Ignoring non-Dexcom glucose data")
                continue
            }
            
            filteredSamples.append(sample)
            if sample.startDate.compare(latestSampleTime) == .orderedDescending {
                latestSampleTime = sample.startDate
            }
        }
        
        self.samples = filteredSamples
        self.latestSampleTime = latestSampleTime
    }
    
    fileprivate func updateBatchMetadata() {
        DDLogVerbose("trace")
        
        guard self.samples.count > 0 else {
            DDLogInfo("No samples available for batch")
            return
        }
        
        let firstSample = self.samples[0]
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
        
        if sourceBundleIdentifier.lowercased().range(of: "com.dexcom.cgm") != nil {
            deviceModel = "DexG5"
        } else if sourceBundleIdentifier.lowercased().range(of: "com.dexcom.share2") != nil {
            deviceModel = "DexG4"
        } else {
            DDLogError("Unknown Dexcom sourceBundleIdentifier: \(sourceBundleIdentifier)")
            deviceModel = "DexUnknown"
        }
        
        return "HealthKit_\(deviceModel)"
    }

    fileprivate var currentUserId = ""
}
