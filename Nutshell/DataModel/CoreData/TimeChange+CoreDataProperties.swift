//
//  TimeChange+CoreDataProperties.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension TimeChange {

    @NSManaged var changeFrom: Date?
    @NSManaged var changeTo: Date?
    @NSManaged var changeAgent: String?
    @NSManaged var changeTimezone: String?
    @NSManaged var changeReasons: String?

}
