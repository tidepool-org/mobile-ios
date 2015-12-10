//
//  User.swift
//  
//
//  Created by Brian King on 9/14/15.
//
//

import Foundation
import CoreData
import SwiftyJSON


class User: NSManagedObject {
    class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> User? {
        if let entityDescription = NSEntityDescription.entityForName("User", inManagedObjectContext: moc) {
            let me = User(entity: entityDescription, insertIntoManagedObjectContext: nil)
            
            me.userid = json["userid"].string
            me.username = json["username"].string
            me.fullName = json["fullName"].string
            me.token = json["token"].string
            
            return me
        }
        return nil
    }
}
