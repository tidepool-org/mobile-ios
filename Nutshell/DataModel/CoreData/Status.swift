//
//  Status.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Status: DeviceMetadata {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> Status? {
        if let entityDescription = NSEntityDescription.entityForName("Status", inManagedObjectContext: moc) {
            let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Status
            
            me.status = json["status"].string
            me.reason = json["reason"].string
            me.duration = json["duration"].number
            
            return me
        }
        
        return nil
    }
}
