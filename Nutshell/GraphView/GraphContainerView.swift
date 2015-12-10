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
}

class GraphContainerView: UIView {
    
    var eventItem: NutEventItem?
    var delegate: GraphContainerViewDelegate?
    
    private var cellSize = CGSizeZero
    private var dataDetected = false
    private var graphCollectionView: UICollectionView?
    private var fixedBackgroundImageView: UIImageView?
    private var graphCenterTime: NSDate = NSDate()
    private var graphViewTimeInterval: NSTimeInterval = 0.0
    // variables for scaling by pixels/hour
    private var graphPixelsPerHour: CGFloat = 80
    private let kInitPixelsPerHour: CGFloat = 80
    private let kMinPixelsPerHour: CGFloat = 30
    private let kMaxPixelsPerHour: CGFloat = 300
    private let kDeltaPixelsPerHour: CGFloat = 10
    
    private let graphCellsInCollection = 7
    private let graphCenterCellInCollection = 3
    
    func configureGraphForEvent(eventItem: NutEventItem) {
        self.eventItem = eventItem
        graphCenterTime = eventItem.time
        configureGraphViewIfNil()
    }
    
    func reloadData() {
        if let graphCollectionView = graphCollectionView, eventItem = eventItem {
            graphCenterTime = eventItem.time
            NSLog("GraphContainerView reloading data")
            graphCollectionView.reloadData()
        }
    }
    
    func redrawData() {
        if let graphCollectionView = graphCollectionView {
            for cell in graphCollectionView.visibleCells() {
                if let graphCell = cell as? GraphCollectionCell {
                    graphCell.updateViewSize()
                }
            }
        }
    }

    func zoomInOut(zoomIn: Bool) {
        if let graphCollectionView = graphCollectionView {
            var size = self.cellSize
            
            let graphLayout = UICollectionViewFlowLayout()
            if zoomIn {
                size.width = size.width * 1.25  // 5/4
                // Don't let the cell size get too huge!
                if size.width > 4 * self.frame.width || size.width > 2000.0 {
                    NSLog("Zoom in limit reached!")
                    return
                }
            } else {
                size.width = size.width * 0.8   // 4/5
                // Don't let the cell size get so small that the number of cells can't cover the width of our view!
                if (size.width * CGFloat(graphCellsInCollection) < self.frame.width) {
                    NSLog("Zoom out limit reached!")
                    return
                }
            }
            graphLayout.itemSize = size

            NSLog("Zoom from cell size: \(self.cellSize) to \(size)")
            self.cellSize = size
            graphLayout.scrollDirection = UICollectionViewScrollDirection.Horizontal
            graphCollectionView.setCollectionViewLayout(graphLayout, animated: false)
            
            // Since we aren't changing the timeframe or time offset covered by each cell, we only need to have each visible cell redraw itself with its new sizing
            redrawData()
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
    
    private func configureGraphPixelsTimeInterval(pixelsPerHour: CGFloat) {
        if pixelsPerHour > kMaxPixelsPerHour || pixelsPerHour < kMinPixelsPerHour {
            return
        }
        NSLog("New pixels per hour: \(pixelsPerHour)")
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
    private func configureGraphViewIfNil() {
        if graphCollectionView == nil {
            
            // first put in the fixed background
            let graphView = GraphUIView.init(frame: self.bounds, centerTime: graphCenterTime, timeIntervalForView: graphViewTimeInterval, timeOfMainEvent: eventItem!.time)
            if let fixedBackgroundImageView = fixedBackgroundImageView {
                fixedBackgroundImageView.removeFromSuperview()
            }
            fixedBackgroundImageView = UIImageView(image: graphView.fixedBackgroundImage())
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
            let events = try DatabaseUtils.getTidepoolEvents(graphCollectStartTime, toTime: graphCollectEndTime, objectTypes: ["basal", "bolus"])
            
            NSLog("\(events.count) basal and bolus events fetched to figure max values")
            maxBasal = 0.0
            maxBolus = 0.0
            for event in events {
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

            NSLog("GraphContainerView cellForItemAtIndexPath \(indexPath.row)")
            // index determines center time...
            let cellCenterTime = centerTimeOfCellAtIndex(indexPath)
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
