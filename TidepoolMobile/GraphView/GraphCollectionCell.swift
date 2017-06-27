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

    var cellIndex: Int = 0
    var layout: GraphLayout?
    fileprivate var graphView: GraphUIView?
    
    func updateViewSize() {
        //NSLog("GraphCollectionCell \(cellIndex) updateViewSize frame \(self.frame.size)")
        if let graphView = graphView {
            graphView.updateViewSize(self.frame.size)
        }
    }
    
    func tappedAtPoint(_ point: CGPoint) -> GraphDataType? {
        if let graphView = graphView {
            return graphView.tappedAtPoint(point)
        }
        return nil
    }
    
    func updateCursorView(_ cursorTime: Date?, cursorColor: UIColor) {
        graphView?.updateCursorView(cursorTime, cursorColor: cursorColor)
    }
    
    func configureCell(_ startTime: Date, timeInterval: TimeInterval, cellIndex: Int) {

        //NSLog("GraphCollectionCell \(cellIndex) configure startTime \(startTime), timeInterval \(timeInterval), frame \(self.frame.size)")

        graphView?.removeFromSuperview()
        graphView = GraphUIView.init(frame: self.bounds, startTime: startTime, layout: layout!, tileIndex: cellIndex)
        if let graphView = graphView {
            graphView.configure()
            self.addSubview(graphView)
        }
    }
    
    
}
