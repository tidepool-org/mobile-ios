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
    // Notify caller that a cell has been updated...
    func containerCellUpdated()
    func pinchZoomEnded()
    func dataPointTapped(dataPoint: GraphDataType, tapLocationInView: CGPoint)
    func willDisplayGraphCell(cell: Int)
}

class GraphContainerView: UIView {
    
    var delegate: GraphContainerViewDelegate?
    var layout: GraphLayout
    var graphCollectionView: UICollectionView?
    
    init(frame: CGRect, delegate: GraphContainerViewDelegate, layout: GraphLayout) {
        self.delegate = delegate
        self.layout = layout
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // private
    private var cellSize = CGSizeZero
    private var pinchStartCellSize = CGSizeZero
    private var pinchLocationInView = CGPointZero
    private var fixedBackgroundImageView: UIImageView?
    private var graphPixelsPerHour: CGFloat = 80
    
    func loadGraphData() {
        //NSLog("GraphContainerView reloading data")
        if let graphCollectionView = graphCollectionView {
            graphCollectionView.reloadData()
        }
    }
    
    func zoomInOut(zoomIn: Bool) {
        var size = self.cellSize
        
        if zoomIn {
            size.width = size.width * (1/layout.zoomIncrement)
        } else {
            size.width = size.width * layout.zoomIncrement
        }
        // Use middle of view as zoom spreading center
        zoomCellSize(size, xOffsetInView: (self.bounds.width)/2.0)
    }
    
    func canZoomIn() -> Bool {
        return self.cellSize.width < layout.zoomInMaxCellWidth()
    }
    
    func canZoomOut() -> Bool {
        return self.cellSize.width > layout.zoomOutMinCellWidth()
    }

    private func zoomCellSize(var size: CGSize, xOffsetInView: CGFloat) {

        // First check against limits, return if we are already there
        let maxWidth = layout.zoomInMaxCellWidth()
        if size.width >= maxWidth {
            NSLog("Zoom in limit reached!")
            if size.width == maxWidth {
                return
            }
            size.width = maxWidth
        }
        let minWidth = layout.zoomOutMinCellWidth()
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

            // Convert xOffset for zoom center back for the new content view size so the point in the middle of our graph view doesn't change
            let contentOffsetToViewCenterZoom = graphCollectionView.contentOffset.x + xOffsetInView
            let timeOffsetToViewCenterZoom = self.viewXOffsetToTimeOffset(contentOffsetToViewCenterZoom)
            
            // Figure backwards with new overall content view sizing for xOffset to the same time offset as before...
            let newContentSizeWidth = size.width * CGFloat(layout.graphCellsInCollection)
            let newContentOffsetToViewCenterZoom = CGFloat(timeOffsetToViewCenterZoom / layout.graphTimeInterval) * newContentSizeWidth
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
            
            let collectLayout = UICollectionViewFlowLayout()
            collectLayout.itemSize = size
            collectLayout.targetContentOffsetForProposedContentOffset(targetOffset)
            collectLayout.scrollDirection = UICollectionViewScrollDirection.Horizontal
            graphCollectionView.setCollectionViewLayout(collectLayout, animated: false)
            //NSLog("End content offset & size: \(graphCollectionView.contentOffset) & \(graphCollectionView.contentSize)")
            
            // Since we aren't changing the timeframe or time offset covered by each cell, we only need to have each visible cell redraw itself with its new sizing
            layout.updateCellViewSize(size)
            for cell in graphCollectionView.visibleCells() {
                if let graphCell = cell as? GraphCollectionCell {
                    graphCell.updateViewSize()
                }
            }
            graphCollectionView.setContentOffset(targetOffset, animated: false)
        }
    }
    
    func centerGraphOnEvent(edgeOffset: CGFloat = 0.0, animated: Bool = false) {
        if let graphCollectionView = graphCollectionView {
            graphCollectionView.scrollToItemAtIndexPath(NSIndexPath(forRow: layout.graphCenterCellInCollection, inSection: 0), atScrollPosition: UICollectionViewScrollPosition.CenteredHorizontally, animated: animated)
            
            // Setting an edge offset will put the center graph point at this x position within the graph view
            if !animated && edgeOffset != 0.0 {
                let targetOffsetX = graphCollectionView.contentOffset.x - edgeOffset + cellSize.width/2.0
                let targetOffset = CGPoint(x: targetOffsetX, y: 0.0)
                graphCollectionView.setContentOffset(targetOffset, animated: false)
            }
        }
    }

    //
    // MARK: - Private methods
    //

    private func viewXOffsetToTimeOffset(viewXOffset: CGFloat) -> NSTimeInterval {
        let viewWidth = graphCollectionView!.contentSize.width
        return layout.graphTimeInterval * NSTimeInterval(viewXOffset / viewWidth)
    }
    
