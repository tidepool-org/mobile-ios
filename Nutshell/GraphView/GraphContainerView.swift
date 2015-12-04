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

class GraphContainerView: UIView {

    var eventItem: NutEventItem?
    
    private var graphCollectionView: UICollectionView?
    private var fixedBackgroundImageView: UIImageView?
    private var graphCenterTime: NSDate = NSDate()
    private var graphViewTimeInterval: NSTimeInterval = 0.0
    private var graphTimeScale = 1.0
    // variables for scaling by multiplier
    private var startGraphTimeScale = 1.0
    private let kMinGraphTimeScale = 0.25
    private let kInitGraphTimeScale = 1.0
    private let kMaxGraphTimeScale = 2.0
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
            determineGraphObjectSizing()
            graphCollectionView.reloadData()
        }
    }
    
    func zoomInOut(zoomIn: Bool) {
        let currentHours = self.bounds.width/graphPixelsPerHour
        let newHours = currentHours + (zoomIn ? -1.0 : 1.0)
        let newPixelsPerHour = floor(self.bounds.width/newHours)
        configureGraphPixelsTimeInterval(newPixelsPerHour)
        reloadData()
    }

    func centerGraphOnEvent(animated: Bool = false) {
        if let graphCollectionView = graphCollectionView {
            graphCollectionView.scrollToItemAtIndexPath(NSIndexPath(forRow: graphCenterCellInCollection, inSection: 0), atScrollPosition: UICollectionViewScrollPosition.CenteredHorizontally, animated: animated)
        }
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

    private func updateTimescale(newScale: Double) {
        graphTimeScale = startGraphTimeScale / newScale
        if graphTimeScale > kMaxGraphTimeScale {
            graphTimeScale = kMaxGraphTimeScale
        } else if graphTimeScale < kMinGraphTimeScale {
            graphTimeScale = kMinGraphTimeScale
        }
    }

    //
    // MARK: - Data methods
    //

    private var lastCenterTime: NSDate = NSDate()
    private var lastTimeInterval: NSTimeInterval = 0.0
    private var maxBolus: CGFloat = 0.0
    private var maxBasal: CGFloat = 0.0
    // Scan Bolus and Basal events to determine max values; the graph scales bolus and basal to these max sizes, and because of boundary conditions between cells, this needs to be determined at the level of the entire graph, not just an individual cell
    // TODO: Find optimizations to avoid too many database queries. E.g., perhaps store min and max in block fetch data records and only query those blocks here. Or figure out how to cache this better, or share this lookup with that of the individual cells!
    // Perhaps cache this in class variable?
    private func determineGraphObjectSizing() {
        // Only query if our timeframe has changed to a larger scope...
        if lastCenterTime == graphCenterTime && lastTimeInterval >= graphViewTimeInterval {
            return
        }
        do {
            let boundsTimeIntervalFromCenter = graphViewTimeInterval * Double(graphCellsInCollection)/2.0
            let graphCollectStartTime = graphCenterTime.dateByAddingTimeInterval(-boundsTimeIntervalFromCenter)
            let graphCollectEndTime = graphCenterTime.dateByAddingTimeInterval(boundsTimeIntervalFromCenter)
            let ad = UIApplication.sharedApplication().delegate as! AppDelegate
            
            let events = try DatabaseUtils.getEvents(ad.managedObjectContext,
                fromTime: graphCollectStartTime, toTime: graphCollectEndTime, objectTypes: ["basal", "bolus"])
            
            NSLog("\(events.count) basal and bolus events fetched to figure max values")
            maxBasal = 0.0
            maxBolus = 0.0
            for event in events {
                switch event.type as! String {
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
            NSLog("Determined maxBolus:\(maxBolus), maxBasal:\(maxBasal)")
        } catch let error as NSError {
            print("Error: \(error)")
        }
        
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
                let graphView = GraphUIView.init(frame: self.bounds, centerTime: graphCenterTime, timeIntervalForView: graphViewTimeInterval*graphTimeScale, timeOfMainEvent: eventItem!.time)
                if let fixedBackgroundImageView = fixedBackgroundImageView {
                    fixedBackgroundImageView.removeFromSuperview()
                }
                fixedBackgroundImageView = UIImageView(image: graphView.fixedBackgroundImage())
                self.addSubview(fixedBackgroundImageView!)
                
                let flow = UICollectionViewFlowLayout()
                flow.itemSize = self.bounds.size
                flow.scrollDirection = UICollectionViewScrollDirection.Horizontal
                graphCollectionView = UICollectionView(frame: self.bounds, collectionViewLayout: flow)
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
                    //graphSectionView.insertSubview(graphCollectionView, aboveSubview: fixedBackgroundImageView!)
                    
                    // add pinch gesture recognizer
                    //let recognizer = UIPinchGestureRecognizer(target: self, action: "pinchGestureHandler:")
                    //graphCollectionView.addGestureRecognizer(recognizer)
                    
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
                cellCenterTime = NSDate(timeInterval: graphViewTimeInterval*Double(collectionOffset)*graphTimeScale, sinceDate: graphCenterTime)
            }
            return cellCenterTime
        }
        
        func pinchGestureHandler(sender: AnyObject) {
            if let graphCollectionView = graphCollectionView {
                
                //NSLog("recognized pinch!")
                if let gesture = sender as? UIPinchGestureRecognizer {
                    if gesture.state == UIGestureRecognizerState.Began {
                        //NSLog("gesture started: scale: \(graphTimeScale)")
                        startGraphTimeScale = graphTimeScale
                        return
                    }
                    if gesture.state == UIGestureRecognizerState.Changed {
                        //NSLog("gesture state changed scale: \(gesture.scale)")
                        updateTimescale(Double(gesture.scale))
                        if let curCellIndex = currentCellIndex(graphCollectionView) {
                            if let curCell = graphCollectionView.cellForItemAtIndexPath(curCellIndex) {
                                if let graphCell = curCell as? GraphCollectionCell {
                                    let centerTime = centerTimeOfCellAtIndex(curCellIndex)
                                    graphCell.zoomXAxisToNewTime(centerTime, timeInterval:graphViewTimeInterval*graphTimeScale)
                                }
                            }
                        }
                        return
                    }
                    if gesture.state == UIGestureRecognizerState.Ended {
                        //NSLog("gesture ended with scale: \(gesture.scale)")
                        updateTimescale(Double(gesture.scale))
                        graphCollectionView.reloadData()
                        return
                    }
                }
            }
        }
    }

extension GraphContainerView: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return graphCellsInCollection
    }
    
    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(collectCellReuseID, forIndexPath: indexPath) as! GraphCollectionCell
            
            // index determines center time...
            let cellCenterTime = centerTimeOfCellAtIndex(indexPath)
            cell.configureCell(cellCenterTime, timeInterval: graphViewTimeInterval*graphTimeScale, mainEventTime: eventItem!.time, maxBolus: maxBolus, maxBasal: maxBasal)
            return cell
    }
}

extension GraphContainerView: UICollectionViewDelegate {
    
}

extension GraphContainerView: UICollectionViewDelegateFlowLayout {
    
    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat
    {
        return 0.0
    }
}
