//
//  NutMeal.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/21/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation

struct NutMeal {
    
    var title: String
    var notes: String
    var location: String
    var photo: String
    var time: NSDate
    
    init(title: String?, notes: String?, location: String?, photo: String?, time: NSDate?) {
        self.title = title != nil ? title! : ""
        self.notes = notes != nil ? notes! : ""
        self.location = location != nil ? location! : ""
        self.photo = photo != nil ? photo! : ""
        if time != nil {
            self.time = time!
        } else {
            self.time = NSDate()
            print("ERROR: nil time leaked in for event \(self.title)")
        }
    }
}