    private func deleteGraphView() {
        if (graphCollectionView != nil) {
            graphCollectionView?.removeFromSuperview();
            graphCollectionView = nil;
        }
    }
    
    private let collectCellReuseID = "graphViewCell"
    func configureGraph(edgeOffset: CGFloat = 0.0) {
        if graphCollectionView == nil {
            layout.configureGraph()
            
            // first put in the fixed background
            if let fixedBackgroundImageView = fixedBackgroundImageView {
                fixedBackgroundImageView.removeFromSuperview()
            }
            
            // Note: for time-invariant background view generation, startTime can be anything!
            let graphView = GraphUIView.init(frame: self.bounds, startTime: layout.graphStartTime, layout: layout)
            fixedBackgroundImageView = UIImageView(image: graphView.fixedBackgroundImage())
            
            self.addSubview(fixedBackgroundImageView!)
            
            let collectLayout = UICollectionViewFlowLayout()
            self.cellSize = self.bounds.size
            collectLayout.itemSize = self.cellSize
            collectLayout.scrollDirection = UICollectionViewScrollDirection.Horizontal
            graphCollectionView = UICollectionView(frame: self.bounds, collectionViewLayout: collectLayout)
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
                centerGraphOnEvent(edgeOffset)
                self.addSubview(graphCollectionView)
                
                // add pinch gesture recognizer
                let recognizer = UIPinchGestureRecognizer(target: self, action: "pinchGestureHandler:")
                graphCollectionView.addGestureRecognizer(recognizer)
                
                let tapRecognizer = UITapGestureRecognizer(target: self, action: "tapGestureHandler:")
                graphCollectionView.addGestureRecognizer(tapRecognizer)
            }
        }
    }
    
    func currentCellIndex(collectView: UICollectionView) -> NSIndexPath? {
        let centerPoint = collectView.center
        let pointInCell = CGPoint(x: centerPoint.x + collectView.contentOffset.x, y: centerPoint.y + collectView.contentOffset.y)
        return collectView.indexPathForItemAtPoint(pointInCell)
    }
    
    func startTimeOfCellAtIndex(indexPath: NSIndexPath) -> NSDate {
        var cellStartTime = layout.graphStartTime
        let collectionOffset = indexPath.row
        
        if collectionOffset != 0 {
            cellStartTime = NSDate(timeInterval: layout.cellTimeInterval*Double(collectionOffset), sinceDate: cellStartTime)
        }
        return cellStartTime
    }

    // Maps taps to a particular cell and location within the cell, then calls into the graph data structures to see if an active datapoint was tapped: if so, calls the graph delegate with that point.
    func tapGestureHandler(sender: AnyObject) {
        //NSLog("recognized tap!")
        if let gesture = sender as? UITapGestureRecognizer {
            if gesture.state == .Ended {
                let tapLocation = gesture.locationInView(self)
                NSLog("tap detected at location: \(tapLocation)")
                if let collectView = graphCollectionView {
                    // map to point within a cell
                    let pointInCollection = CGPoint(x: tapLocation.x + collectView.contentOffset.x, y: tapLocation.y + collectView.contentOffset.y)
                    if let indexPath = collectView.indexPathForItemAtPoint(pointInCollection) {
                        if let cell = collectView.cellForItemAtIndexPath(indexPath) as? GraphCollectionCell {
                            let xOffsetInCell: CGFloat = round(pointInCollection.x % cellSize.width)
                            let pointInCell = CGPoint(x: xOffsetInCell, y: pointInCollection.y)
                            //NSLog("Cell at index \(indexPath.row) tapped at point: \(pointInCell)")
                            if let dataPoint = cell.tappedAtPoint(pointInCell) {
                                delegate?.dataPointTapped(dataPoint, tapLocationInView: tapLocation)
                            }
                        }
                    }
                }
            }
        }
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
}

//
// MARK: - UICollectionViewDataSource
//

extension GraphContainerView: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return layout.graphCellsInCollection
    }
    
    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(collectCellReuseID, forIndexPath: indexPath) as! GraphCollectionCell

            //NSLog("GraphContainerView cellForItemAtIndexPath \(indexPath.row)")
            // index determines center time...
            let cellStartTime = startTimeOfCellAtIndex(indexPath)
            cell.cellDebugId = String(indexPath.row)
            cell.layout = layout
            cell.configureCell(cellStartTime, timeInterval: layout.cellTimeInterval)
            delegate?.containerCellUpdated()
            return cell
    }
}

extension GraphContainerView: UICollectionViewDelegate {
    
    func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        //NSLog("collect view willDisplayCell at indexPath row: \(indexPath.row)")
        delegate?.willDisplayGraphCell(indexPath.row)
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
