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

class TidepoolGraphView: GraphContainerView, GraphDataSource {
 
    // TODO: GraphContainerView should take a graphDataDelegate and a graphLayout instead!
    var tpLayout: TidepoolGraphLayout?

    override func configureGraphForEvent(eventItem: NutEventItem) {
        //super.configureGraphForEvent(eventItem)
        self.eventItem = eventItem
        self.graphCenterTime = eventItem.time
        self.dataDelegate = self
        self.layout = TidepoolGraphLayout(viewSize: self.frame.size)
        self.configureGraphViewIfNil()
    }

    override func reloadData() {
        if let graphCollectionView = graphCollectionView, eventItem = eventItem {
            graphCenterTime = eventItem.time
            //NSLog("GraphContainerView reloading data")
            // max bolus/basal may have changed with new data, so need to refigure those!
            //determineGraphObjectSizing()
            // TODO: make sure we don't call this when unnecessary!
            determineMaxBolusAndBasal()
            invalidateLoadCache()
            graphCollectionView.reloadData()
        }
    }
    
    /// GraphDataSource methods
    func loadDataItemsForLayer(layer: GraphDataLayer) -> Int {
        // Load all the types in anticipation they will all be needed...
        loadAllDataForTimeRange(layer.startTime, timeInterval: layer.timeIntervalForView)

        // Create the appropriate data layer based on type passed in...
        if let mealLayer = layer as? MealGraphDataLayer {
            mealLayer.dataArray = mealData
            return mealData.count
        }
        if let cbgLayer = layer as? CbgGraphDataLayer {
            cbgLayer.dataArray = cbgData
            return cbgData.count
        }
        if let smbgLayer = layer as? SmbgGraphDataLayer {
            smbgLayer.dataArray = smbgData
            return smbgData.count
        }
        if let basalLayer = layer as? BasalGraphDataLayer {
            basalLayer.dataArray = basalData
            basalLayer.maxBasal = maxBasal
            return basalData.count
        }
        if let bolusLayer = layer as? BolusGraphDataLayer {
            bolusLayer.dataArray = bolusData
            bolusLayer.maxBolus = maxBolus
            return bolusData.count
        }
        return 0;
    }
    
    func dataFound() -> Bool {
        // TODO!
        return false
    }
 
    private var maxBolus: CGFloat = 0.0
    private var maxBasal: CGFloat = 0.0

    private var smbgData: [SmbgGraphDataType] = []
    private var cbgData: [CbgGraphDataType] = []
    private var bolusData: [BolusGraphDataType] = []
    private var wizardData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var basalData: [BasalGraphDataType] = []
    private var workoutData: [(timeOffset: NSTimeInterval, duration: NSTimeInterval, mainEvent: Bool)] = []
    private var mealData: [MealGraphDataType] = []

    //
    // MARK: - Data query funcs
    //
    
    private func addSmbgEvent(event: SelfMonitoringGlucose, deltaTime: NSTimeInterval) {
        //NSLog("Adding smbg event: \(event)")
        if let value = event.value {
            let convertedValue = round(CGFloat(value) * kGlucoseConversionToMgDl)
            smbgData.append(SmbgGraphDataType(value: convertedValue, timeOffset: deltaTime))
        } else {
            NSLog("ignoring Smbg event with nil value")
        }
    }
    
    private let kGlucoseConversionToMgDl: CGFloat = 18.0
    private func addCbgEvent(event: ContinuousGlucose, deltaTime: NSTimeInterval) {
        //NSLog("Adding Cbg event: \(event)")
        if let value = event.value {
            let convertedValue = round(CGFloat(value) * kGlucoseConversionToMgDl)
            cbgData.append(CbgGraphDataType(value: convertedValue, timeOffset: deltaTime))
        } else {
            NSLog("ignoring Cbg event with nil value")
        }
    }
    
    private func addBolusEvent(event: Bolus, deltaTime: NSTimeInterval) {
        //NSLog("Adding Bolus event: \(event)")
        if event.value != nil {
            let bolus = BolusGraphDataType(event: event, deltaTime: deltaTime)
            bolusData.append(bolus)
            if bolus.value > maxBolus {
                maxBolus = bolus.value
            }
        } else {
            NSLog("ignoring Bolus event with nil value")
        }
    }
    
    private func addWizardEvent(event: Wizard, deltaTime: NSTimeInterval) {
        //NSLog("Adding Wizard event: \(event)")
        if let value = event.carbInput {
            if Float(value) != 0.0 {
                wizardData.append((timeOffset: deltaTime, value: value))
            } else {
                NSLog("ignoring Wizard event with carbInput value of zero!")
            }
            
        } else {
            NSLog("ignoring Wizard event with nil carbInput value!")
        }
    }
    
    private func addBasalEvent(event: Basal, deltaTime: NSTimeInterval) {
        //NSLog("Adding Basal event: \(event)")
        var value = event.value
        if value == nil {
            if let deliveryType = event.deliveryType {
                if deliveryType == "suspend" {
                    value = NSNumber(double: 0.0)
                }
            }
        }
        if value != nil {
            let floatValue = CGFloat(value!)
            var suppressed: CGFloat? = nil
            if event.percent != nil {
                suppressed = CGFloat(event.percent!)
            }
            basalData.append(BasalGraphDataType(value: floatValue, timeOffset: deltaTime, suppressed: suppressed))
            if floatValue > maxBasal {
                maxBasal = floatValue
            }
        } else {
            NSLog("ignoring Basal event with nil value")
        }
    }

