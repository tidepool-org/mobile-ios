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
    internal let iso8601dateZuluTime: String = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

    internal func addCommonFields(sampleToUploadDict: inout [String: AnyObject], sample: HKSample) {
        sampleToUploadDict["time"] = dateFormatter.isoStringFromDate(sample.startDate, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime) as AnyObject?
        
        // add optional application origin
        if let origin = sampleOrigin(sample) {
            // Don't let invalid json crash the app during later serialization!
            if JSONSerialization.isValidJSONObject(origin) {
                // Add metadata values as the payload struct
                sampleToUploadDict["origin"] = origin as AnyObject
            } else {
                DDLogError("Invalid origin failed to serialize: \(String(describing:origin)), for type: \(typeName), guid: \(sampleToUploadDict["guid"] ?? "no guid" as AnyObject)")
            }
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
            // HKQuantity values won't serialize as json, so convert to string here...
            if let quantityValue = value as? HKQuantity {
                metadata[key] = String(describing: quantityValue)
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
    
    internal func sampleOrigin(_ sample: HKSample) -> [String: AnyObject]? {
        
        var origin: [String: AnyObject] = [
            "id": sample.uuid.uuidString as AnyObject,
            "name": "com.apple.HealthKit" as AnyObject,
            "type": "service" as AnyObject
        ]

        if let userEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool {
            if userEntered {
                origin["type"] = "service" as AnyObject
            }
        }
        
        var payloadDict = [String: AnyObject]()
        
        //let sourceBundleName = sample.sourceRevision.source.bundleIdentifier.lowercased()
        //TODO: sync syntax check with service!
        //if isValidReverseDomain(sourceBundleName) {
        //    payloadDict["sourceRevision"] = sourceBundleName as AnyObject
        //}
        
        var sourceRevisionDict = [String: AnyObject]()
        var sourceRevSrcDict = [String: String]()
        sourceRevSrcDict["bundleIdentifier"] = sample.sourceRevision.source.bundleIdentifier
        sourceRevSrcDict["name"] = sample.sourceRevision.source.name
        sourceRevisionDict["source"] = sourceRevSrcDict as AnyObject
        if let version = sample.sourceRevision.version {
            sourceRevisionDict["version"] = version as AnyObject
        }
        if let productType = sample.sourceRevision.productType {
            sourceRevisionDict["productType"] = productType as AnyObject
        }
        let version = sample.sourceRevision.operatingSystemVersion
        let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        sourceRevisionDict["operatingSystemVersion"] = versionString as AnyObject
        payloadDict["sourceRevision"] = sourceRevisionDict as AnyObject
        
        if let device = sample.device {
            var deviceDict = [String: String]()
            if let name = device.name {
                deviceDict["name"] = name
            }
            if let model = device.model {
                deviceDict["model"] = model
            }
            if let manufacturer = device.manufacturer {
                deviceDict["manufacturer"] = manufacturer
            }
            if let udiDeviceIdentifier = device.udiDeviceIdentifier {
                deviceDict["udiDeviceIdentifier"] = udiDeviceIdentifier
            }
            if let localIdentifier = device.localIdentifier {
                deviceDict["localIdentifier"] = localIdentifier
            }
            if let firmwareVersion = device.firmwareVersion {
                deviceDict["firmwareVersion"] = firmwareVersion
            }
            if let hardwareVersion = device.hardwareVersion {
                deviceDict["hardwareVersion"] = hardwareVersion
            }
            if let softwareVersion = device.softwareVersion {
                deviceDict["softwareVersion"] = softwareVersion
            }
            if !deviceDict.isEmpty {
                payloadDict["device"] = deviceDict as AnyObject
            }
        }
        
        if !payloadDict.isEmpty {
            origin["payload"] = payloadDict as AnyObject
        }
        
        return origin
    }
    
    let reverseDomainTest = NSPredicate(format:"SELF MATCHES %@", reverseDomainRegEx)
    // Service requirement: Must start with 2-63 lower-case alpha characters, followed by a period, followed by lower-case alpha or 0-9 characters. E.g., failures include "com.Apple" (includes uppercase), "q5awl8wcy6.imapmyrunplus" (has numbers in the first part), etc.
    internal func isValidReverseDomain(_ testStr:String) -> Bool {
        return reverseDomainTest.evaluate(with: testStr)
    }

    internal func prepareDataForDelete(_ data: HealthKitUploadData) -> [[String: AnyObject]] {
        DDLogInfo("\(#function)")
        var samplesToDeleteDictArray = [[String: AnyObject]]()
        for sample in data.deletedSamples {
            var sampleToDeleteDict = [String: AnyObject]()
            let origin: [String: AnyObject] = [
                "id": sample.uuid.uuidString as AnyObject
            ]
            sampleToDeleteDict["origin"] = origin as AnyObject
            samplesToDeleteDictArray.append(sampleToDeleteDict)
        }
        return samplesToDeleteDictArray
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
    internal func prepareDataForUpload(_ data: HealthKitUploadData) -> [[String: AnyObject]] {
        return [[String: AnyObject]]()
    }
    
}

