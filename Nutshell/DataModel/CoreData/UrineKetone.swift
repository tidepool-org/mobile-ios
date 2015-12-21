//
//  UrineKetone.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class UrineKetone: CommonData {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> UrineKetone? {
        if let entityDescription = NSEntityDescription.entityForName("UrineKetone", inManagedObjectContext: moc) {
            let me = UrineKetone(entity: entityDescription, insertIntoManagedObjectContext: nil)
            
            me.value = json["value"].string
                        
            return me
        }
        
        return nil
    }
}
