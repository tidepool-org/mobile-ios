/*
 * Copyright (c) 2018, Tidepool Project
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
import HealthKit

class HealthKitUploadTypeWorkout: HealthKitUploadType {
    init() {
        super.init("Workout")
    }

    internal override func hkSampleType() -> HKSampleType? {
        return HKSampleType.workoutType()
    }

    private var kOneWeekInSeconds: TimeInterval = 1*60*60*24*7
    override func prepareDataForUpload(_ sample: HKSample) -> [String: AnyObject]? {
            if let workout = sample as? HKWorkout {
                var sampleToUploadDict = [String: AnyObject]()
                sampleToUploadDict["type"] = "physicalActivity" as AnyObject?
                // Add fields common to all types: guid, deviceId, time, and origin
                super.addCommonFields(sampleToUploadDict: &sampleToUploadDict, sample: sample)
 
                // service syntax for optional duration value: [float64; required; 0 <= x <= 1 week in appropriate units]
                if kDebugTurnOffSampleChecks || (workout.duration < kOneWeekInSeconds && workout.duration >= 0.0) {
                    let duration = [
                        "units": "seconds",
                        "value": workout.duration
                        ] as [String : Any]
                    sampleToUploadDict["duration"] = duration as AnyObject
                } else {
                    DDLogError("Workout sample with out-of-range duration: \(workout.duration) seconds, skipping duration field!")
                }
                
                var floatMiles: Float?
                if let totalDistance = workout.totalDistance {
                    let miles = totalDistance.doubleValue(for: HKUnit.mile())
                    floatMiles = Float(miles)
                    // service syntax for optional distance value: [float64; required; 0 <= x <= 100 miles in appropriate units]
                    if kDebugTurnOffSampleChecks || (miles >= 0.0 && miles <= 100.0) {
                        let distance = [
                            "units": "miles",
                            "value": miles
                            ] as [String : Any]
                        sampleToUploadDict["distance"] = distance as AnyObject
                    } else {
                        DDLogError("Workout sample with out-of-range distance: \(miles) miles, skipping distance field!")
                    }
                }
                
                if let energyBurned = workout.totalEnergyBurned?.doubleValue(for: HKUnit.largeCalorie()) {
                    // service syntax for optional energy value: [float64; required]. Also, between 0 and 10000
                    let kEnergyValueKilocaloriesMaximum = 10000.0
                    let kEnergyValueKilocaloriesMinimum = 0.0
                    if !kDebugTurnOffSampleChecks && (energyBurned < kEnergyValueKilocaloriesMinimum || energyBurned > kEnergyValueKilocaloriesMaximum)  {
                        DDLogError("Workout sample with out-of-range energy: \(energyBurned) kcal, skipping energy field!")
                    } else {
                        let energy = [
                            "units": "kilocalories",
                            "value": energyBurned
                            ] as [String : Any]
                        sampleToUploadDict["energy"] = energy as AnyObject
                    }
                }
                
                // Default name format: "Run - 4.2 miles"
                var name = self.stringsForHKWorkoutActivityType(workout.workoutActivityType).userStr
                if let floatMiles = floatMiles {
                    // service syntax for name: [string; optional; 0 < len <= 100]
                    name = name + " - " + String(format: "%.2f",floatMiles) + " miles"
                }
                if !name.isEmpty {
                    sampleToUploadDict["name"] = name as AnyObject
                }
                
                // Add sample metadata payload props
                if var metadata = sample.metadata {
                    addMetadata(&metadata, sampleToUploadDict: &sampleToUploadDict)
                }

                return(sampleToUploadDict)
            } else {
                return nil
        }
    }

    // Convert HKWorkoutActivityType enum to (user string, Tidepool type string)
    // Note: no default case, so this needs modification as HK adds or changes types.
    func stringsForHKWorkoutActivityType(_ type: HKWorkoutActivityType) -> (userStr: String, tidepoolStr: String) {
        
        switch( type ){
        case .americanFootball:
            return ("Football", "americanFootball")
        case .archery:
            return ("Archery", "archery")
        case .australianFootball:
            return ("Australian Football", "australianFootball")
        case .badminton:
            return ("Badminton", "badminton")
        case .barre:
            return ("Barre", "barre")
        case .baseball:
            return ("Baseball", "baseball")
        case .basketball:
            return ("Basketball", "basketball")
        case .bowling:
            return ("Bowling", "bowling")
        case .boxing:
            return ("Boxing", "boxing")
        case .climbing:
            return ("Climbing", "climbing")
        case .coreTraining:
            return ("Core Training", "coreTraining")
        case .cricket:
            return ("Cricket", "cricket")
        case .crossCountrySkiing:
            return ("Cross Country Skiiing", "crossCountrySkiing")
        case .crossTraining:
            return ("Cross Training", "crossTraining")
        case .curling:
            return ("Curling", "curling")
        case .cycling:
            return ("Cycling", "cycling")
        case .dance:
            return ("Dance", "dance")
        case .danceInspiredTraining:
            return ("DanceInspiredTraining", "danceInspiredTraining")
        case .downhillSkiing:
            return ("Downhill Skiing", "downhillSkiing")
        case .elliptical:
            return ("Elliptical", "elliptical")
        case .equestrianSports:
            return ("Equestrian Sports", "equestrianSports")
        case .fencing:
            return ("Fencing", "fencing")
        case .fishing:
            return ("Fishing", "fishing")
        case .flexibility:
            return ("Flexibility", "flexibility")
        case .functionalStrengthTraining:
            return ("Functional Strength Training", "functionalStrengthTraining")
        case .golf:
            return ("Golf", "golf")
        case .gymnastics:
            return ("Gymnastics", "gymnastics")
        case .handball:
            return ("Handball", "handball")
        case .handCycling:
            return ("Hand Cycling", "handCycling")
        case .highIntensityIntervalTraining:
            return ("High Intensity Interval Training", "highIntensityIntervalTraining")
        case .hiking:
            return ("Hiking", "hiking")
        case .hockey:
            return ("Hockey", "hockey")
        case .hunting:
            return ("Hunting", "hunting")
        case .jumpRope:
            return ("Jump Rope", "jumpRope")
        case .kickboxing:
            return ("Kick Boxing", "kickboxing")
        case .lacrosse:
            return ("Lacrosse", "lacrosse")
        case .martialArts:
            return ("Martial Arts", "martialArts")
        case .mindAndBody:
            return ("Mind And Body", "mindAndBody")
        case .mixedCardio:
            return ("Mixed Cardio", "mixedCardio")
        case .mixedMetabolicCardioTraining:
            return ("Mixed Metabolic Cardio Training", "mixedMetabolicCardioTraining")
        case .other:
            return ("Other Activity", "other")
        case .paddleSports:
            return ("PaddleSports", "paddleSports")
        case .pilates:
            return ("Pilates", "pilates")
        case .play:
            return ("Play", "play")
        case .preparationAndRecovery:
            return ("Preparation And Recovery", "preparationAndRecovery")
        case .racquetball:
            return ("Racquetball", "racquetball")
        case .rowing:
            return ("Rowing", "rowing")
        case .rugby:
            return ("Rugby", "rugby")
        case .running:
            return ("Running", "running")
        case .sailing:
            return ("Sailing", "sailing")
        case .skatingSports:
            return ("Skating Sports", "skatingSports")
        case .snowboarding:
            return ("Snowboarding", "snowboarding")
        case .snowSports:
            return ("Snow Sports", "snowSports")
        case .soccer:
            return ("Soccer", "soccer")
        case .softball:
            return ("Softball", "softball")
        case .squash:
            return ("Squash", "squash")
        case .stairClimbing:
            return ("StairClimbing", "stairClimbing")
        case .stairs:
            return ("Stairs", "stairs")
        case .stepTraining:
            return ("Step Training", "stepTraining")
        case .surfingSports:
            return ("Surfing Sports", "surfingSports")
        case .swimming:
            return ("Swimming", "swimming")
        case .tableTennis:
            return ("Table Tennis", "tableTennis")
        case .taiChi:
            return ("Tai Chi", "taiChi")
        case .tennis:
            return ("Tennis", "tennis")
        case .trackAndField:
            return ("TrackAndField", "trackAndField")
        case .traditionalStrengthTraining:
            return ("Traditional Strength Training", "traditionalStrengthTraining")
        case .volleyball:
            return ("Volleyball", "volleyball")
        case .walking:
            return ("Walking", "walking")
        case .waterFitness:
            return ("Water Fitness", "waterFitness")
        case .waterPolo:
            return ("Water Polo", "waterPolo")
        case .waterSports:
            return ("Water Sports", "waterSports")
        case .wheelchairWalkPace:
            return ("Wheelchair Walk Pace", "wheelchairWalkPace")
        case .wheelchairRunPace:
            return ("Wheelchair Run Pace", "wheelchairRunPace")
        case .wrestling:
            return ("Wrestling", "wrestling")
        case .yoga:
            return ("Yoga", "yoga")
        default:
            return ("Other Activity", "other")
        }
    }

}

