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
import HealthKit

class HealthKitUploadTypeBloodGlucose: HealthKitUploadType {
    init() {
        super.init("BloodGlucose")
    }

    // MARK: Overrides!
    internal override func hkSampleType() -> HKSampleType? {
        return HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
    }

    /// Whitelist for now to distinguish "cbg" types: all others are assumed to be "smbg". Also passes back whether this is a "Dexcom" sample.
    private func determineTypeOfBG(_ sample: HKQuantitySample) -> (type: String, isDexcom: Bool) {
        let bundleIdSeparators = CharacterSet(charactersIn: ".")
        // source string, isDexcom?
        let whiteListSources = [
            "loop" : false,
            "bgmtool" : false,
            "dexcom" : true,
            ]
        // bundleId string, isDexcom?
        let whiteListBundleIds = [
            "org.nightscoutfoundation.spike" : false,
            "com.spike-app.spike": false, // old TestFlight distribution
            ]
        // bundleId component string, isDexcom?
        let whiteListBundleComponents = [
            "loopkit" : false
        ]
        let kTypeCbg = "cbg"
        let kTypeSmbg = "smbg"

        // First check whitelisted sources for those we know are cbg sources...
        let sourceNameLowercased = sample.sourceRevision.source.name.lowercased()
        var isDexcom = whiteListSources[sourceNameLowercased]
        if isDexcom != nil {
            return (kTypeCbg, isDexcom!)
        }

        // source name prefixed with "dexcom" also counts to catch European app with source == "Dexcom 6"
        if sourceNameLowercased.hasPrefix("dexcom") {
            return (kTypeCbg, true)
        }

        // Also mark glucose data from HK as CGM data if any of the following are true:
        // (1) HKSource.bundleIdentifier is one of the following: com.dexcom.Share2, com.dexcom.CGM, com.dexcom.G6, or org.nightscoutfoundation.spike.
        // (1a) HKSource.bundleIdentifier has com.dexcom as a prefix (so more general compare)...

        let bundleIdLowercased = sample.sourceRevision.source.bundleIdentifier.lowercased()
        isDexcom = whiteListBundleIds[bundleIdLowercased]
        if isDexcom != nil {
            return (kTypeCbg, isDexcom!)
        }

        if bundleIdLowercased.hasPrefix("com.dexcom") {
            return (kTypeCbg, true)
        }

        // (2) HKSource.bundleIdentifier ends in .Loop
        if bundleIdLowercased.hasSuffix(".loop") {
            return (kTypeCbg, false)
        }

        // (3) HKSource.bundleIdentifier has loopkit as one of the (dot separated) components
        let bundleIdComponents = bundleIdLowercased.components(separatedBy: bundleIdSeparators)
        for comp in bundleIdComponents {
            isDexcom = whiteListBundleComponents[comp]
            if isDexcom != nil {
                return (kTypeCbg, isDexcom!)
            }
        }

        // (4) HKSource.bundleIdentifier has suffix of "xdripreader"
        if bundleIdLowercased.hasSuffix("xdripreader") {
            return (kTypeCbg, false)
        }

        // Assume everything else is smbg!
        return (kTypeSmbg, false)
    }

    override func prepareDataForUpload(_ sample: HKSample) -> [String: AnyObject]? {
        //DDLogInfo("blood glucose prepareDataForUpload")
        //let dateFormatter = DateFormatter()
            if let quantitySample = sample as? HKQuantitySample {
                var sampleToUploadDict = [String: AnyObject]()
                let typeOfBGSample = determineTypeOfBG(quantitySample)
                sampleToUploadDict["type"] = typeOfBGSample.type as AnyObject?
 
                // Add fields common to all types: guid, deviceId, time, and origin
                super.addCommonFields(sampleToUploadDict: &sampleToUploadDict, sample: sample)
                let units = "mg/dL"
                sampleToUploadDict["units"] = units as AnyObject?
                let unit = HKUnit(from: units)
                var value = quantitySample.quantity.doubleValue(for: unit)
                // service syntax check: [required; 0 <= value <= 1000]
                if value < 0 || value > 1000 {
                    //TODO: log this some more obvious way?
                    DDLogError("Blood glucose sample with out-of-range value: \(value)")
                    if !kDebugTurnOffSampleChecks {
                        return nil
                    }
                }
                
                // Add out-of-range annotation if needed, and adjust value, but only for Dexcom samples...
                if typeOfBGSample.isDexcom {
                    var annotationCode: String?
                    var annotationValue: String?
                    var annotationThreshold = 0
                    if (value < 40) {
                        annotationCode = "bg/out-of-range"
                        annotationValue = "low"
                        annotationThreshold = 40
                        // also set value to 39 as does the Tidepool Uploader...
                        value = 39
                    } else if (value > 400) {
                        annotationCode = "bg/out-of-range"
                        annotationValue = "high"
                        annotationThreshold = 400
                        // also set value to 401 as does the Tidepool Uploader...
                        value = 401
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
                sampleToUploadDict["value"] = value as AnyObject?
                //DDLogInfo("blood glucose value: \(String(describing: value))")

                if var metadata = sample.metadata {
                    if typeOfBGSample.type == "smbg" {
                        // If the blood glucose data point is NOT from a whitelisted cbg source AND is flagged in HealthKit as HKMetadataKeyWasUserEntered, then label it as subtype = manual
                        if let wasUserEntered = metadata[HKMetadataKeyWasUserEntered] as? Bool {
                            if wasUserEntered {
                                sampleToUploadDict["subType"] = "manual" as AnyObject?
                            }
                        }
                    }
                    // Special case for Dexcom, if "Receiver Display Time" exists, pass that as deviceTime and remove from metadata payload
                    if let receiverTime = metadata["Receiver Display Time"] {
                        if let date = receiverTime as? Date {
                            let formattedDate = dateFormatter.isoStringFromDate(date, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateNoTimeZone)
                            sampleToUploadDict["deviceTime"] = formattedDate as AnyObject?
                            metadata.removeValue(forKey: "Receiver Display Time")
                        }
                    }

                    // Add remaining metadata, if any, as payload struct
                    addMetadata(&metadata, sampleToUploadDict: &sampleToUploadDict)
                }
                
                // return sample
                return(sampleToUploadDict)
            } else {
                DDLogError("Encountered HKSample that was not an HKQuantitySample!")
                return nil
            }
        }

}

