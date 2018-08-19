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
    internal override func hkSampleType() -> HKSampleType? {
        return HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
    }

    internal override func filterSamples(sortedSamples: [HKSample]) -> [HKSample] {
        DDLogVerbose("trace")
        // For now, don't filter anything out!
        return sortedSamples

//        // Filter out non-Dexcom data
//        var filteredSamples = [HKSample]()
//
//        for sample in sortedSamples {
//            let sourceRevision = sample.sourceRevision
//            let source = sourceRevision.source
//            let treatAllBloodGlucoseSourceTypesAsDexcom = UserDefaults.standard.bool(forKey: HealthKitSettings.TreatAllBloodGlucoseSourceTypesAsDexcomKey)
//            if source.name.lowercased().range(of: "dexcom") == nil && !treatAllBloodGlucoseSourceTypesAsDexcom {
//                DDLogInfo("Ignoring non-Dexcom glucose data from source: \(source.name)")
//                continue
//            }
//
//            filteredSamples.append(sample)
//        }
//        
//        return filteredSamples
    }
        
    internal override func deviceModelForSourceBundleIdentifier(_ sourceBundleIdentifier: String) -> String {
        var deviceModel = ""
        
        // TODO: uploader - what about G6? others?
        if sourceBundleIdentifier.lowercased().range(of: "com.dexcom.cgm") != nil {
            deviceModel = "DexG5"
        } else if sourceBundleIdentifier.lowercased().range(of: "com.dexcom.share2") != nil {
            deviceModel = "DexG4"
        } else {
            DDLogInfo("Unknown cbg sourceBundleIdentifier: \(sourceBundleIdentifier)")
            deviceModel = "Unknown: \(sourceBundleIdentifier)"
            // Note: this will return something like HealthKit_Unknown: com.apple.Health_060EF7B3-9D86-4B93-9EE1-2FC6C618A4AD
            // TODO: figure out what LoopKit might put here. Also, if we have com.apple.Health, and it is is user entered, this would be a direct user HK entry: what should we put?
        }
        
        return "HealthKit_\(deviceModel)"
    }

    internal override func prepareDataForUpload(_ data: HealthKitUploadData) -> [[String: AnyObject]] {
        //DDLogInfo("blood glucose prepareDataForUpload")
        //let dateFormatter = DateFormatter()
        var samplesToUploadDictArray = [[String: AnyObject]]()
        for sample in data.filteredSamples {
            var sampleToUploadDict = [String: AnyObject]()
            sampleToUploadDict["type"] = "cbg" as AnyObject?
            // Add fields common to all types: guid, deviceId, time, and origin
            super.addCommonFields(sampleToUploadDict: &sampleToUploadDict, sample: sample)

            if let quantitySample = sample as? HKQuantitySample {
                let units = "mg/dL"
                sampleToUploadDict["units"] = units as AnyObject?
                let unit = HKUnit(from: units)
                let value = quantitySample.quantity.doubleValue(for: unit)
                sampleToUploadDict["value"] = value as AnyObject?
                //DDLogInfo("blood glucose value: \(String(describing: value))")

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
            
            // separate out receiver display time if it exists...
            if var metadata = sample.metadata {
                // If "HKWasUserEntered" exists and is true, change type to "smbg" and remove from metadata
                if let wasUserEntered = metadata[HKMetadataKeyWasUserEntered] as? Bool {
                    if wasUserEntered {
                        sampleToUploadDict["type"] = "smbg" as AnyObject?
                    }
                }
                // Add remaining metadata, if any, as payload struct
                addMetadata(&metadata, sampleToUploadDict: &sampleToUploadDict)
            }
            // Add sample
            samplesToUploadDictArray.append(sampleToUploadDict)
        }
        return samplesToUploadDictArray
    }
}

