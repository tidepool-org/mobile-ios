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

class TidepoolGraphView: GraphContainerView {
 
    fileprivate var tidepoolLayout: TidepoolGraphLayout!

    init(frame: CGRect, delegate: GraphContainerViewDelegate?, mainEventTime: Date, tzOffsetSecs: Int, lowBGBounds: Int? = nil, highBGBounds: Int? = nil) {
        let layout = TidepoolGraphLayout(viewSize: frame.size, mainEventTime: mainEventTime, tzOffsetSecs: tzOffsetSecs)
        layout.setLowAndHighBGBounds(low: lowBGBounds, high: highBGBounds)
        super.init(frame: frame, delegate: delegate, layout: layout)
        tidepoolLayout = layout
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadGraphData() {
        // TODO: make sure we don't call this when unnecessary!
        //NSLog("TidepoolGraphView reloading data")
        tidepoolLayout.invalidateCaches()
        super.loadGraphData()
    }
   
    // Note: when data is not displayed, it will also not be loaded. Display true is the default, so this is generally only called when data layer suppression is desired (typically to show other overlays)
    func displayGraphData(_ display: Bool) {
        if display != tidepoolLayout.showDataLayers {
            tidepoolLayout.showDataLayers = display
            loadGraphData()
        } else {
            NSLog("\(#function) display: already in state \(display)")
        }
    }
    
    // This can be called to randomly show/hide gridlines
    func displayGridLines(_ display: Bool) {
        if display != tidepoolLayout.displayGridLines {
            tidepoolLayout.displayGridLines = display
            tidepoolLayout.configureGraph()
            configureBackground()
        } else {
            NSLog("\(#function) display: already in state \(display)")
        }
    }
    
    func configureNotesToDisplay(_ notes: [BlipNote]) {
        tidepoolLayout.notesToDisplay = notes
    }
    
    func dataFound() -> Bool {
        return tidepoolLayout.dataDetected
    }
    
}
