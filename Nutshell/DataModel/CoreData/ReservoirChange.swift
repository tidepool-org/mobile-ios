//
//  ReservoirChange.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class ReservoirChange: DeviceMetadata {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> ReservoirChange? {
        if let entityDescription = NSEntityDescription.entityForName("ReservoirChange", inManagedObjectContext: moc) {
            let me = ReservoirChange(entity: entityDescription, insertIntoManagedObjectContext: nil)
            
            me.status = json["status"].string
            
            return me
        }
        
        return nil
    }
}
