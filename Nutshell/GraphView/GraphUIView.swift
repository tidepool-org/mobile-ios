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
    private var viewTimeInterval = 0.0
    private var smgbData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var cbgData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var bolusData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    private var basalData: [(timeOffset: NSTimeInterval, value: NSNumber)] = []
    
    func configureTimeFrame(fromTime: NSDate, toTime: NSDate) {
        startTime = fromTime
        endTime = toTime
        viewTimeInterval = toTime.timeIntervalSinceDate(fromTime)
        // TODO: validate time interval is positive and reasonable
        
        self.loadDataForView()
    }
    
    func configureTimeFrame(centerTime: NSDate, timeIntervalForView: NSTimeInterval) {
        startTime = centerTime.dateByAddingTimeInterval(-timeIntervalForView/2)
        endTime = startTime?.dateByAddingTimeInterval(timeIntervalForView)
        viewTimeInterval = timeIntervalForView
        // TODO: validate time interval is positive and reasonable
        
        self.loadDataForView()
    }

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
                let events = try DatabaseUtils.getEvents(ad.managedObjectContext, fromTime: startTime, toTime: endTime)
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
