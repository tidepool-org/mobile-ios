/*
* Copyright (c) 2015, Tidepool Project
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

import UIKit

class GraphUIView: UIView {

    /// After init, call configure to create the graph.
    ///
    /// - parameter centerTime:
    ///   The time at the center of the X axis of the graph.
    ///
    /// - parameter timeIntervalForView:
    ///   The time span covered by the graph
    
    init(frame: CGRect, centerTime: NSDate, timeIntervalForView: NSTimeInterval) {

        self.startTime = centerTime.dateByAddingTimeInterval(-timeIntervalForView/2)
        self.endTime = startTime.dateByAddingTimeInterval(timeIntervalForView)
        self.viewTimeInterval = timeIntervalForView
        self.graphViews = GraphViews(viewSize: frame.size, timeIntervalForView: viewTimeInterval, startTime: startTime)
        
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Graph set up
    ///
    /// Queries the core database for relevant events in the specified timeframe, and creates the graph view with that data.
    
    func configure() {
        
        self.loadDataForView()
        self.graphData()
    }
    
    /// Check for data points in graph
    ///
    /// A graph with no data points will consist of the graph background (labeled axes) and any nut events in the timeframe
    ///
    /// - returns: True if there were any cpg, bolus, basal or smgb events in the time frame of the graph
    
    func dataFound() -> Bool {
        return cbgData.count != 0 || bolusData.count != 0 || basalData.count != 0 || smbgData.count != 0 || wizardData.count != 0
    }
    
    //
    // MARK: - Private data
    //
    
    var startTime: NSDate, endTime: NSDate
    var viewTimeInterval: NSTimeInterval = 0.0
    
    private var graphViews: GraphViews
    private var smbgData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var cbgData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var bolusData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var wizardData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var basalData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var workoutData: [(timeOffset: NSTimeInterval, duration: NSTimeInterval)] = []
    private var mealData: [NSTimeInterval] = []

    //
    // MARK: - Private funcs
    //

    private func graphData() {
        // At this point data should be loaded, and we just need to plot the data
        // First generate the graph background
        
        let backgroundImage = graphViews.imageOfGraphBackground()
        let graphBackground = UIImageView(image: backgroundImage)
        addSubview(graphBackground)
    
        if !dataFound() {
            return
        }
        
        if !workoutData.isEmpty {
            let overlayImage = graphViews.imageOfWorkoutData(workoutData)
            let overlay = UIImageView(image:overlayImage)
            addSubview(overlay)
        }

        if !mealData.isEmpty {
            let overlayImage = graphViews.imageOfMealData(mealData)
            let overlay = UIImageView(image:overlayImage)
            addSubview(overlay)
        }

        if !cbgData.isEmpty {
            let overlayImage = graphViews.imageOfCbgData(cbgData)
            let overlay = UIImageView(image:overlayImage)
            addSubview(overlay)
        }
 
        if !smbgData.isEmpty {
            let smbgOverlayImage = graphViews.imageOfSmbgData(smbgData)
            let overlay = UIImageView(image:smbgOverlayImage)
            addSubview(overlay)
        }
 
        if !wizardData.isEmpty {
            let overlayImage = graphViews.imageOfWizardData(wizardData)
            let overlay = UIImageView(image:overlayImage)
            addSubview(overlay)
        }

        if !bolusData.isEmpty {
            let overlayImage = graphViews.imageOfBolusData(bolusData)
            let overlay = UIImageView(image:overlayImage)
            addSubview(overlay)
        }

        if !basalData.isEmpty {
            let overlayImage = graphViews.imageOfBasalData(basalData)
            let overlay = UIImageView(image:overlayImage)
            addSubview(overlay)
        }

    }

    //
    // MARK: - Data query funcs
    //

    private func addSmbgEvent(event: SelfMonitoringGlucose, deltaTime: NSTimeInterval) {
        //print("Adding smbg event: \(event)")
        if let value = event.value {
            smbgData.append((timeOffset: deltaTime, value: value))
        } else {
            print("ignoring Smbg event with nil value")
        }
    }
    
    private func addCbgEvent(event: ContinuousGlucose, deltaTime: NSTimeInterval) {
        //print("Adding Cbg event: \(event)")
        if let value = event.value {
            cbgData.append((timeOffset: deltaTime, value: value))
        } else {
            print("ignoring Cbg event with nil value")
        }
    }

    private func addBolusEvent(event: Bolus, deltaTime: NSTimeInterval) {
        //print("Adding Bolus event: \(event)")
        if let value = event.value {
            bolusData.append((timeOffset: deltaTime, value: value))
        } else {
            print("ignoring Bolus event with nil value")
        }
    }

    private func addWizardEvent(event: Wizard, deltaTime: NSTimeInterval) {
        //print("Adding Wizard event: \(event)")
        if let value = event.carbInput {
            wizardData.append((timeOffset: deltaTime, value: value))
        } else {
            print("ignoring Wizard event with nil carbInput value!")
        }
    }

    private func addBasalEvent(event: Basal, deltaTime: NSTimeInterval) {
        //print("Adding Basal event: \(event)")
        if let value = event.value {
            basalData.append((timeOffset: deltaTime, value: value))
        } else {
            print("ignoring Basal event with nil value")
        }
    }

    private func addWorkoutEvent(event: Workout, deltaTime: NSTimeInterval) {
        //print("Adding Workout event: \(event)")
        if let duration = event.duration {
            workoutData.append((timeOffset: deltaTime, duration: NSTimeInterval(duration)))
        } else {
            print("ignoring Workout event with nil duration")
        }
    }

    private func loadDataForView() {
        // Reload all data, assuming time span has changed
        smbgData = []
        cbgData = []
        bolusData = []
        basalData = []
        wizardData = []
        mealData = []
        workoutData = []
        
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate
        do {
            let events = try DatabaseUtils.getEvents(ad.managedObjectContext,
            fromTime: startTime, toTime: endTime, objectTypes: ["smbg", "bolus", "cbg", "wizard", "meal", "workout"])
            
            print("\(events.count) events")
            for event in events {
                if let eventTime = event.time {
                    let deltaTime = eventTime.timeIntervalSinceDate(startTime)
                    switch event.type as! String {
                    case "smbg":
                        if let smbgEvent = event as? SelfMonitoringGlucose {
                            addSmbgEvent(smbgEvent, deltaTime: deltaTime)
                        }
                    case "bolus":
                        if let bolusEvent = event as? Bolus {
                            addBolusEvent(bolusEvent, deltaTime: deltaTime)
                        }
                    case "wizard":
                        if let wizardEvent = event as? Wizard {
                            addWizardEvent(wizardEvent, deltaTime: deltaTime)
                        }
                    case "cbg":
                        if let cbgEvent = event as? ContinuousGlucose {
                            addCbgEvent(cbgEvent, deltaTime: deltaTime)
                        }
                    case "meal":
                        if let _ = event as? Meal {
                            mealData.append(deltaTime)
                        }
                    case "workout":
                        if let workoutEvent = event as? Workout {
                            addWorkoutEvent(workoutEvent, deltaTime: deltaTime)
                        }
                    default: print("Ignoring event of type: \(event.type)")
                        break
                    }
                }
            }
        } catch let error as NSError {
            print("Error: \(error)")
        }
        
        // since basal events have a duration, use a different query to start earlier in time
        do {
            let earlyStartTime = startTime.dateByAddingTimeInterval(-60*60*12)
            let events = try DatabaseUtils.getEvents(ad.managedObjectContext,
                fromTime: earlyStartTime, toTime: endTime, objectTypes: ["basal"])
            
            print("\(events.count) events")
            for event in events {
                if let eventTime = event.time {
                    let deltaTime = eventTime.timeIntervalSinceDate(startTime)
                    switch event.type as! String {
                    case "basal":
                        if let basalEvent = event as? Basal {
                            addBasalEvent(basalEvent, deltaTime: deltaTime)
                        }
                    default:
                        break
                    }
                }
            }
        } catch let error as NSError {
            print("Error: \(error)")
        }

        print("loaded \(smbgData.count) smbg events, \(cbgData.count) cbg events, \(bolusData.count) bolus events, \(basalData.count) basal events, \(wizardData.count) wizard events, \(mealData.count) meal events, \(workoutData.count) workout events")
    }
}
