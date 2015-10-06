//
//  NutMeal.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/21/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation

class NutMeal: NutEventItem {
    
    var location: String
    var photo: String
    
    init(title: String?, notes: String?, location: String?, photo: String?, time: NSDate?) {
        self.location = location != nil ? location! : ""
        self.photo = photo != nil ? photo! : ""
        super.init(title: title, notes: notes, time: time)
    }
}