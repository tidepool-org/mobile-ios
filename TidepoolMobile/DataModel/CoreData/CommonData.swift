//
//  CommonData.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class CommonData: NSManagedObject {
    // TODO: add code to download "meal" and "workout" items from service once they are supported and we upload them
    class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> CommonData? {
        // The type of object we create is based on the "type" field
        var newObject: CommonData? = nil
        if let type = json["type"].string {
            switch type {
                case "activity":            newObject = Activity.fromJSON(json, moc: moc)
                case "basal":               newObject = Basal.fromJSON(json, moc: moc)
                case "bolus":               newObject = Bolus.fromJSON(json, moc: moc)
                case "cbg":                 newObject = ContinuousGlucose.fromJSON(json, moc: moc)
                
                // The documentation indicates "deviceMeta", but the actual JSON shows "deviceEvent"
                case "deviceEvent", "deviceMeta": newObject = DeviceMetadata.fromJSON(json, moc: moc)
                
                case "food":                newObject = Food.fromJSON(json, moc: moc)
                case "grabbag":             newObject = GrabBag.fromJSON(json, moc: moc)
                case "bloodKetone":         newObject = BloodKetone.fromJSON(json, moc: moc)
                case "urineKetone":         newObject = UrineKetone.fromJSON(json, moc: moc)
                case "note":                newObject = Note.fromJSON(json, moc: moc)
                case "smbg":                newObject = SelfMonitoringGlucose.fromJSON(json, moc: moc)
                case "settings":            newObject = Settings.fromJSON(json, moc: moc)
                case "upload":              newObject = Upload.fromJSON(json, moc: moc)
                case "wizard":              newObject = Wizard.fromJSON(json, moc: moc)
                
                default:                    print("CommonData: Unknown type \(type)")
            }
            
            // If we got an object, set the common properties on it
            if let newObject = newObject {
                
                if let id = json["id"].string {
                    newObject.id = id as NSString?
                } else {
                     print("skipped record of type \(type) missing id")
                    return nil
                }
                newObject.type = type as NSString?
                
                if let timeString = json["time"].string {
                    if let time = NutUtils.dateFromJSON(timeString) {
                        newObject.time = time
                    } else {
                        print("skipped record of type \(type) with unknown time format: \(timeString)")
                        return nil
                    }
                } else {
                    print("skipped record of type \(type) with missing time field")
                    return nil
                }

                newObject.time = NutUtils.dateFromJSON(json["time"].string)
                
                
                newObject.deviceId = json["deviceId"].string
                newObject.uploadId = json["uploadId"].string
                newObject.previous = json["previous"].string
                newObject.timezoneOffset = json["timezoneOffset"].number
                newObject.deviceTime = NutUtils.dateFromJSON(json["deviceTime"].string)
                newObject.units = json["units"].string
                newObject.createdTime = NutUtils.dateFromJSON(json["createdTime"].string)
                newObject.modifiedTime = NutUtils.dateFromJSON(json["modifiedTime"].string)
                newObject.payload = json["payload"].string
                newObject.annotations = json["annotations"].string
            }
        }
        
        return newObject
    }
}
