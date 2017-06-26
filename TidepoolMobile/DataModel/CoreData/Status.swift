//
//  Status.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Status: DeviceMetadata {
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> Status? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "Status", in: moc) {
            let me = Status(entity: entityDescription, insertInto: nil)
            
            me.status = json["status"].string
            me.reason = json["reason"].string
            me.duration = json["duration"].number
            
            return me
        }
        
        return nil
    }
}
