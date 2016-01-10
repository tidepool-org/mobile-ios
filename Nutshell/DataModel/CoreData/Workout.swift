//
//  Workout.swift
//  
//
//  Created by Larry Kenyon on 10/6/15.
//
//

import Foundation
import CoreData
import HealthKit


class Workout: EventItem {

// Insert code here to add functionality to your managed object subclass
    // override for eventItems that have location too!
    override func nutEventIdString() -> String {
        if let title = title {
            return "W" + title
        }
        return super.nutEventIdString()
    }

    // Convert Open mHealth enum to display string
    class func userStringForHKWorkoutActivityTypeEnumString(typeEnumString: String) -> String {
        
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
    class func enumStringForHKWorkoutActivityType(type: HKWorkoutActivityType) -> String {
        
        switch( type ){
        case HKWorkoutActivityType.AmericanFootball:
            return "HKWorkoutActivityTypeAmericanFootball"
        case HKWorkoutActivityType.Archery:
            return "HKWorkoutActivityTypeArchery"
        case HKWorkoutActivityType.AustralianFootball:
            return "HKWorkoutActivityTypeAustralianFootball"
        case HKWorkoutActivityType.Badminton:
            return "HKWorkoutActivityTypeBadminton"
        case HKWorkoutActivityType.Baseball:
            return "HKWorkoutActivityTypeBaseball"
        case HKWorkoutActivityType.Basketball:
            return "HKWorkoutActivityTypeBasketball"
        case HKWorkoutActivityType.Bowling:
            return "HKWorkoutActivityTypeBowling"
        case HKWorkoutActivityType.Boxing:
            return "HKWorkoutActivityTypeBoxing"
        case HKWorkoutActivityType.Climbing:
            return "HKWorkoutActivityTypeClimbing"
        case HKWorkoutActivityType.Cricket:
            return "HKWorkoutActivityTypeCricket"
        case HKWorkoutActivityType.CrossTraining:
            return "HKWorkoutActivityTypeCrossTraining"
        case HKWorkoutActivityType.Curling:
            return "HKWorkoutActivityTypeCurling"
        case HKWorkoutActivityType.Cycling:
            return "HKWorkoutActivityTypeCycling"
        case HKWorkoutActivityType.Dance:
            return "HKWorkoutActivityTypeDance"
        case HKWorkoutActivityType.DanceInspiredTraining:
            return "HKWorkoutActivityTypeDanceInspiredTraining"
        case HKWorkoutActivityType.Elliptical:
            return "HKWorkoutActivityTypeElliptical"
        case HKWorkoutActivityType.EquestrianSports:
            return "HKWorkoutActivityTypeEquestrianSports"
        case HKWorkoutActivityType.Fencing:
            return "HKWorkoutActivityTypeFencing"
        case HKWorkoutActivityType.Fishing:
            return "HKWorkoutActivityTypeFishing"
        case HKWorkoutActivityType.FunctionalStrengthTraining:
            return "HKWorkoutActivityTypeFunctionalStrengthTraining"
        case HKWorkoutActivityType.Golf:
            return "HKWorkoutActivityTypeGolf"
        case HKWorkoutActivityType.Gymnastics:
            return "HKWorkoutActivityTypeGymnastics"
        case HKWorkoutActivityType.Handball:
            return "HKWorkoutActivityTypeHandball"
        case HKWorkoutActivityType.Hiking:
            return "HKWorkoutActivityTypeHiking"
        case HKWorkoutActivityType.Hockey:
            return "HKWorkoutActivityTypeHockey"
        case HKWorkoutActivityType.Hunting:
            return "HKWorkoutActivityTypeHunting"
        case HKWorkoutActivityType.Lacrosse:
            return "HKWorkoutActivityTypeLacrosse"
        case HKWorkoutActivityType.MartialArts:
            return "HKWorkoutActivityTypeMartialArts"
        case HKWorkoutActivityType.MindAndBody:
            return "HKWorkoutActivityTypeMindAndBody"
        case HKWorkoutActivityType.MixedMetabolicCardioTraining:
            return "HKWorkoutActivityTypeMixedMetabolicCardioTraining"
        case HKWorkoutActivityType.PaddleSports:
            return "HKWorkoutActivityTypePaddleSports"
        case HKWorkoutActivityType.Play:
            return "HKWorkoutActivityTypePlay"
        case HKWorkoutActivityType.PreparationAndRecovery:
            return "HKWorkoutActivityTypePreparationAndRecovery"
        case HKWorkoutActivityType.Racquetball:
            return "HKWorkoutActivityTypeRacquetball"
        case HKWorkoutActivityType.Rowing:
            return "HKWorkoutActivityTypeRowing"
        case HKWorkoutActivityType.Rugby:
            return "HKWorkoutActivityTypeRugby"
        case HKWorkoutActivityType.Running:
            return "HKWorkoutActivityTypeRunning"
        case HKWorkoutActivityType.Sailing:
            return "HKWorkoutActivityTypeSailing"
        case HKWorkoutActivityType.SkatingSports:
            return "HKWorkoutActivityTypeSkatingSports"
        case HKWorkoutActivityType.SnowSports:
            return "HKWorkoutActivityTypeSnowSports"
        case HKWorkoutActivityType.Soccer:
            return "HKWorkoutActivityTypeSoccer"
        case HKWorkoutActivityType.Softball:
            return "HKWorkoutActivityTypeSoftball"
        case HKWorkoutActivityType.Squash:
            return "HKWorkoutActivityTypeSquash"
        case HKWorkoutActivityType.StairClimbing:
            return "HKWorkoutActivityTypeStairClimbing"
        case HKWorkoutActivityType.SurfingSports:
            return "HKWorkoutActivityTypeSurfingSports"
        case HKWorkoutActivityType.Swimming:
            return "HKWorkoutActivityTypeSwimming"
        case HKWorkoutActivityType.TableTennis:
            return "HKWorkoutActivityTypeTableTennis"
        case HKWorkoutActivityType.Tennis:
            return "HKWorkoutActivityTypeTennis"
        case HKWorkoutActivityType.TrackAndField:
            return "HKWorkoutActivityTypeTrackAndField"
        case HKWorkoutActivityType.TraditionalStrengthTraining:
            return "HKWorkoutActivityTypeTraditionalStrengthTraining"
        case HKWorkoutActivityType.Volleyball:
            return "HKWorkoutActivityTypeVolleyball"
        case HKWorkoutActivityType.Walking:
            return "HKWorkoutActivityTypeWalking"
        case HKWorkoutActivityType.WaterFitness:
            return "HKWorkoutActivityTypeWaterFitness"
        case HKWorkoutActivityType.WaterPolo:
            return "HKWorkoutActivityTypeWaterPolo"
        case HKWorkoutActivityType.WaterSports:
            return "HKWorkoutActivityTypeWaterSports"
        case HKWorkoutActivityType.Wrestling:
            return "HKWorkoutActivityTypeWrestling"
        case HKWorkoutActivityType.Yoga:
            return "HKWorkoutActivityTypeYoga"
        case HKWorkoutActivityType.Other:
            return "HKWorkoutActivityTypeOther"
//        default:
//            return "HKWorkoutActivityTypeOther"
        }
    }


}
