/*
 * Copyright (c) 2019, Tidepool Project
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the associated License, which is identical to the BSD 2-Clause
 * License as published by the Open Source Initiative at opensource.org.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the License for more details.
 *
 * You should have received a copy of the License along with this program; if
 * not, you can obtain one from Tidepool Project at tidepool.org.
 */

import Foundation
import CoreData
import HealthKit


class Workout: EventItem {

// Insert code here to add functionality to your managed object subclass

    // Convert Open mHealth enum to display string
    class func userStringForHKWorkoutActivityTypeEnumString(_ typeEnumString: String) -> String {
        
        switch (typeEnumString) {
        case "HKWorkoutActivityTypeAmericanFootball":
            return "Football"
        case "HKWorkoutActivityTypeArchery":
            return "Archery"
        case "HKWorkoutActivityTypeAustralianFootball":
            return "Australian Football"
        case "HKWorkoutActivityTypeBadminton":
            return "Badminton"
        case "HKWorkoutActivityTypeBaseball":
            return "Baseball"
        case "HKWorkoutActivityTypeBasketball":
            return "Basketball"
        case "HKWorkoutActivityTypeBowling":
            return "Bowling"
        case "HKWorkoutActivityTypeBoxing":
            return "Boxing"
        case "HKWorkoutActivityTypeClimbing":
            return "Climbing"
        case "HKWorkoutActivityTypeCricket":
            return "Cricket"
        case "HKWorkoutActivityTypeCrossTraining":
            return "CrossTraining"
        case "HKWorkoutActivityTypeCurling":
            return "Curling"
        case "HKWorkoutActivityTypeCycling":
            return "Cycling"
        case "HKWorkoutActivityTypeDance":
            return "Dance"
        case "HKWorkoutActivityTypeDanceInspiredTraining":
            return "Dance Inspired Training"
        case "HKWorkoutActivityTypeElliptical":
            return "Elliptical"
        case "HKWorkoutActivityTypeEquestrianSports":
            return "Equestrian Sports"
        case "HKWorkoutActivityTypeFencing":
            return "Fencing"
        case "HKWorkoutActivityTypeFishing":
            return "Fishing"
        case "HKWorkoutActivityTypeFunctionalStrengthTraining":
            return "Functional Strength Training"
        case "HKWorkoutActivityTypeGolf":
            return "Golf"
        case "HKWorkoutActivityTypeGymnastics":
            return "Gymnastics"
        case "HKWorkoutActivityTypeHandball":
            return "Handball"
        case "HKWorkoutActivityTypeHiking":
            return "Hiking"
        case "HKWorkoutActivityTypeHockey":
            return "Hockey"
        case "HKWorkoutActivityTypeHunting":
            return "Hunting"
        case "HKWorkoutActivityTypeLacrosse":
            return "Lacrosse"
        case "HKWorkoutActivityTypeMartialArts":
            return "Martial Arts"
        case "HKWorkoutActivityTypeMindAndBody":
            return "Mind and Body"
        case "HKWorkoutActivityTypeMixedMetabolicCardioTraining":
            return "Mixed Metabolic Cardio Training"
        case "HKWorkoutActivityTypePaddleSports":
            return "Paddle Sports"
        case "HKWorkoutActivityTypePlay":
            return "Play"
        case "HKWorkoutActivityTypePreparationAndRecovery":
            return "Preparation and Recovery"
        case "HKWorkoutActivityTypeRacquetball":
            return "Racquetball"
        case "HKWorkoutActivityTypeRowing":
            return "Rowing"
        case "HKWorkoutActivityTypeRugby":
            return "Rugby"
        case "HKWorkoutActivityTypeRunning":
            return "Running"
        case "HKWorkoutActivityTypeSailing":
            return "Sailing"
        case "HKWorkoutActivityTypeSkatingSports":
            return "Skating Sports"
        case "HKWorkoutActivityTypeSnowSports":
            return "Snow Sports"
        case "HKWorkoutActivityTypeSoccer":
            return "Soccer"
        case "HKWorkoutActivityTypeSoftball":
            return "Softball"
        case "HKWorkoutActivityTypeSquash":
            return "Squash"
        case "HKWorkoutActivityTypeStairClimbing":
            return "Stair Climbing"
        case "HKWorkoutActivityTypeSurfingSports":
            return "Surfing Sports"
        case "HKWorkoutActivityTypeSwimming":
            return "Swimming"
        case "HKWorkoutActivityTypeTableTennis":
            return "Table Tennis"
        case "HKWorkoutActivityTypeTennis":
            return "Tennis"
        case "HKWorkoutActivityTypeTrackAndField":
            return "Track and Field"
        case "HKWorkoutActivityTypeTraditionalStrengthTraining":
            return "Traditional Strength Training"
        case "HKWorkoutActivityTypeVolleyball":
            return "Volleyball"
        case "HKWorkoutActivityTypeWalking":
            return "Walking"
        case "HKWorkoutActivityTypeWaterFitness":
            return "WaterFitness"
        case "HKWorkoutActivityTypeWaterPolo":
            return "WaterPolo"
        case "HKWorkoutActivityTypeWaterSports":
            return "WaterSports"
        case "HKWorkoutActivityTypeWrestling":
            return "Wrestling"
        case "HKWorkoutActivityTypeYoga":
            return "Yoga"
        case "HKWorkoutActivityTypeOther":
            return "Workout"
        default:
            return "Workout"
        }
    }

