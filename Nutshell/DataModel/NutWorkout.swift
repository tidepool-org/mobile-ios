//
//  NutWorkout.swift
//  Nutshell
//
//  Created by Larry Kenyon on 10/6/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation

class NutWorkout: NutEventItem {
    
    var distance: NSNumber
    var duration: NSTimeInterval
    var workout: Workout
    
    init(workout: Workout, title: String?, notes: String?, distance: NSNumber?, duration: NSNumber?, time: NSDate?) {
        self.distance = distance != nil ? distance! : 0.0
        self.duration = NSTimeInterval(duration != nil ? duration! : 0.0)
        self.workout = workout
        super.init(title: title, notes: notes, time: time)
    }
}
