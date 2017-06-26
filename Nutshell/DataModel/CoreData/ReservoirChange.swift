//
//  ReservoirChange.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class ReservoirChange: DeviceMetadata {
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> ReservoirChange? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "ReservoirChange", in: moc) {
            let me = ReservoirChange(entity: entityDescription, insertInto: nil)
            
            me.status = json["status"].string
            
            return me
        }
        
        return nil
    }
}
