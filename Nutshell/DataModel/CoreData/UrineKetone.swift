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
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> UrineKetone? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "UrineKetone", in: moc) {
            let me = UrineKetone(entity: entityDescription, insertInto: nil)
            
            me.value = json["value"].string
                        
            return me
        }
        
        return nil
    }
}
