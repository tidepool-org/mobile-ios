//
//  GrabBag.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class GrabBag: CommonData {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> GrabBag? {
        if let entityDescription = NSEntityDescription.entityForName("GrabBag", inManagedObjectContext: moc) {
            let me = GrabBag(entity: entityDescription, insertIntoManagedObjectContext: nil)
            
            me.subType = json["subType"].string
            
            return me
        }
        
        return nil
    }
}
