//
//  Prime.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Prime: DeviceMetadata {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> Prime? {
        if let entityDescription = NSEntityDescription.entityForName("Prime", inManagedObjectContext: moc) {
            let me = Prime(entity: entityDescription, insertIntoManagedObjectContext: nil) 
            
            me.primeTarget = json["primeTarget"].string
            me.volume = NutUtils.decimalFromJSON(json["volume"].string)

            return me
        }
        
        return nil
    }
}
