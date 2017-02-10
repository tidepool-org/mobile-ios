//
//  Note+CoreDataProperties.swift
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

extension Note {

    @NSManaged var shortText: String?
    @NSManaged var text: String?
    @NSManaged var creatorId: String?
    @NSManaged var reference: String?
    @NSManaged var displayTime: Date?

}
