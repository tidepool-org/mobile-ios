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

class GraphCollectionCell: UICollectionViewCell {

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
    
    func configureCell(centerTime: NSDate, timeInterval: NSTimeInterval, mainEventTime: NSDate, maxBolus: CGFloat, maxBasal: CGFloat) -> Bool {
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
                graphView.configure(maxBolus, maxBasal: maxBasal)
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
