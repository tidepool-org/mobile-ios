//
//  EventDetailGraphCollectionCell.swift
//  Nutshell
//
//  Created by Larry Kenyon on 10/1/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class EventDetailGraphCollectionCell: UICollectionViewCell {

    private var graphView: GraphUIView?
    var graphTime: NSDate?
    private var graphTimeInterval: NSTimeInterval?
    private var graphZoomed: Bool = false
    
    func zoomXAxisToNewTime(centerTime: NSDate, timeInterval: NSTimeInterval) {
        if let graphView = graphView {
            graphTime = centerTime
            graphTimeInterval = timeInterval
            graphView.zoomXAxisToNewTime(centerTime, timeIntervalForView: timeInterval)
            graphZoomed = true
        }
    }
    
    func configureCell(centerTime: NSDate, timeInterval: NSTimeInterval, mainEventTime: NSDate) -> Bool {
        print("size at configure: \(self.frame.size)")

        if (graphView != nil) {
//            if (graphView!.frame.size != self.frame.size) || timeInterval != graphTimeInterval || centerTime != graphTime || graphZoomed {
                graphView?.removeFromSuperview();
                graphView = nil;
                graphZoomed = false
//            }
        }

        if (graphView == nil) {
            graphView = GraphUIView.init(frame: self.bounds, centerTime: centerTime, timeIntervalForView: timeInterval, timeOfMainEvent: mainEventTime)
            if let graphView = graphView {
                graphTime = centerTime
                graphTimeInterval = timeInterval
                graphView.configure()
                self.addSubview(graphView)
                return graphView.dataFound()
            } else {
                return false
            }
        } else {
            print("skipping redo of graph at size: \(self.frame.size), time: \(graphTime)")
            return graphView!.dataFound()
        }
    }
    
}
