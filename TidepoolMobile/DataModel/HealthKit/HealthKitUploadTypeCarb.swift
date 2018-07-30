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

class HealthKitUploadTypeCarb: HealthKitUploadType {
    init() {
        super.init("Carb")
    }

    internal override func hkQuantityTypeIdentifier() -> HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier.dietaryCarbohydrates
    }

    internal override func filterSamples(sortedSamples: [HKSample]) -> [HKSample] {
        DDLogVerbose("trace")
        // For carbs, don't filter anything out yet!
        return sortedSamples
    }
    
    // override!
    internal override func typeSpecificMetadata() -> [(metaKey: String, metadatum: AnyObject)] {
        DDLogVerbose("trace")
        let metadata: [(metaKey: String, metadatum: AnyObject)] = []
        return metadata
    }
    
    internal override func deviceModelForSourceBundleIdentifier(_ sourceBundleIdentifier: String) -> String {
        DDLogInfo("Unknown cbg sourceBundleIdentifier: \(sourceBundleIdentifier)")
        let deviceModel = "Unknown: \(sourceBundleIdentifier)"
        // Note: this will return something like HealthKit_Unknown: com.apple.Health_060EF7B3-9D86-4B93-9EE1-2FC6C618A4AD
        // TODO: figure out what Link might put here. Also, if we have com.apple.Health, and it is is user entered, this would be a direct user HK entry: what should we put?
        return "HealthKit_\(deviceModel)"
    }
    
    internal override func prepareDataForUpload(_ data: HealthKitUploadData) -> [[String: AnyObject]] {
        DDLogInfo("carb prepareDataForUpload")
        let dateFormatter = DateFormatter()
        var samplesToUploadDictArray = [[String: AnyObject]]()
        for sample in data.filteredSamples {
            var sampleToUploadDict = [String: AnyObject]()
            
            //sampleToUploadDict["uploadId"] = data.batchMetadata["uploadId"]
            sampleToUploadDict["type"] = "food" as AnyObject?
            sampleToUploadDict["deviceId"] = data.batchMetadata["deviceId"]
            //sampleToUploadDict["guid"] = sample.uuid.uuidString as AnyObject?
            sampleToUploadDict["time"] = dateFormatter.isoStringFromDate(sample.startDate, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime) as AnyObject?
            
            if let quantitySample = sample as? HKQuantitySample {
                let unit = HKUnit(from: "g")
                let value = quantitySample.quantity.doubleValue(for: unit)
                DDLogInfo("carb value: \(String(describing: value))")
                var nutrition = [String: AnyObject]()
                let carbs = [
                    "net": value,
                    "units": "grams"
                    ] as [String : Any]
                nutrition["carbohydrate"] = carbs as AnyObject?
                sampleToUploadDict["nutrition"] = nutrition as AnyObject?
                
                // Add sample metadata payload props
                // TODO: document this time format adjust!
                if var metadata = sample.metadata {
                    for (key, value) in metadata {
                        if let dateValue = value as? Date {
                            metadata[key] = dateFormatter.isoStringFromDate(dateValue, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
                        }
                    }
                    
                    sampleToUploadDict["payload"] = metadata as AnyObject?
                }
                // Add sample if valid...
                samplesToUploadDictArray.append(sampleToUploadDict)
            }
            
        }
        return samplesToUploadDictArray
    }
}

