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

protocol GraphContainerViewDelegate {
    // Notify caller that a new cell has been loaded...
    func containerCellUpdated(dataDetected: Bool)
    func pinchZoomEnded()
}

class GraphContainerView: UIView {
    
    var eventItem: NutEventItem?
    var delegate: GraphContainerViewDelegate?
    // NEW ARCH
    var dataDelegate: GraphDataSource?
    var layout: GraphLayout?
    
    private var cellSize = CGSizeZero
    private var pinchStartCellSize = CGSizeZero
    private var pinchLocationInView = CGPointZero
    var dataDetected = false
    var graphCollectionView: UICollectionView?
    private var fixedBackgroundImageView: UIImageView?
    var graphCenterTime: NSDate = NSDate()
    var graphViewTimeInterval: NSTimeInterval = 0.0
    // variables for scaling by pixels/hour
    private var graphPixelsPerHour: CGFloat = 80
    private let kInitPixelsPerHour: CGFloat = 80
    private let kMinPixelsPerHour: CGFloat = 30
    private let kMaxPixelsPerHour: CGFloat = 300
    private let kDeltaPixelsPerHour: CGFloat = 10
    
    let graphCellsInCollection = 7
    private let graphCenterCellInCollection = 3
    
    func configureGraphForEvent(eventItem: NutEventItem) {
        self.eventItem = eventItem
        graphCenterTime = eventItem.time
        configureGraphViewIfNil()
    }
    
    func reloadData() {
        if let graphCollectionView = graphCollectionView, eventItem = eventItem {
            graphCenterTime = eventItem.time
            //NSLog("GraphContainerView reloading data")
            // max bolus/basal may have changed with new data, so need to refigure those!
            determineGraphObjectSizing()
            graphCollectionView.reloadData()
        }
    }
    
    func zoomInOut(zoomIn: Bool) {
        var size = self.cellSize
        
        if zoomIn {
            size.width = size.width * 1.25  // 5/4
        } else {
            size.width = size.width * 0.8   // 4/5
        }
        // Use middle of view as zoom spreading center
        zoomCellSize(size, xOffsetInView: (self.bounds.width)/2.0)
    }
    
    func canZoomIn() -> Bool {
        return self.cellSize.width < zoomInMaxCellWidth()
    }
    
    func canZoomOut() -> Bool {
        return self.cellSize.width > zoomOutMinCellWidth()
    }
    // Somewhat arbitrary max cell width
    private func zoomInMaxCellWidth() -> CGFloat {
        return min((4 * self.frame.width), 2000.0)
    }

    // Minimum cell width is more important: cells need to at least cover the view width
    private func zoomOutMinCellWidth() -> CGFloat {
        return self.frame.width / CGFloat(graphCellsInCollection)
    }

    private func redrawData() {
        if let graphCollectionView = graphCollectionView {
            for cell in graphCollectionView.visibleCells() {
                if let graphCell = cell as? GraphCollectionCell {
                    graphCell.updateViewSize()
                }
            }
        }
    }

    private func zoomCellSize(var size: CGSize, xOffsetInView: CGFloat) {

        // First check against limits, return if we are already there
        let maxWidth = zoomInMaxCellWidth()
        if size.width >= maxWidth {
            NSLog("Zoom in limit reached!")
            if size.width == maxWidth {
                return
            }
            size.width = maxWidth
        }
        let minWidth = zoomOutMinCellWidth()
        if size.width <= minWidth {
            NSLog("Zoom out limit reached!")
            if size.width == minWidth {
                return
            }
            size.width = minWidth
        }

        if let graphCollectionView = graphCollectionView {
            //NSLog("Zoom from cell size: \(self.cellSize) to \(size)")
            self.cellSize = size //  new cell sizing
            let ratioXOffset = xOffsetInView / self.bounds.width

            // Convert view xOffset for zoom center back for the new content view size so the point in the middle of our graph view doesn't change

            let contentOffsetToViewCenterZoom = graphCollectionView.contentOffset.x + xOffsetInView
            let timeOffsetToViewCenterZoom = self.viewXOffsetToTimeOffset(contentOffsetToViewCenterZoom)
            
            // Figure backwards with new overall content view sizing for xOffset to the same time offset as before...
            let newContentSizeWidth = size.width * CGFloat(graphCellsInCollection)
            let newContentOffsetToViewCenterZoom = CGFloat(timeOffsetToViewCenterZoom / self.graphViewTimeInterval) * newContentSizeWidth
            var targetOffsetX = newContentOffsetToViewCenterZoom - (ratioXOffset * self.bounds.width)
            
            // Don't let offset get below zero or less than a screen's width away from the right edge
             if targetOffsetX < 0.0 {
                targetOffsetX = 0.0
            }
            let maxOffsetX = newContentSizeWidth - self.bounds.width
            if targetOffsetX > maxOffsetX {
                targetOffsetX = maxOffsetX
            }
            let targetOffset = CGPoint(x: targetOffsetX, y: 0.0)
            
            let graphLayout = UICollectionViewFlowLayout()
            graphLayout.itemSize = size
            graphLayout.targetContentOffsetForProposedContentOffset(targetOffset)
            graphLayout.scrollDirection = UICollectionViewScrollDirection.Horizontal
            graphCollectionView.setCollectionViewLayout(graphLayout, animated: false)
            //NSLog("End content offset & size: \(graphCollectionView.contentOffset) & \(graphCollectionView.contentSize)")
            
            // Since we aren't changing the timeframe or time offset covered by each cell, we only need to have each visible cell redraw itself with its new sizing
            redrawData()
            graphCollectionView.setContentOffset(targetOffset, animated: false)
        }
    }
    
