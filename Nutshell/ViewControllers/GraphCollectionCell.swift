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
    // NEW ARCH
    var layout: GraphLayout?
    var dataSource: GraphDataSource?

    // BOTH
    private var graphView: GraphUIView?
    
    func updateViewSize() {
        //NSLog("GraphCollectionCell checkLayout frame \(self.frame.size)")
        if let graphView = graphView {
            graphView.updateViewSize(self.frame.size)
        }
    }
    
    // TODO: change centerTime to startTime!
    func configureCell(centerTime: NSDate, timeInterval: NSTimeInterval,                 mainEventTime: NSDate, maxBolus: CGFloat, maxBasal: CGFloat) -> Bool {

        //NSLog("GraphCollectionCell configure centerTime \(centerTime), timeInterval \(timeInterval), frame \(self.frame.size)")

        graphView?.removeFromSuperview()
        graphView = nil
        
        if let layout=layout, dataSource=dataSource {
            // NEW ARCH
            let startTime = NSDate(timeInterval: -timeInterval/2.0, sinceDate: centerTime)
            graphView = GraphUIView.init(frame: self.bounds, startTime: startTime, timeIntervalForView: timeInterval, layout: layout, dataSource: dataSource)
            if let graphView = graphView {
                graphView.configure()
                self.addSubview(graphView)
                return dataSource.dataFound()
            }
        } else {
            graphView = GraphUIView.init(frame: self.bounds, centerTime: centerTime, timeIntervalForView: timeInterval, timeOfMainEvent: mainEventTime)
            if let graphView = graphView {
                graphView.configure(maxBolus, maxBasal: maxBasal)
                self.addSubview(graphView)
                return graphView.dataFound()
            }
        }
        NSLog("ERROR: unable to create GraphUIView in \(__FUNCTION__)!")
        return false
    }
    
    func containsData() -> Bool {
        if let graphView = graphView {
            return graphView.dataFound()
        }
        return false
    }
    
}
