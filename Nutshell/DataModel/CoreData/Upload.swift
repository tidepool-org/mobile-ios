//
//  Upload.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Upload: CommonData {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> Upload? {
        if let entityDescription = NSEntityDescription.entityForName("Upload", inManagedObjectContext: moc) {
            let me = Upload(entity: entityDescription, insertIntoManagedObjectContext: nil)
            
            me.timezone = json["timezone"].string
            me.version = json["version"].string
            me.byUser = json["byUser"].string
            me.deviceTagsJSON = json["deviceTags"].string
            me.deviceManufacturersJSON = json["deviceManufacturers"].string
            me.deviceModel = json["deviceModel"].string
            me.deviceSerialNumber = json["deviceSerialNumber"].string
            
            return me
        }
        
        return nil
    }
}
