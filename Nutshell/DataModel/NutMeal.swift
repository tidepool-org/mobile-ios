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
    
    init(title: String, notes: String, location: String, photo: String, time: NSDate) {
        self.title = title
        self.notes = notes
        self.location = location
        self.photo = photo
        self.time = time
    }
}