    // Scan Bolus and Basal events to determine max values; the graph scales bolus and basal to these max sizes, and because of boundary conditions between cells, this needs to be determined at the level of the entire graph, not just an individual cell
    // TODO: Find optimizations to avoid too many database queries. E.g., perhaps store min and max in block fetch data records and only query those blocks here. Or figure out how to cache this better, or share this lookup with that of the individual cells!
    private func determineMaxBolusAndBasal() {
        do {
            let boundsTimeIntervalFromCenter = graphViewTimeInterval * Double(graphCellsInCollection)/2.0
            let graphCollectStartTime = graphCenterTime.dateByAddingTimeInterval(-boundsTimeIntervalFromCenter)
            let graphCollectEndTime = graphCenterTime.dateByAddingTimeInterval(boundsTimeIntervalFromCenter)
            let events = try DatabaseUtils.getTidepoolEvents(graphCollectStartTime, thruTime: graphCollectEndTime, objectTypes: ["basal", "bolus"])
            
            //NSLog("\(events.count) basal and bolus events fetched to figure max values")
            maxBasal = 0.0
            maxBolus = 0.0
            for event in events {
                if let event = event as? CommonData {
                    if let type = event.type as? String {
                        switch type {
                        case "basal":
                            if let basalEvent = event as? Basal {
                                if let value = basalEvent.value {
                                    let floatValue = CGFloat(value)
                                    if floatValue > maxBasal {
                                        maxBasal = floatValue
                                    }
                                }
                            }
                        case "bolus":
                            if let bolusEvent = event as? Bolus {
                                if let value = bolusEvent.value {
                                    let floatValue = CGFloat(value)
                                    if floatValue > maxBolus {
                                        maxBolus = floatValue
                                    }
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }
            NSLog("Determined maxBolus:\(maxBolus), maxBasal:\(maxBasal)")
        } catch let error as NSError {
            print("Error: \(error)")
        }
        if maxBolus != 0.0 || maxBasal != 0.0 {
            dataDetected = true
        }
    }
    
    private var curStartTime: NSDate?
    private var curTimeInterval: NSTimeInterval = 0.0
    
    private func invalidateLoadCache() {
        curStartTime = nil
        curTimeInterval = 0.0
    }
    
    private func loadAllDataForTimeRange(startTime: NSDate, timeInterval: NSTimeInterval) {
        
        if let curStartTime=curStartTime {
            if startTime == curStartTime && timeInterval == curTimeInterval {
                return // we already have the data...
            }
        }
        curStartTime = startTime
        curTimeInterval = timeInterval
        let endTime = startTime.dateByAddingTimeInterval(timeInterval)
        
        // Reload all data, assuming time span has changed
        smbgData = []
        cbgData = []
        bolusData = []
        basalData = []
        wizardData = []
        mealData = []
        workoutData = []
        
        // TODO: figure out a better time extension? One hour should pick up anything other than bolus extensions and workouts longer than 1 hour...
        let earlyStartTime = startTime.dateByAddingTimeInterval(-3600 /* -graphViews.timeExtensionForDataFetch*/)
        let lateEndTime = endTime.dateByAddingTimeInterval(3600 /* -graphViews.timeExtensionForDataFetch*/)
        
        do {
            let events = try DatabaseUtils.getTidepoolEvents(earlyStartTime, thruTime: lateEndTime, objectTypes: ["smbg", "bolus", "cbg", "wizard"])
            
            for event in events {
                if let event = event as? CommonData {
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
                        default: NSLog("Ignoring event of type: \(event.type)")
                            break
                        }
                    }
                }
            }
        } catch let error as NSError {
            NSLog("Error: \(error)")
        }
        
        // since basal events have a duration, use a different query to start earlier in time
        do {
            let earlyStartTime = startTime.dateByAddingTimeInterval(-60*60*12)
            let events = try DatabaseUtils.getTidepoolEvents(earlyStartTime, thruTime: endTime, objectTypes: ["basal"])
            
            for event in events {
                if let event = event as? CommonData {
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
            }
        } catch let error as NSError {
            NSLog("Error: \(error)")
        }
        
        // since meal events may be in a different store, make a separate call
        // TODO: clean this up, it is too tightly coupled!
        do {
            let events = try DatabaseUtils.getNutEvents(earlyStartTime, toTime: lateEndTime)
            
            for event in events {
                if let eventTime = event.time {
                    let deltaTime = eventTime.timeIntervalSinceDate(startTime)
                    switch event.type as! String {
                    case "meal":
                        if let mealEvent = event as? Meal {
                            let isMainEvent = mealEvent.time == self.eventItem?.time
                            mealData.append(MealGraphDataType(timeOffset: deltaTime, isMain: isMainEvent))
                        }
                    case "workout":
                        if let workoutEvent = event as? Workout {
                            let isMainEvent = workoutEvent.time == self.eventItem?.time
                            if let duration = workoutEvent.duration {
                                workoutData.append((timeOffset: deltaTime, duration: NSTimeInterval(duration), mainEvent: isMainEvent))
                            } else {
                                NSLog("ignoring Workout event with nil duration")
                            }
                        }
                    default: NSLog("Ignoring event of type: \(event.type)")
                        break
                    }
                }
            }
        } catch let error as NSError {
            NSLog("Error: \(error)")
        }
        
        NSLog("loaded \(smbgData.count) smbg events, \(cbgData.count) cbg events, \(bolusData.count) bolus events, \(basalData.count) basal events, \(wizardData.count) wizard events, \(mealData.count) meal events, \(workoutData.count) workout events")
    }

}
