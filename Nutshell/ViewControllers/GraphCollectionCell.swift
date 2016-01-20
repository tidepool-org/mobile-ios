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

    var cellDebugId = ""
    var layout: GraphLayout?
    private var graphView: GraphUIView?
    
    func updateViewSize() {
        NSLog("GraphCollectionCell \(cellDebugId) updateViewSize frame \(self.frame.size)")
        if let graphView = graphView {
            graphView.updateViewSize(self.frame.size)
        }
    }
    
    func tappedAtPoint(point: CGPoint) -> GraphDataType? {
        if let graphView = graphView {
            return graphView.tappedAtPoint(point)
        }
        return nil
    }
    
    func configureCell(startTime: NSDate, timeInterval: NSTimeInterval) {

        //NSLog("GraphCollectionCell \(cellDebugId) configure centerTime \(centerTime), timeInterval \(timeInterval), frame \(self.frame.size)")

        graphView?.removeFromSuperview()
        graphView = GraphUIView.init(frame: self.bounds, startTime: startTime, layout: layout!)
        if let graphView = graphView {
            graphView.configure()
            self.addSubview(graphView)
        }
    }
    
    
}