    func centerGraphOnEvent(animated: Bool = false) {
        if let graphCollectionView = graphCollectionView {
            graphCollectionView.scrollToItemAtIndexPath(NSIndexPath(forRow: graphCenterCellInCollection, inSection: 0), atScrollPosition: UICollectionViewScrollPosition.CenteredHorizontally, animated: animated)
        }
    }

    func containsData() -> Bool {
        return dataDetected
    }

    //
    // MARK: - Private methods
    //

    private func viewXOffsetToTimeOffset(viewXOffset: CGFloat) -> NSTimeInterval {
        let viewWidth = graphCollectionView!.contentSize.width
        return graphViewTimeInterval * NSTimeInterval(viewXOffset / viewWidth)
    }
    
    private func timeOffsetToViewXOffset(timeOffset: NSTimeInterval) -> CGFloat {
        let viewWidth = graphCollectionView!.contentSize.width
        return CGFloat(timeOffset / self.graphViewTimeInterval) * viewWidth
    }
    
    private func configureGraphPixelsTimeInterval(pixelsPerHour: CGFloat) {
        if pixelsPerHour > kMaxPixelsPerHour || pixelsPerHour < kMinPixelsPerHour {
            return
        }
        //NSLog("New pixels per hour: \(pixelsPerHour)")
        graphPixelsPerHour = pixelsPerHour
        graphViewTimeInterval = NSTimeInterval(self.bounds.width * 3600.0/graphPixelsPerHour)
    }
    
    //
    // MARK: - Graph view
    //
    
    private func deleteGraphView() {
        if (graphCollectionView != nil) {
            graphCollectionView?.removeFromSuperview();
            graphCollectionView = nil;
        }
    }
    
    private let collectCellReuseID = "graphViewCell"
    func configureGraphViewIfNil() {
        if graphCollectionView == nil {
            
            // first put in the fixed background
            if let fixedBackgroundImageView = fixedBackgroundImageView {
                fixedBackgroundImageView.removeFromSuperview()
            }
            
            if let layout=layout, dataDelegate=dataDelegate {
                // NEW ARCH
                let startTime = graphCenterTime.dateByAddingTimeInterval(-graphViewTimeInterval/2)
                let graphView = GraphUIView.init(frame: self.bounds, startTime: startTime, timeIntervalForView: graphViewTimeInterval, layout: layout, dataSource: dataDelegate)
                fixedBackgroundImageView = UIImageView(image: graphView.fixedBackgroundImage())
            } else {
                let graphView = GraphUIView.init(frame: self.bounds, centerTime: graphCenterTime, timeIntervalForView: graphViewTimeInterval, timeOfMainEvent: eventItem!.time)
                fixedBackgroundImageView = UIImageView(image: graphView.fixedBackgroundImage())
            }
            
            self.addSubview(fixedBackgroundImageView!)
            
            let graphLayout = UICollectionViewFlowLayout()
            self.cellSize = self.bounds.size
            graphLayout.itemSize = self.cellSize
            graphLayout.scrollDirection = UICollectionViewScrollDirection.Horizontal
            graphCollectionView = UICollectionView(frame: self.bounds, collectionViewLayout: graphLayout)
            if let graphCollectionView = graphCollectionView {
                graphCollectionView.backgroundColor = UIColor.clearColor()
                graphCollectionView.showsHorizontalScrollIndicator = false
                graphCollectionView.showsVerticalScrollIndicator = false
                graphCollectionView.dataSource = self
                graphCollectionView.delegate = self
                graphCollectionView.pagingEnabled = false
                //graphCollectionView.contentSize = self.bounds.size
                graphCollectionView.registerClass(GraphCollectionCell.self, forCellWithReuseIdentifier: collectCellReuseID)
                // event is in the center cell, see cellForItemAtIndexPath below...
                centerGraphOnEvent()
                self.addSubview(graphCollectionView)
                
                // add pinch gesture recognizer
                let recognizer = UIPinchGestureRecognizer(target: self, action: "pinchGestureHandler:")
                graphCollectionView.addGestureRecognizer(recognizer)
                
            }
            
            // Now that graph width is known, configure time span
            configureGraphPixelsTimeInterval(kInitPixelsPerHour)
            // Figure out the largest bolus and basal events
            determineGraphObjectSizing()
        }
    }
    
    func currentCellIndex(collectView: UICollectionView) -> NSIndexPath? {
        let centerPoint = collectView.center
        let pointInCell = CGPoint(x: centerPoint.x + collectView.contentOffset.x, y: centerPoint.y + collectView.contentOffset.y)
        return collectView.indexPathForItemAtPoint(pointInCell)
    }
    
