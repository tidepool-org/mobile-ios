//
//  Wizard.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Wizard: CommonData {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> Wizard? {
        if let entityDescription = NSEntityDescription.entityForName("Wizard", inManagedObjectContext: moc) {
            let me = Wizard(entity: entityDescription, insertIntoManagedObjectContext: nil) 
            me.bgInput = json["bgInput"].number
            me.carbInput = json["carbInput"].number
            me.insulinOnBoard = json["insulinOnBoard"].number
            // Rename to "recommendedNet"
            me.insulinCarbRatio = json["recommended"]["net"].number
            me.insulinSensitivity = json["insulinSensitivity"].number
            me.bolus = json["bolus"].string
            
            return me
        }
        
        return nil
    }
}
