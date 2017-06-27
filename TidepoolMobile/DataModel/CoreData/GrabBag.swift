//
//  GrabBag.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class GrabBag: CommonData {
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> GrabBag? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "GrabBag", in: moc) {
            let me = GrabBag(entity: entityDescription, insertInto: nil)
            
            me.subType = json["subType"].string
            
            return me
        }
        
        return nil
    }
}
