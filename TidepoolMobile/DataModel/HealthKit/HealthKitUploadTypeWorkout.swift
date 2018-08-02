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
import CocoaLumberjack
import HealthKit

class HealthKitUploadTypeWorkout: HealthKitUploadType {
    init() {
        super.init("Workout")
    }

    internal override func hkSampleType() -> HKSampleType? {
        return HKSampleType.workoutType()
    }

    internal override func filterSamples(sortedSamples: [HKSample]) -> [HKSample] {
        DDLogVerbose("trace")
        // For workouts, don't filter anything out yet!
        return sortedSamples
    }
    
    // override!
    internal override func typeSpecificMetadata() -> [(metaKey: String, metadatum: AnyObject)] {
        DDLogVerbose("trace")
        let metadata: [(metaKey: String, metadatum: AnyObject)] = []
        return metadata
    }
    
    internal override func deviceModelForSourceBundleIdentifier(_ sourceBundleIdentifier: String) -> String {
        DDLogInfo("Unknown cbg sourceBundleIdentifier: \(sourceBundleIdentifier)")
        let deviceModel = "Unknown: \(sourceBundleIdentifier)"
        // Note: this will return something like HealthKit_Unknown: com.apple.Health_060EF7B3-9D86-4B93-9EE1-2FC6C618A4AD
        // TODO: figure out what workout apps might put here. Also, if we have com.apple.Health, and it is is user entered, this would be a direct user HK entry: what should we put?
        return "HealthKit_\(deviceModel)"
    }
    
    internal override func prepareDataForUpload(_ data: HealthKitUploadData) -> [[String: AnyObject]] {
        DDLogInfo("workout prepareDataForUpload")
        let dateFormatter = DateFormatter()
        var samplesToUploadDictArray = [[String: AnyObject]]()
        
        for sample in data.filteredSamples {
            if let workout = sample as? HKWorkout {
                
                var sampleToUploadDict = [String: AnyObject]()
                
                sampleToUploadDict["type"] = "physicalActivity" as AnyObject?
                sampleToUploadDict["deviceId"] = data.batchMetadata["deviceId"]
                sampleToUploadDict["time"] = dateFormatter.isoStringFromDate(sample.startDate, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime) as AnyObject?
                // Service wants a string if we specify "other", but HK doesn't provide the user a way to enter one...
                if workout.workoutActivityType != .other {
                    sampleToUploadDict["activityType"] = stringsForHKWorkoutActivityType(workout.workoutActivityType).tidepoolStr as AnyObject
                }
 
                // add optional application origin
                if let origin = sampleOrigin(sample) {
                    sampleToUploadDict["origin"] = origin as AnyObject
                }

                let duration = [
                    "units": "seconds",
                    "value": workout.duration
                    ] as [String : Any]
                sampleToUploadDict["duration"] = duration as AnyObject
                
                var miles: Double?
                if let totalDistance = workout.totalDistance?.doubleValue(for: HKUnit.mile()) {
                    miles = totalDistance
                    // Need to do the same validation as on the service!
                    if miles! > 0.0 && miles! < 100.0 {
                        let distance = [
                            "units": "miles",
                            "value": totalDistance
                            ] as [String : Any]
                        sampleToUploadDict["distance"] = distance as AnyObject
                    }
                }
                
                if let energyBurned = workout.totalEnergyBurned?.doubleValue(for: HKUnit.largeCalorie()) {
                    let energy = [
                        "units": "kilocalories",
                        "value": energyBurned
                    ] as [String : Any]
                    sampleToUploadDict["energy"] = energy as AnyObject
                }
                
                // Default name format: "Run - 4.2 miles"
                var name = self.stringsForHKWorkoutActivityType(workout.workoutActivityType).userStr
                if let miles = miles {
                    let floatMiles = Float(miles)
                    name = name + " - " + String(format: "%.2f",floatMiles) + " miles"
                }
                if !name.isEmpty {
                    sampleToUploadDict["name"] = name as AnyObject
                }
                
                // Add sample metadata payload props
                // TODO: figure out how to work around the exception when some instances of payload are converted to JSON!
//                if var metadata = sample.metadata {
//                    for (key, value) in metadata {
//                        if let dateValue = value as? Date {
//                            metadata[key] = dateFormatter.isoStringFromDate(dateValue, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
//                        }
//                        if let str = value as? String {
//                            metadata[key] = str.replacingOccurrences(of: "/", with: "-")
//                        }
//                    }
//
//                    // add any remaining metadata values as the payload struct
//                    if !metadata.isEmpty {
//                        sampleToUploadDict["payload"] = metadata as AnyObject?
//                    }
//                }
                // Add sample if valid...
                samplesToUploadDictArray.append(sampleToUploadDict)
            }
            
        }
        return samplesToUploadDictArray
    }

    // Convert HKWorkoutActivityType enum to (user string, Tidepool type string)
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
        //default:
        //    return ("Other Activity", "other")
        }
    }

}

