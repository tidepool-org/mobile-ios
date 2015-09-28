//
//  Basal+CoreDataProperties.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/17/15.
//  Copyright © 2015 Tidepool. All rights reserved.
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

}
