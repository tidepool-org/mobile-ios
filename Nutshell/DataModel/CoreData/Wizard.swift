//
//  Wizard.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Wizard: CommonData {
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> Wizard? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "Wizard", in: moc) {
            let me = Wizard(entity: entityDescription, insertInto: nil) 
            me.bgInput = json["bgInput"].number
            me.carbInput = json["carbInput"].number
            me.insulinOnBoard = json["insulinOnBoard"].number
            me.recommendedNet = json["recommended"]["net"].number
            me.insulinSensitivity = json["insulinSensitivity"].number
            me.bolus = json["bolus"].string
            
            return me
        }
        
        return nil
    }
}
