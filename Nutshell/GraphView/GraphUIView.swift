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

        // TODO: validate time interval is positive and reasonable
        self.startTime = centerTime.dateByAddingTimeInterval(-timeIntervalForView/2)
        self.endTime = startTime?.dateByAddingTimeInterval(timeIntervalForView)
        self.viewTimeInterval = CGFloat(timeIntervalForView)
        self.graphViews = GraphViews(viewSize: frame.size, timeIntervalForView: viewTimeInterval)
        
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
        return cbgData.count != 0 || bolusData.count != 0 || basalData.count != 0 || smgbData.count != 0
    }
    
    //
    // MARK: - Private data
    //

    private var graphViews: GraphViews
    private var startTime: NSDate?, endTime: NSDate?
    private var viewTimeInterval: CGFloat = 0.0
    private var smgbData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var cbgData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var bolusData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var basalData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var mealData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []

    //
    // MARK: - Private funcs
    //

    private func graphData() {
        // At this point data should be loaded, and we just need to plot the data
        // First generate the graph background
        
        let backgroundImage = graphViews.imageOfGraphBackground()
        let graphBackground = UIImageView(image: backgroundImage)
        addSubview(graphBackground)
        
        let cbgOverlayImage = graphViews.imageOfGlucoseData(cbgData)
        let cbgOverlay = UIImageView(image:cbgOverlayImage)
        addSubview(cbgOverlay)
                
        let workoutImage = graphViews.imageOfHealthEvent(60*60*1)
        // need to offset the middle of this view precisely at the time offset of the event
        // assume time start of 0, time width of the graph 6 hours, and time offset of 3 hours
        let pixelsPerSecond = self.frame.size.width/viewTimeInterval
        let eventOffsetTime: CGFloat = 3*60*60
        var eventOffsetPixels = pixelsPerSecond * eventOffsetTime
        // offset for width of the event bar: the middle of the bar is where the event line is!
        eventOffsetPixels = floor(eventOffsetPixels - 0.5 * workoutImage.size.width)
        
        let frame = CGRectMake(eventOffsetPixels, 0, workoutImage.size.width, workoutImage.size.height)
        let healthEvent = UIImageView(frame: frame)
        healthEvent.image = workoutImage
        self.addSubview(healthEvent)
    }

    //
    //            image = GraphViews.imageOfHealthEvent(0.15, graphSize:graphSectionView.frame.size)
    //            // need to offset the middle of this view precisely at the time offset of the event
    //            // assume time start of 0, time width of the graph 6 hours, and time offset of 3 hours
    //            let graphTotalSecs: CGFloat = 6*60*60
    //            let pixelsPerSecond = graphSectionView.frame.size.width/graphTotalSecs
    //            let eventOffsetTime: CGFloat = 3*60*60
    //            var eventOffsetPixels = pixelsPerSecond * eventOffsetTime
    //            // offset for width of the event bar: the middle of the bar is where the event line is!
    //            eventOffsetPixels = floor(eventOffsetPixels - 0.5 * image.size.width)
    //
    //            let frame = CGRectMake(eventOffsetPixels, 0, image.size.width, image.size.height)
    //            let healthEvent = UIImageView(frame: frame)
    //            healthEvent.image = image
    //            graphBackground?.addSubview(healthEvent)
    

    //
    // MARK: - Data query funcs
    //

    private func addSmbgEvent(event: SelfMonitoringGlucose, deltaTime: NSTimeInterval) {
        //print("Adding smbg event: \(event)")
        if let value = event.value {
            smgbData.append((timeOffset: deltaTime, value: value))
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

    private func addBasalEvent(event: Basal, deltaTime: NSTimeInterval) {
        //print("Adding Basal event: \(event)")
        if let value = event.value {
            basalData.append((timeOffset: deltaTime, value: value))
        } else {
            print("ignoring Basal event with nil value")
        }
    }

    private func loadDataForView() {
        // Reload all data, assuming time span has changed
        smgbData = []
        cbgData = []
        bolusData = []
        basalData = []
        
        if let startTime = startTime, endTime = endTime {
            let ad = UIApplication.sharedApplication().delegate as! AppDelegate
            do {
                let events = try DatabaseUtils.getEvents(ad.managedObjectContext,
                    fromTime: startTime, toTime: endTime, objectTypes: ["smbg", "bolus", "cbg", "basal"])
                    
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
                        case "cbg":
                            if let cbgEvent = event as? ContinuousGlucose {
                                addCbgEvent(cbgEvent, deltaTime: deltaTime)
                            }
                        case "basal":
                            if let basalEvent = event as? Basal {
                                addBasalEvent(basalEvent, deltaTime: deltaTime)
                            }
                        default: print("Ignoring event of type: \(event.type)")
                        }
                    }
                }
            } catch let error as NSError {
                print("Error: \(error)")
            }
            print("loaded \(smgbData.count) smgb events, \(cbgData.count) cbg events, \(bolusData.count) bolus events, and \(basalData.count) basal events")
        }
    }
}
