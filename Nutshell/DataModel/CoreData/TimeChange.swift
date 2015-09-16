//
//  TimeChange.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class TimeChange: DeviceMetadata {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> TimeChange? {
        if let entityDescription = NSEntityDescription.entityForName("TimeChange", inManagedObjectContext: moc) {
            let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! TimeChange
            
            me.changeFrom = NutUtils.dateFromJSON(json["changeFrom"].string)
            me.changeTo = NutUtils.dateFromJSON(json["changeTo"].string)
            me.changeAgent = json["changeAgent"].string
            me.changeTimezone = json["changeTimezone"].string
            me.changeReasons = json["changeReasons"].string
            
            return me
        }
        
        return nil
    }
}