    // Convert HKWorkoutActivityType enum to Open mHealth enum string...
    class func enumStringForHKWorkoutActivityType(_ type: HKWorkoutActivityType) -> String {
        
        switch( type ){
        case HKWorkoutActivityType.americanFootball:
            return "HKWorkoutActivityTypeAmericanFootball"
        case HKWorkoutActivityType.archery:
            return "HKWorkoutActivityTypeArchery"
        case HKWorkoutActivityType.australianFootball:
            return "HKWorkoutActivityTypeAustralianFootball"
        case HKWorkoutActivityType.badminton:
            return "HKWorkoutActivityTypeBadminton"
        case HKWorkoutActivityType.baseball:
            return "HKWorkoutActivityTypeBaseball"
        case HKWorkoutActivityType.basketball:
            return "HKWorkoutActivityTypeBasketball"
        case HKWorkoutActivityType.bowling:
            return "HKWorkoutActivityTypeBowling"
        case HKWorkoutActivityType.boxing:
            return "HKWorkoutActivityTypeBoxing"
        case HKWorkoutActivityType.climbing:
            return "HKWorkoutActivityTypeClimbing"
        case HKWorkoutActivityType.cricket:
            return "HKWorkoutActivityTypeCricket"
        case HKWorkoutActivityType.crossTraining:
            return "HKWorkoutActivityTypeCrossTraining"
        case HKWorkoutActivityType.curling:
            return "HKWorkoutActivityTypeCurling"
        case HKWorkoutActivityType.cycling:
            return "HKWorkoutActivityTypeCycling"
        case HKWorkoutActivityType.dance:
            return "HKWorkoutActivityTypeDance"
        case HKWorkoutActivityType.danceInspiredTraining:
            return "HKWorkoutActivityTypeDanceInspiredTraining"
        case HKWorkoutActivityType.elliptical:
            return "HKWorkoutActivityTypeElliptical"
        case HKWorkoutActivityType.equestrianSports:
            return "HKWorkoutActivityTypeEquestrianSports"
        case HKWorkoutActivityType.fencing:
            return "HKWorkoutActivityTypeFencing"
        case HKWorkoutActivityType.fishing:
            return "HKWorkoutActivityTypeFishing"
        case HKWorkoutActivityType.functionalStrengthTraining:
            return "HKWorkoutActivityTypeFunctionalStrengthTraining"
        case HKWorkoutActivityType.golf:
            return "HKWorkoutActivityTypeGolf"
        case HKWorkoutActivityType.gymnastics:
            return "HKWorkoutActivityTypeGymnastics"
        case HKWorkoutActivityType.handball:
            return "HKWorkoutActivityTypeHandball"
        case HKWorkoutActivityType.hiking:
            return "HKWorkoutActivityTypeHiking"
        case HKWorkoutActivityType.hockey:
            return "HKWorkoutActivityTypeHockey"
        case HKWorkoutActivityType.hunting:
            return "HKWorkoutActivityTypeHunting"
        case HKWorkoutActivityType.lacrosse:
            return "HKWorkoutActivityTypeLacrosse"
        case HKWorkoutActivityType.martialArts:
            return "HKWorkoutActivityTypeMartialArts"
        case HKWorkoutActivityType.mindAndBody:
            return "HKWorkoutActivityTypeMindAndBody"
        case HKWorkoutActivityType.mixedMetabolicCardioTraining:
            return "HKWorkoutActivityTypeMixedMetabolicCardioTraining"
        case HKWorkoutActivityType.paddleSports:
            return "HKWorkoutActivityTypePaddleSports"
        case HKWorkoutActivityType.play:
            return "HKWorkoutActivityTypePlay"
        case HKWorkoutActivityType.preparationAndRecovery:
            return "HKWorkoutActivityTypePreparationAndRecovery"
        case HKWorkoutActivityType.racquetball:
            return "HKWorkoutActivityTypeRacquetball"
        case HKWorkoutActivityType.rowing:
            return "HKWorkoutActivityTypeRowing"
        case HKWorkoutActivityType.rugby:
            return "HKWorkoutActivityTypeRugby"
        case HKWorkoutActivityType.running:
            return "HKWorkoutActivityTypeRunning"
        case HKWorkoutActivityType.sailing:
            return "HKWorkoutActivityTypeSailing"
        case HKWorkoutActivityType.skatingSports:
            return "HKWorkoutActivityTypeSkatingSports"
        case HKWorkoutActivityType.snowSports:
            return "HKWorkoutActivityTypeSnowSports"
        case HKWorkoutActivityType.soccer:
            return "HKWorkoutActivityTypeSoccer"
        case HKWorkoutActivityType.softball:
            return "HKWorkoutActivityTypeSoftball"
        case HKWorkoutActivityType.squash:
            return "HKWorkoutActivityTypeSquash"
        case HKWorkoutActivityType.stairClimbing:
            return "HKWorkoutActivityTypeStairClimbing"
        case HKWorkoutActivityType.surfingSports:
            return "HKWorkoutActivityTypeSurfingSports"
        case HKWorkoutActivityType.swimming:
            return "HKWorkoutActivityTypeSwimming"
        case HKWorkoutActivityType.tableTennis:
            return "HKWorkoutActivityTypeTableTennis"
        case HKWorkoutActivityType.tennis:
            return "HKWorkoutActivityTypeTennis"
        case HKWorkoutActivityType.trackAndField:
            return "HKWorkoutActivityTypeTrackAndField"
        case HKWorkoutActivityType.traditionalStrengthTraining:
            return "HKWorkoutActivityTypeTraditionalStrengthTraining"
        case HKWorkoutActivityType.volleyball:
            return "HKWorkoutActivityTypeVolleyball"
        case HKWorkoutActivityType.walking:
            return "HKWorkoutActivityTypeWalking"
        case HKWorkoutActivityType.waterFitness:
            return "HKWorkoutActivityTypeWaterFitness"
        case HKWorkoutActivityType.waterPolo:
            return "HKWorkoutActivityTypeWaterPolo"
        case HKWorkoutActivityType.waterSports:
            return "HKWorkoutActivityTypeWaterSports"
        case HKWorkoutActivityType.wrestling:
            return "HKWorkoutActivityTypeWrestling"
        case HKWorkoutActivityType.yoga:
            return "HKWorkoutActivityTypeYoga"
        case HKWorkoutActivityType.other:
            return "HKWorkoutActivityTypeOther"
        // TODO: add new iOS 10 activities
        default:
            return "HKWorkoutActivityTypeOther"
        }
    }


}
