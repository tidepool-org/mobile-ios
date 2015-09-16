/*
* Copyright (c) 2015, Tidepool Project
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

import UIKit
import CoreData

class NutUtils {

    class func dispatchBoolToVoidAfterSecs(secs: Float, result: Bool, boolToVoid: (Bool) -> (Void)) {
        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(secs * Float(NSEC_PER_SEC)))
        dispatch_after(time, dispatch_get_main_queue()){
            boolToVoid(result)
        }
    }
    
    class func dateFromJSON(json: String?) -> NSDate? {
        if let json = json {
            return jsonDateFormatter.dateFromString(json)
        }
        return nil
    }
    
    class func decimalFromJSON(json: String?) -> NSDecimalNumber? {
        if let json = json {
            return NSDecimalNumber(string: json)
        }
        return nil
    }

    /** Date formatter for JSON date strings */
    class var jsonDateFormatter : NSDateFormatter {
        struct Static {
            static let instance: NSDateFormatter = {
                let dateFormatter = NSDateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                return dateFormatter
                }()
        }
        return Static.instance
    }
    
    class func removeAllDatabaseEntries(moc: NSManagedObjectContext) {
        let entities = ["Activity", "Alarm", "Basal", "BloodKetone", "Bolus", "Calibration",
        "ContinuousGlucose", "Food", "GrabBag", "Note", "Prime", "ReservoirChange", "SelfMonitoringGlucose",
        "Settings", "Status", "TimeChange", "Upload", "UrineKetone", "Wizard"]
        
        for entity in entities {
            do {
                let request = NSFetchRequest(entityName: entity)
                let myList = try moc.executeFetchRequest(request)
                for obj: AnyObject in myList {
                    moc.deleteObject(obj as! NSManagedObject)
                }
            } catch let error as NSError {
                print("Failed to delete \(entity) items: \(error)")
            }
        }
        
        do {
            try moc.save()
        } catch let error as NSError {
            print("Failed to save MOC: \(error)")
        }
    }
}