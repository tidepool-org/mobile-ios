//
//  User+CoreDataProperties.swift
//  
//
//  Created by Larry Kenyon on 3/24/16.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Hashtag {

    @NSManaged var text: String?
    @NSManaged var userid: String?
    @NSManaged var usages: NSNumber?

}
