//
//  EventItem+CoreDataProperties.swift
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

extension EventItem {

    @NSManaged var notes: String?
    @NSManaged var nutCracked: NSNumber?
    @NSManaged var title: String?
    @NSManaged var userid: String?

}
