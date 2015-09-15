//
//  User+CoreDataProperties.swift
//  
//
//  Created by Brian King on 9/14/15.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension User {

    @NSManaged var userid: String?
    @NSManaged var username: String?
    @NSManaged var fullName: String?

}
