//
//  GraphUIView.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/19/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class GraphUIView: UIView {

    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */

    private var startTime: NSDate?, endTime: NSDate?
    private var viewTimeInterval: CGFloat = 0.0
    private var smgbData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var cbgData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var bolusData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var basalData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var mealData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []

    func dataFound() -> Bool {
        return cbgData.count != 0 || bolusData.count != 0 || basalData.count != 0 || smgbData.count != 0
    }
    
    func configureTimeFrame(fromTime: NSDate, toTime: NSDate) {
        startTime = fromTime
        endTime = toTime
        viewTimeInterval = CGFloat(toTime.timeIntervalSinceDate(fromTime))
    
        // TODO: validate time interval is positive and reasonable
        
        self.loadDataForView()
        self.graphData()
    }

    func configureTimeFrame(centerTime: NSDate, timeIntervalForView: NSTimeInterval) {
        startTime = centerTime.dateByAddingTimeInterval(-timeIntervalForView/2)
        endTime = startTime?.dateByAddingTimeInterval(timeIntervalForView)
        viewTimeInterval = CGFloat(timeIntervalForView)
        // TODO: validate time interval is positive and reasonable
        
        self.loadDataForView()
        self.graphData()
    }

    private func graphData() {
        // At this point data should be loaded, and we just need to plot the data
        // First generate the graph background
        
            let backgroundImage = GraphViews.imageOfGraphBackground(viewSize: self.frame.size)
            let graphBackground = UIImageView(image: backgroundImage)
            addSubview(graphBackground)
        
            let workoutImage = GraphViews.imageOfHealthEvent(0.15, graphSize:self.frame.size)
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
