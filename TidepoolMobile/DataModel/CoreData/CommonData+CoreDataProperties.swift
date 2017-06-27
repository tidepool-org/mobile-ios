//
//  CommonData+CoreDataProperties.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension CommonData {

    @NSManaged var id: NSString?
    @NSManaged var type: NSString?
    @NSManaged var time: Date?
    @NSManaged var deviceId: String?
    @NSManaged var uploadId: String?
    @NSManaged var previous: String?
    @NSManaged var timezoneOffset: NSNumber?
    @NSManaged var deviceTime: Date?
    @NSManaged var units: String?
    @NSManaged var createdTime: Date?
    @NSManaged var modifiedTime: Date?
    @NSManaged var payload: String?
    @NSManaged var annotations: String?

}
