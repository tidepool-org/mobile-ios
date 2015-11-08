//
//  NutEventItem.swift
//  Nutshell
//
//  Created by Larry Kenyon on 10/6/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import UIKit

class NutEventItem {
    
    var title: String
    var location: String
    var notes: String
    var time: NSDate
    var nutCracked: Bool = false
    var eventItem: EventItem
    
    init(eventItem: EventItem) {
        self.eventItem = eventItem
        self.title = eventItem.title ?? ""
        self.location = ""
        self.notes = eventItem.notes ?? ""
        if eventItem.nutCracked != nil {
            self.nutCracked = Bool(eventItem.nutCracked!)
        }
        
        if eventItem.time != nil {
            self.time = eventItem.time!
        } else {
            self.time = NSDate()
            print("ERROR: nil time leaked in for event \(self.title)")
        }
    }
    
    func nutEventIdString() -> String {
        // TODO: this will alias:
        //  title: "My NutEvent at Home", loc: "" with
        //  title: "My NutEvent at ", loc: "Home"
        // But for now consider this a feature...
        return title + location
    }
    
    func containsSearchString(searchString: String) -> Bool {
        if notes.localizedCaseInsensitiveContainsString(searchString) {
            return true
        }
        return false;
    }
    
    func saveChanges() -> Bool {
        var result = true
        if changed() {
            copyChanges()
            let ad = UIApplication.sharedApplication().delegate as! AppDelegate
            let moc = ad.managedObjectContext
            eventItem.modifiedTime = NSDate()
            moc.refreshObject(eventItem, mergeChanges: true)
            result = DatabaseUtils.databaseSave(moc)
        }
        return result
    }

    func deleteItem() -> Bool {
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = ad.managedObjectContext
        moc.deleteObject(self.eventItem)
        return DatabaseUtils.databaseSave(moc)
    }

    //
    // MARK: - Override in subclasses!
    //

    func changed() -> Bool {
        let currentTitle = eventItem.title ?? ""
        if currentTitle != title {
            return true
        }
        let currentNotes = eventItem.notes ?? ""
        if currentNotes != notes {
            return true
        }
        if eventItem.nutCracked == nil || nutCracked != Bool(eventItem.nutCracked!) {
            return true
        }
        if eventItem.time == nil || time != eventItem.time {
            return true
        }
        return false
    }
 
    func copyChanges() {
        eventItem.title = title
        eventItem.notes = notes
        eventItem.nutCracked = nutCracked
        eventItem.time = time
    }
    
    func firstPictureUrl() -> String {
        return ""
    }

}

func != (left: NutEventItem, right: NutEventItem) -> Bool {
    // TODO: if we had an id, we could just check that!
    return ((left.notes != right.notes) || (left.time != right.time))
}

