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
import CocoaLumberjack


class User: NSManagedObject {
    
    class func fromJSON(_ json: JSON, email: String? = nil, moc: NSManagedObjectContext) -> User? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "User", in: moc) {
            let me = User(entity: entityDescription, insertInto: nil)
            
            me.userid = json["userid"].string
            me.username = json["username"].string
            me.fullName = json["fullName"].string
            me.token = json["token"].string
            me.email = email
            return me
        }
        return nil
    }
    
    func processProfileJSON(_ json: JSON) {
        DDLogInfo("profile json: \(json)")
        fullName = json["fullName"].string
        if fullName != nil {
            self.managedObjectContext?.refresh(self, mergeChanges: true)
            DDLogInfo("Added full name from profile: \(fullName!))")
        }
        let patient = json["patient"]
        let isDSA = patient != JSON.null
        if isDSA {
            accountIsDSA = NSNumber.init(value: isDSA)
            biologicalSex = patient["biologicalSex"].string
        }
    }
    
    func updateBiologicalSex(_ biologicalSex: String) {
        self.biologicalSex = biologicalSex
        guard let moc = self.managedObjectContext else {
            return
        }
        do {
            moc.refresh(self, mergeChanges: true)
            try moc.save()
        } catch {
            DDLogError("Failed to save changes!")
        }
    }
}