    func centerTimeOfCellAtIndex(indexPath: NSIndexPath) -> NSDate {
        var cellCenterTime = graphCenterTime
        let collectionOffset = indexPath.row - graphCenterCellInCollection
        
        if collectionOffset != 0 {
            cellCenterTime = NSDate(timeInterval: graphViewTimeInterval*Double(collectionOffset), sinceDate: graphCenterTime)
        }
        return cellCenterTime
    }

    func pinchGestureHandler(sender: AnyObject) {
        //NSLog("recognized pinch!")
        if let gesture = sender as? UIPinchGestureRecognizer {
            if gesture.state == UIGestureRecognizerState.Began {
                //NSLog("gesture started: start cell size: \(cellSize)")
                pinchStartCellSize = cellSize
                pinchLocationInView = gesture.locationInView(self)
                return
            }
            if gesture.state == UIGestureRecognizerState.Changed {
                //NSLog("gesture state changed scale: \(gesture.scale)")
                var newCellSize = pinchStartCellSize
                newCellSize.width = newCellSize.width * CGFloat(gesture.scale)
                zoomCellSize(newCellSize, xOffsetInView: pinchLocationInView.x)
                delegate?.pinchZoomEnded()
                
                return
            }
            if gesture.state == UIGestureRecognizerState.Ended {
                //NSLog("gesture ended with scale: \(gesture.scale)")
                var newCellSize = pinchStartCellSize
                newCellSize.width = newCellSize.width * CGFloat(gesture.scale)
                zoomCellSize(newCellSize, xOffsetInView: pinchLocationInView.x)
                delegate?.pinchZoomEnded()
                return
            }
        }
    }

    //
    // MARK: - Data methods
    //
    
    private var maxBolus: CGFloat = 0.0
    private var maxBasal: CGFloat = 0.0
    // Scan Bolus and Basal events to determine max values; the graph scales bolus and basal to these max sizes, and because of boundary conditions between cells, this needs to be determined at the level of the entire graph, not just an individual cell
    // TODO: Find optimizations to avoid too many database queries. E.g., perhaps store min and max in block fetch data records and only query those blocks here. Or figure out how to cache this better, or share this lookup with that of the individual cells!
    private func determineGraphObjectSizing() {
        do {
            let boundsTimeIntervalFromCenter = graphViewTimeInterval * Double(graphCellsInCollection)/2.0
            let graphCollectStartTime = graphCenterTime.dateByAddingTimeInterval(-boundsTimeIntervalFromCenter)
            let graphCollectEndTime = graphCenterTime.dateByAddingTimeInterval(boundsTimeIntervalFromCenter)
            let events = try DatabaseUtils.getTidepoolEvents(graphCollectStartTime, thruTime: graphCollectEndTime, objectTypes: ["basal", "bolus"])
            
            //NSLog("\(events.count) basal and bolus events fetched to figure max values")
            maxBasal = 0.0
            maxBolus = 0.0
            for event in events {
                if let event = event as? CommonData {
                    if let type = event.type as? String {
                        switch type {
                        case "basal":
                            if let basalEvent = event as? Basal {
                                if let value = basalEvent.value {
                                    let floatValue = CGFloat(value)
                                    if floatValue > maxBasal {
                                        maxBasal = floatValue
                                    }
                                }
                            }
                        case "bolus":
                            if let bolusEvent = event as? Bolus {
                                if let value = bolusEvent.value {
                                    let floatValue = CGFloat(value)
                                    if floatValue > maxBolus {
                                        maxBolus = floatValue
                                    }
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }
            NSLog("Determined maxBolus:\(maxBolus), maxBasal:\(maxBasal)")
        } catch let error as NSError {
            print("Error: \(error)")
        }
        if maxBolus != 0.0 || maxBasal != 0.0 {
            dataDetected = true
        }
    }

}

//
// MARK: - UICollectionViewDataSource
//

extension GraphContainerView: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return graphCellsInCollection
    }
    
    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(collectCellReuseID, forIndexPath: indexPath) as! GraphCollectionCell

            //NSLog("GraphContainerView cellForItemAtIndexPath \(indexPath.row)")
            // index determines center time...
            let cellCenterTime = centerTimeOfCellAtIndex(indexPath)
            // NEW ARCHITECTURE
            if let dataDelegate = dataDelegate, layout = layout {
                // TODO: should get layout from graphDelegate? Or layout needs to be initialized with sizing later!
                cell.layout = layout
                cell.dataSource = dataDelegate
            }
            if cell.configureCell(cellCenterTime, timeInterval: graphViewTimeInterval, mainEventTime: eventItem!.time, maxBolus: maxBolus, maxBasal: maxBasal) {
                dataDetected = true
            }
            
            delegate?.containerCellUpdated(dataDetected)
            return cell
    }
}

//
// MARK: - UICollectionViewDelegateFlowLayout
//

extension GraphContainerView: UICollectionViewDelegateFlowLayout {
    
    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat
    {
        return 0.0
    }
}
