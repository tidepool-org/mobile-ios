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

class HealthKitUploadTypeBloodGlucose: HealthKitUploadType {
    init() {
        super.init("BloodGlucose")
    }

    // MARK: Overrides!
    
    internal override func hkQuantityTypeIdentifier() -> HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier.bloodGlucose
    }
    
    internal override func filterSamples(sortedSamples: [HKSample]) -> [HKSample] {
        DDLogVerbose("trace")
        
        // Filter out non-Dexcom data
        var filteredSamples = [HKSample]()
        
        for sample in sortedSamples {
            let sourceRevision = sample.sourceRevision
            let source = sourceRevision.source
            let treatAllBloodGlucoseSourceTypesAsDexcom = UserDefaults.standard.bool(forKey: HealthKitSettings.TreatAllBloodGlucoseSourceTypesAsDexcomKey)
            if source.name.lowercased().range(of: "dexcom") == nil && !treatAllBloodGlucoseSourceTypesAsDexcom {
                DDLogInfo("Ignoring non-Dexcom glucose data from source: \(source.name)")
                continue
            }
            
            filteredSamples.append(sample)
        }
        
        return filteredSamples
    }
    
    // override!
    internal override func typeSpecificMetadata() -> [(metaKey: String, metadatum: AnyObject)] {
        DDLogVerbose("trace")
        var metadata: [(metaKey: String, metadatum: AnyObject)] = []
        metadata.append((metaKey: "deviceTags", metadatum: ["cgm"] as AnyObject))
        metadata.append((metaKey: "deviceManufacturers", metadatum: ["Dexcom"] as AnyObject))
        return metadata
    }
    
    internal override func deviceModelForSourceBundleIdentifier(_ sourceBundleIdentifier: String) -> String {
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

    internal override func prepareDataForUpload(_ data: HealthKitUploadData) -> [[String: AnyObject]] {
        let dateFormatter = DateFormatter()
        var samplesToUploadDictArray = [[String: AnyObject]]()
        for sample in data.filteredSamples {
            var sampleToUploadDict = [String: AnyObject]()
            
            sampleToUploadDict["uploadId"] = data.batchMetadata["uploadId"]
            sampleToUploadDict["type"] = "cbg" as AnyObject?
            sampleToUploadDict["deviceId"] = data.batchMetadata["deviceId"]
            sampleToUploadDict["guid"] = sample.uuid.uuidString as AnyObject?
            sampleToUploadDict["time"] = dateFormatter.isoStringFromDate(sample.startDate, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime) as AnyObject?
            
            if let quantitySample = sample as? HKQuantitySample {
                let units = "mg/dL"
                sampleToUploadDict["units"] = units as AnyObject?
                let unit = HKUnit(from: units)
                let value = quantitySample.quantity.doubleValue(for: unit)
                sampleToUploadDict["value"] = value as AnyObject?
                
                // Add out-of-range annotation if needed
                var annotationCode: String?
                var annotationValue: String?
                var annotationThreshold = 0
                if (value < 40) {
                    annotationCode = "bg/out-of-range"
                    annotationValue = "low"
                    annotationThreshold = 40
                } else if (value > 400) {
                    annotationCode = "bg/out-of-range"
                    annotationValue = "high"
                    annotationThreshold = 400
                }
                if let annotationCode = annotationCode,
                    let annotationValue = annotationValue {
                    let annotations = [
                        [
                            "code": annotationCode,
                            "value": annotationValue,
                            "threshold": annotationThreshold
                        ]
                    ]
                    sampleToUploadDict["annotations"] = annotations as AnyObject?
                }
            }
            
            // Add sample metadata payload props
            if var metadata = sample.metadata {
                for (key, value) in metadata {
                    if let dateValue = value as? Date {
                        if key == "Receiver Display Time" {
                            metadata[key] = dateFormatter.isoStringFromDate(dateValue, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateNoTimeZone)
                            
                        } else {
                            metadata[key] = dateFormatter.isoStringFromDate(dateValue, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
                        }
                    }
                }
                
                // If "Receiver Display Time" exists, use that as deviceTime and remove from metadata payload
                if let receiverDisplayTime = metadata["Receiver Display Time"] {
                    sampleToUploadDict["deviceTime"] = receiverDisplayTime as AnyObject?
                    metadata.removeValue(forKey: "Receiver Display Time")
                }
                sampleToUploadDict["payload"] = metadata as AnyObject?
            }
            
            // Add sample
            samplesToUploadDictArray.append(sampleToUploadDict)
        }
        return samplesToUploadDictArray
    }
}

