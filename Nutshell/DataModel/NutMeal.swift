//
//  NutMeal.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/21/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation

class NutMeal: NutEventItem {
    
    var photo: String
    var meal: Meal
    
    init(meal: Meal, title: String?, notes: String?, location: String?, photo: String?, time: NSDate?) {
        self.photo = photo ?? ""
        self.meal = meal
        super.init(title: title, notes: notes, time: time)
        if location != nil {
            self.location = location!
        }
    }
}