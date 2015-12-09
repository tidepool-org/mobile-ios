//
//  User+CoreDataProperties.swift
//  
//
//  Created by Larry Kenyon on 12/9/15.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension User {

    @NSManaged var fullName: String?
    @NSManaged var userid: String?
    @NSManaged var username: String?
    @NSManaged var token: String?

}
