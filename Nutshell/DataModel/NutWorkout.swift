//
//  NutWorkout.swift
//  Nutshell
//
//  Created by Larry Kenyon on 10/6/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation

class NutWorkout: NutEventItem {
    
    var distance: NSNumber?
    var duration: TimeInterval
    var calories: NSNumber?
    
    init(workout: Workout) {
        self.distance = workout.distance
        self.duration = TimeInterval(workout.duration ?? 0.0)
        self.calories = workout.calories
        super.init(eventItem: workout)
    }

    override func prefix() -> String {
        // Subclass!
        return "W"
    }

    //
    // MARK: - Overrides
    //
    
    override func copyChanges() {
        if let workout = eventItem as? Workout {
            workout.distance = distance
            workout.duration = duration as NSNumber?
        }
        super.copyChanges()
    }
    
    override func changed() -> Bool {
        if let workout = eventItem as? Workout {
            let currentDistance = workout.distance ?? 0.0
            if distance != currentDistance {
                return true
            }
            let currentDuration = workout.duration ?? 0.0
            if duration != currentDuration.doubleValue {
                return true
            }
        }
        return super.changed()
    }
}
