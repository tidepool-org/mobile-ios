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

import Foundation
import CocoaLumberjack
import HealthKit

// For parameter checking...
// Reverse domain string needs to
// (1) begin with 2 to 63 lower case letters
// (2) followed by one or more groups of:
//      period
//      0 or more lower case letters or numerals or dashes
//      1 lower case letter or number
let reverseDomainRegEx = "^[a-z]{2,63}(\\.([a-z0-9]|[a-z0-9][a-z0-9-]{0,61}[a-z0-9]))+$"

class HealthKitUploadType {
    private(set) var typeName: String
    init(_ typeName: String) {
        self.typeName = typeName
    }

    //
    //  MARK: - Public data used by HealthKitManager
    //
    
    // Note: might want to keep this data with HealthKitManager, but this does make it clear that there will only be one observation and one query per type at a time...
    var sampleObservationQuery: HKObserverQuery?
    var sampleBackgroundDeliveryEnabled = false
    var sampleQueryAnchor = Int(HKAnchoredObjectQueryNoAnchor)
    
    //
    //  MARK: - Subclass utility functions
    //
    internal let dateFormatter = DateFormatter()

    internal func addCommonFields(_ data: HealthKitUploadData, sampleToUploadDict: inout [String: AnyObject], sample: HKSample) {
        sampleToUploadDict["guid"] = sample.uuid.uuidString as AnyObject?
        sampleToUploadDict["deviceId"] = data.batchMetadata["deviceId"]
        //sampleToUploadDict["guid"] = sample.uuid.uuidString as AnyObject?
        sampleToUploadDict["time"] = dateFormatter.isoStringFromDate(sample.startDate, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime) as AnyObject?
        
        // add optional application origin
        if let origin = sampleOrigin(sample) {
            sampleToUploadDict["origin"] = origin as AnyObject
        }
    }
    
    internal func addMetadata(_ metadata: inout [String: Any], sampleToUploadDict: inout [String: AnyObject]) {
        
        if metadata.isEmpty {
            return
        }
        for (key, value) in metadata {
            // TODO: document this time format adjust!
            if let dateValue = value as? Date {
                metadata[key] = dateFormatter.isoStringFromDate(dateValue, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
            }
        }
        
        // Don't let invalid json crash the app during later serialization!
        if JSONSerialization.isValidJSONObject(metadata) {
            // Add metadata values as the payload struct
            sampleToUploadDict["payload"] = metadata as AnyObject?
        } else {
            DDLogError("Invalid metadata failed to serialize: \(String(describing:metadata)), for type: \(typeName), guid: \(sampleToUploadDict["guid"] ?? "no guid" as AnyObject)")
        }

    }
    
    internal func sampleOrigin(_ sample: HKSample) -> [String: String]? {
        let sourceBundleName = sample.sourceRevision.source.bundleIdentifier.lowercased()
        if isValidReverseDomain(sourceBundleName) {
            var origin = [
                "name": sample.sourceRevision.source.bundleIdentifier.lowercased()
            ]
            if let userEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool {
                if userEntered {
                    origin["type"] = "manual"
                }
            }
            return origin
        } else {
            DDLogInfo("Invalid reverse domain name: \(sourceBundleName)")
            return nil
        }
    }
    
    let reverseDomainTest = NSPredicate(format:"SELF MATCHES %@", reverseDomainRegEx)
    // Service requirement: Must start with 2-63 lower-case alpha characters, followed by a period, followed by lower-case alpha or 0-9 characters. E.g., failures include "com.Apple" (includes uppercase), "q5awl8wcy6.imapmyrunplus" (has numbers in the first part), etc.
    internal func isValidReverseDomain(_ testStr:String) -> Bool {
        return reverseDomainTest.evaluate(with: testStr)
    }

    //
    //  MARK: - Override these methods!
    //
  
    // override!
    internal func hkSampleType() -> HKSampleType? {
        return nil
    }
    
    // override!
    internal func filterSamples(sortedSamples: [HKSample]) -> [HKSample] {
        return sortedSamples
    }
    
    // override!
    internal func deviceModelForSourceBundleIdentifier(_ sourceBundleIdentifier: String) -> String {
        return ""
    }
    
    // override!
    internal func typeSpecificMetadata() -> [(metaKey: String, metadatum: AnyObject)] {
        return []
    }
    
    // override!
    internal func prepareDataForUpload(_ data: HealthKitUploadData) -> [[String: AnyObject]] {
        return [[String: AnyObject]]()
    }
    
}

