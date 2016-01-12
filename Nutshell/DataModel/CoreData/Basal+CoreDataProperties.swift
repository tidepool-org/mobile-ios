//
//  Basal+CoreDataProperties.swift
//  
//
//  Created by Larry Kenyon on 12/15/15.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Basal {

    @NSManaged var deliveryType: String?
    @NSManaged var duration: NSNumber?
    @NSManaged var insulin: String?
    @NSManaged var value: NSNumber?
    @NSManaged var suppressedRate: NSNumber?

}
