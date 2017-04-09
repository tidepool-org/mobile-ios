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
    class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> User? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "User", in: moc) {
            let me = User(entity: entityDescription, insertInto: nil)
            
            me.userid = json["userid"].string
            me.username = json["username"].string
            me.fullName = json["fullName"].string
            me.token = json["token"].string
            
            return me
        }
        return nil
    }
    
    func processProfileJSON(_ json: JSON) {
        NSLog("profile json: \(json)")
        fullName = json["fullName"].string
        if fullName != nil {
            self.managedObjectContext?.refresh(self, mergeChanges: true)
            NSLog("Added full name from profile: \(fullName!))")
        }
        let patient = json["patient"]
        let isDSA = patient != JSON.null
        accountIsDSA = NSNumber.init(value: isDSA)
    }
}
