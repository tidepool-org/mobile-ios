//
//  Food.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Food: CommonData {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> Food? {
        if let entityDescription = NSEntityDescription.entityForName("Food", inManagedObjectContext: moc) {
            let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Food
            
            me.carbs = NSDecimalNumber(string: json["carbs"].string)
            me.protein = NSDecimalNumber(string: json["protein"].string)
            me.fat = NSDecimalNumber(string: json["fat"].string)
            me.location = json["location"].string
            me.name = json["name"].string
            
            return me
        }
        
        return nil
    }
}
