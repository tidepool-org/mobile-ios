//
//  Prime.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Prime: DeviceMetadata {
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> Prime? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "Prime", in: moc) {
            let me = Prime(entity: entityDescription, insertInto: nil) 
            
            me.primeTarget = json["primeTarget"].string
            me.volume = NutUtils.decimalFromJSON(json["volume"].string)

            return me
        }
        
        return nil
    }
}
