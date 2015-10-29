//
//  NutEventItem.swift
//  Nutshell
//
//  Created by Larry Kenyon on 10/6/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation

class NutEventItem {
    
    var title: String
    var location: String
    var notes: String
    var time: NSDate
    var nutCracked: Bool = false
    
    init(title: String?, notes: String?, time: NSDate?) {
        self.title = title != nil ? title! : ""
        self.location = ""
        self.notes = notes != nil ? notes! : ""
        
        if time != nil {
            self.time = time!
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
}

func != (left: NutEventItem, right: NutEventItem) -> Bool {
    // TODO: if we had an id, we could just check that!
    return ((left.notes != right.notes) || (left.time != right.time))
}

