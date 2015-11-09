//
//  EventDetailGraphCollectionCell.swift
//  Nutshell
//
//  Created by Larry Kenyon on 10/1/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class EventDetailGraphCollectionCell: UICollectionViewCell {

    var graphView: GraphUIView?
    var graphTime: NSDate?
    var graphTimeInterval: NSTimeInterval?
    
    func configureCell(centerTime: NSDate, timeInterval: NSTimeInterval) -> Bool {
        print("size at configure: \(self.frame.size)")

        if (graphView != nil) {
            if (graphView!.frame.size != self.frame.size) || timeInterval != graphTimeInterval || centerTime != graphTime {
                graphView?.removeFromSuperview();
                graphView = nil;
            }
        }

        if (graphView == nil) {
            graphView = GraphUIView.init(frame: self.bounds, centerTime: centerTime, timeIntervalForView: timeInterval)
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
