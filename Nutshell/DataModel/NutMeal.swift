//
//  NutMeal.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/21/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation

class NutMeal: NutEventItem {

    override func prefix() -> String {
        // Subclass!
        return "M"
    }

    var photo: String
    var photo2: String
    var photo3: String
    
    init(meal: Meal) {
        self.photo = meal.photo ?? ""
        self.photo2 = meal.photo2 ?? ""
        self.photo3 = meal.photo3 ?? ""
        super.init(eventItem: meal)
        // do this last because we've moved location up to NutEventItem
        if meal.location != nil {
            self.location = meal.location!
        }
    }

    //
    // MARK: - Overrides
    //

    override func deleteItem() -> Bool {
        // First delete any photos we have stored separately in the file system. Photos are associated with at most one Meal event, so if the meal event is deleted, the photo should also be deleted!
        // TODO: when we sync meal events with Tidepool service, we'll need to be able to delete these events on the service as well!
        return super.deleteItem()
    }
    
    override func copyChanges() {
        if let meal = eventItem as? Meal {
            meal.location = location
            meal.photo = photo
            meal.photo2 = photo2
            meal.photo3 = photo3
        }
        super.copyChanges()
    }
    
    override func changed() -> Bool {
        if let meal = eventItem as? Meal {
            let currentLocation = meal.location ?? ""
            if location != currentLocation {
                return true
            }
            var currentPhoto = meal.photo ?? ""
            if photo != currentPhoto {
                return true
            }
            currentPhoto = meal.photo2 ?? ""
            if photo2 != currentPhoto {
                return true
            }
            currentPhoto = meal.photo3 ?? ""
            if photo3 != currentPhoto {
                return true
            }
        }
        return super.changed()
    }
    
    override func firstPictureUrl() -> String {
        if let _ = eventItem as? Meal {
            if !photo.isEmpty {
                return photo
            }
            if !photo2.isEmpty {
                return photo2
            }
            if !photo3.isEmpty {
                return photo3
            }
        }
        return ""
    }
    
    override func photoUrlArray() -> [String] {
        var result: [String] = []
        if !photo.isEmpty {
            result.append(photo)
        }
        if !photo2.isEmpty {
            result.append(photo2)
        }
        if !photo3.isEmpty {
            result.append(photo3)
        }
        return result
    }

}
