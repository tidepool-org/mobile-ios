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
import CocoaLumberjack
import CryptoSwift

class HealthKitUploadData: NSObject {
    var uploadType: HealthKitUploadType
    
    init(_ uploadType: HealthKitUploadType, newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, currentUserId: String) {
        DDLogVerbose("trace")
        self.uploadType = uploadType
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

    private(set) var filteredSamples = [HKSample]()
    private(set) var earliestSampleTime = Date.distantFuture
    private(set) var latestSampleTime = Date.distantPast
    private(set) var batchMetadata = [String: AnyObject]()
    private(set) var newOrDeletedSamplesWereDelivered = false
    
    func updateSamples(samples: [HKSample]) {
        DDLogVerbose("type: \(uploadType.typeName)")
        
        // Sort by sample date
        let sortedSamples = samples.sorted(by: {x, y in
            return x.startDate.compare(y.startDate) == .orderedAscending
        })
        
        self.filteredSamples = uploadType.filterSamples(sortedSamples: sortedSamples)
        
        var earliestSampleTime = Date.distantFuture
        var latestSampleTime = Date.distantPast
        for sample in self.filteredSamples {
            if sample.startDate.compare(earliestSampleTime) == .orderedAscending {
                earliestSampleTime = sample.startDate
            }
            
            if sample.startDate.compare(latestSampleTime) == .orderedDescending {
                latestSampleTime = sample.startDate
            }
        }
        
        self.earliestSampleTime = earliestSampleTime
        self.latestSampleTime = latestSampleTime
    }

    func updateBatchMetadata() {
        DDLogVerbose("type: \(uploadType.typeName)")

        guard self.filteredSamples.count > 0 else {
            DDLogInfo("No samples available for batch")
            return
        }
        
        let firstSample = self.filteredSamples[0]
        let sourceRevision = firstSample.sourceRevision
        let source = sourceRevision.source
        let sourceBundleIdentifier = source.bundleIdentifier
        let deviceModel = uploadType.deviceModelForSourceBundleIdentifier(sourceBundleIdentifier)
        let deviceId = "\(deviceModel)_\(UIDevice.current.identifierForVendor!.uuidString)"
        let timeZoneOffset = NSCalendar.current.timeZone.secondsFromGMT() / 60
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let appBuild = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        let appBundleIdentifier = Bundle.main.bundleIdentifier!
        let version = "\(appBundleIdentifier):\(appVersion)-\(appBuild)"
        let dateFormatter = DateFormatter()
        let now = Date()
        let time = DateFormatter().isoStringFromDate(now)
        //let guid = UUID().uuidString
        //let uploadIdSuffix = "\(deviceId)_\(time)_\(guid)"
        //let uploadIdSuffixMd5Hash = uploadIdSuffix.md5()
        //let uploadId = "upid_\(uploadIdSuffixMd5Hash)"
        
        var batchMetadata = [String: AnyObject]()
        batchMetadata["type"] = "upload" as AnyObject
        //batchMetadata["uploadId"] = uploadId as AnyObject
        batchMetadata["computerTime"] = dateFormatter.isoStringFromDate(now, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateNoTimeZone) as AnyObject
        batchMetadata["time"] = time as AnyObject
        batchMetadata["timezoneOffset"] = timeZoneOffset as AnyObject
        batchMetadata["timezone"] = TimeZone.autoupdatingCurrent.identifier as AnyObject
        batchMetadata["timeProcessing"] = "none" as AnyObject
        batchMetadata["version"] = version as AnyObject
        //batchMetadata["guid"] = guid as AnyObject
        batchMetadata["byUser"] = self.currentUserId as AnyObject
        batchMetadata["deviceSerialNumber"] = "" as AnyObject
        batchMetadata["deviceModel"] = deviceModel as AnyObject
        batchMetadata["deviceId"] = deviceId as AnyObject
        
        // override point! Add additional type-specific metadata, if any...
        for item in uploadType.typeSpecificMetadata() {
            batchMetadata[item.metaKey] = item.metadatum
        }
        
        self.batchMetadata = batchMetadata
    }
    
    private var currentUserId = ""
}

