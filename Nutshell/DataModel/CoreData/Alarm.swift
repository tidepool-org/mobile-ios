//
//  Alarm.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Alarm: DeviceMetadata {
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> Alarm? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "Alarm", in: moc) {
            let me = Alarm(entity: entityDescription, insertInto: nil)
            
            me.alarmType = json["alarmType"].string
            me.status = json["status"].string
            
            return me
        }
        
        return nil
    }
}
