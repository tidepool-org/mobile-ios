//
//  BloodKetone.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class BloodKetone: CommonData {
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> BloodKetone? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "BloodKetone", in: moc) {
            let me = BloodKetone(entity: entityDescription, insertInto: nil)
            
            me.value = TidepoolMobileUtils.decimalFromJSON(json["value"].string)
            
            return me
        }
        return nil
    }
}
