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
    var notes: String
    var time: NSDate
    
    init(title: String?, notes: String?, time: NSDate?) {
        self.title = title != nil ? title! : ""
        self.notes = notes != nil ? notes! : ""
        
        if time != nil {
            self.time = time!
        } else {
            self.time = NSDate()
            print("ERROR: nil time leaked in for event \(self.title)")
        }
    }
}
