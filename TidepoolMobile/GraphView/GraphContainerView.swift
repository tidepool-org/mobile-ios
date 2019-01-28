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
import CocoaLumberjack

protocol GraphContainerViewDelegate {
    // Notify caller that a cell has been updated...
    func containerCellUpdated()
    func pinchZoomEnded()
    func dataPointTapped(_ dataPoint: GraphDataType, tapLocationInView: CGPoint)
    func willDisplayGraphCell(_ cell: Int)
    func unhandledTapAtLocation(_ tapLocationInView: CGPoint, graphTimeOffset: TimeInterval)
}

class GraphContainerView: UIView {
    
    var delegate: GraphContainerViewDelegate?
    var layout: GraphLayout
    var graphCollectionView: UICollectionView?
    var graphUtils: GraphingUtils?
    
    init(frame: CGRect, delegate: GraphContainerViewDelegate?, layout: GraphLayout) {
        self.delegate = delegate
        self.layout = layout
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // private
    fileprivate var cellSize = CGSize.zero
    fileprivate var pinchStartCellSize = CGSize.zero
    fileprivate var pinchLocationInView = CGPoint.zero
    fileprivate var fixedBackgroundImageView: UIImageView?
    fileprivate var graphPixelsPerHour: CGFloat = 80
    
    func loadGraphData() {
        //DDLogInfo("GraphContainerView reloading data")
        if let graphCollectionView = graphCollectionView {
            graphCollectionView.reloadData()
        }
    }
    
    func zoomInOut(_ zoomIn: Bool) {
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

    fileprivate func zoomCellSize(_ zoomToSize: CGSize, xOffsetInView: CGFloat) {

        var size = zoomToSize
        // First check against limits, return if we are already there
        let maxWidth = layout.zoomInMaxCellWidth()
        if size.width >= maxWidth {
            DDLogInfo("Zoom in limit reached!")
            if size.width == maxWidth {
                return
            }
            size.width = maxWidth
        }
        let minWidth = layout.zoomOutMinCellWidth()
        if size.width <= minWidth {
            DDLogInfo("Zoom out limit reached!")
            if size.width == minWidth {
                return
            }
            size.width = minWidth
        }

        if let graphCollectionView = graphCollectionView {
            //DDLogInfo("Zoom from cell size: \(self.cellSize) to \(size)")
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
            collectLayout.targetContentOffset(forProposedContentOffset: targetOffset)
            collectLayout.scrollDirection = UICollectionView.ScrollDirection.horizontal
            graphCollectionView.setCollectionViewLayout(collectLayout, animated: false)
            //DDLogInfo("End content offset & size: \(graphCollectionView.contentOffset) & \(graphCollectionView.contentSize)")
            
            // Since we aren't changing the timeframe or time offset covered by each cell, we only need to have each visible cell redraw itself with its new sizing
            layout.updateCellViewSize(size)
            for cell in graphCollectionView.visibleCells {
                if let graphCell = cell as? GraphCollectionCell {
                    graphCell.updateViewSize()
                }
            }
            graphCollectionView.setContentOffset(targetOffset, animated: false)
            graphCollectionView.delegate = self
        }
    }
    
    func centerGraphOnEvent(_ edgeOffset: CGFloat = 0.0, animated: Bool = false) {
        if let graphCollectionView = graphCollectionView {
            graphCollectionView.scrollToItem(at: IndexPath(row: layout.graphCellFocusInCollection, section: 0), at: UICollectionView.ScrollPosition.centeredHorizontally, animated: animated)
            
            // Setting an edge offset will put the center graph point at this x position within the graph view
            if !animated && edgeOffset != 0.0 {
                let targetOffsetX = graphCollectionView.contentOffset.x - edgeOffset + cellSize.width/2.0
                let targetOffset = CGPoint(x: targetOffsetX, y: 0.0)
                graphCollectionView.setContentOffset(targetOffset, animated: false)
            }
        }
    }

    func centerGraphAtTimeOffset(_ timeOffset: TimeInterval, animated: Bool = false) {
        if let graphCollectionView = graphCollectionView {
            
            var xOffset = CGFloat(timeOffset/layout.graphTimeInterval) * graphCollectionView.contentSize.width
            let centerOffset = layout.graphViewSize.width/2.0
            if xOffset < centerOffset {
                xOffset = centerOffset
            }
            let targetOffsetX = xOffset - centerOffset
            let targetOffset = CGPoint(x: targetOffsetX, y: 0.0)
            graphCollectionView.setContentOffset(targetOffset, animated: true)
         }
    }

    func updateCursorView(_ cursorTimeOffset: TimeInterval?, cursorColor: UIColor) {
        if let graphCollectionView = graphCollectionView {
            for cell in graphCollectionView.visibleCells {
                if let graphCell = cell as? GraphCollectionCell {
                    var cursorTime: Date?
                    if let cursorTimeOffset = cursorTimeOffset {
                        cursorTime = layout.graphStartTime.addingTimeInterval(cursorTimeOffset) as Date
                    }
                    graphCell.updateCursorView(cursorTime, cursorColor: cursorColor)
                }
            }
        }
    }
    
    //
    // MARK: - Private methods
    //

    fileprivate func viewXOffsetToTimeOffset(_ viewXOffset: CGFloat) -> TimeInterval {
        let viewWidth = graphCollectionView!.contentSize.width
        return layout.graphTimeInterval * TimeInterval(viewXOffset / viewWidth)
    }
    
    fileprivate func deleteGraphView() {
        if (graphCollectionView != nil) {
            graphCollectionView?.removeFromSuperview();
            graphCollectionView = nil;
        }
    }

    /// Return the non-changing part of the graph background
    ///
    /// Right now this is just the y axis with its values.
    ///
    /// - returns: A UIImageView the size of the current view, with static parts of the background. This should be placed in back of the graph...
    
    func fixedBackgroundImage() -> UIImage {
        let graphUtils = layout.graphUtilsForGraphView()
        return graphUtils.imageOfFixedGraphBackground()
    }
    
    func configureBackground() {
        // first put in the fixed background
        if let fixedBackgroundImageView = fixedBackgroundImageView {
            fixedBackgroundImageView.removeFromSuperview()
        }
        
        // Get time-invariant background view generation
        let graphUtils = layout.graphUtilsForGraphView()
        fixedBackgroundImageView = UIImageView(image: graphUtils.imageOfFixedGraphBackground())
        
        self.insertSubview(fixedBackgroundImageView!, at: 0)
    }
    
    fileprivate let collectCellReuseID = "graphViewCell"
    func configureGraph(_ edgeOffset: CGFloat = 0.0) {
        if graphCollectionView == nil {
            layout.configureGraph()
            
            configureBackground()
            
            let collectLayout = UICollectionViewFlowLayout()
            self.cellSize = layout.cellViewSize
            collectLayout.itemSize = self.cellSize
            collectLayout.scrollDirection = UICollectionView.ScrollDirection.horizontal
            graphCollectionView = UICollectionView(frame: self.bounds, collectionViewLayout: collectLayout)
            if let graphCollectionView = graphCollectionView {
                graphCollectionView.backgroundColor = UIColor.clear
                graphCollectionView.showsHorizontalScrollIndicator = false
                graphCollectionView.showsVerticalScrollIndicator = false
                graphCollectionView.dataSource = self
                graphCollectionView.delegate = self
                graphCollectionView.isPagingEnabled = false
                //graphCollectionView.contentSize = self.bounds.size
                graphCollectionView.register(GraphCollectionCell.self, forCellWithReuseIdentifier: collectCellReuseID)
                // event is in the center cell, see cellForItemAtIndexPath below...
                centerGraphOnEvent(edgeOffset)
                self.addSubview(graphCollectionView)
                
                // add pinch gesture recognizer
                let recognizer = UIPinchGestureRecognizer(target: self, action: #selector(GraphContainerView.pinchGestureHandler(_:)))
                graphCollectionView.addGestureRecognizer(recognizer)
                
                let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(GraphContainerView.tapGestureHandler(_:)))
                graphCollectionView.addGestureRecognizer(tapRecognizer)
            }
        }
    }
    
    func currentCellIndex(_ collectView: UICollectionView) -> IndexPath? {
        let centerPoint = collectView.center
        let pointInCell = CGPoint(x: centerPoint.x + collectView.contentOffset.x, y: centerPoint.y + collectView.contentOffset.y)
        return collectView.indexPathForItem(at: pointInCell)
    }
    
    func startTimeOfCellAtIndex(_ indexPath: IndexPath) -> Date {
        var cellStartTime = layout.graphStartTime
        let collectionOffset = indexPath.row
        
        if collectionOffset != 0 {
            cellStartTime = Date(timeInterval: layout.cellTimeInterval*Double(collectionOffset), since: cellStartTime)
        }
        return cellStartTime as Date
    }

    // Maps taps to a particular cell and location within the cell, then calls into the graph data structures to see if an active datapoint was tapped: if so, calls the graph delegate with that point.
    @objc func tapGestureHandler(_ sender: AnyObject) {
        //DDLogInfo("recognized tap!")
        if let gesture = sender as? UITapGestureRecognizer {
            if gesture.state == .ended {
                let tapLocation = gesture.location(in: self)
                DDLogInfo("tap detected at location: \(tapLocation)")
                if let collectView = graphCollectionView {
                    // map to point within a cell
                    var handledTap = false
                    let pointInCollection = CGPoint(x: tapLocation.x + collectView.contentOffset.x, y: tapLocation.y + collectView.contentOffset.y)
                    if let indexPath = collectView.indexPathForItem(at: pointInCollection) {
                        if let cell = collectView.cellForItem(at: indexPath) as? GraphCollectionCell {
                            let xOffsetInCell: CGFloat = round(pointInCollection.x.truncatingRemainder(dividingBy: cellSize.width))
                            let pointInCell = CGPoint(x: xOffsetInCell, y: pointInCollection.y)
                            //DDLogInfo("Cell at index \(indexPath.row) tapped at point: \(pointInCell)")
                            if let dataPoint = cell.tappedAtPoint(pointInCell) {
                                delegate?.dataPointTapped(dataPoint, tapLocationInView: tapLocation)
                                handledTap = true
                            }
                        }
                    }
                    if !handledTap {
                        let contentOffsetToTapX = collectView.contentOffset.x + tapLocation.x
                        let graphTimeOffset = viewXOffsetToTimeOffset(contentOffsetToTapX)
                        delegate?.unhandledTapAtLocation(tapLocation, graphTimeOffset: graphTimeOffset)
                    }
                }
            }
        }
    }
    
    @objc func pinchGestureHandler(_ sender: AnyObject) {
        //DDLogInfo("recognized pinch!")
        if let gesture = sender as? UIPinchGestureRecognizer {
            if gesture.state == UIGestureRecognizer.State.began {
                //DDLogInfo("gesture started: start cell size: \(cellSize)")
                pinchStartCellSize = cellSize
                pinchLocationInView = gesture.location(in: self)
                return
            }
            if gesture.state == UIGestureRecognizer.State.changed {
                //DDLogInfo("gesture state changed scale: \(gesture.scale)")
                var newCellSize = pinchStartCellSize
                newCellSize.width = round(newCellSize.width * CGFloat(gesture.scale))
                zoomCellSize(newCellSize, xOffsetInView: pinchLocationInView.x)
                return
            }
            if gesture.state == UIGestureRecognizer.State.ended {
                //DDLogInfo("gesture ended with scale: \(gesture.scale)")
                var newCellSize = pinchStartCellSize
                newCellSize.width = round(newCellSize.width * CGFloat(gesture.scale))
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
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return layout.graphCellsInCollection
    }
    
    func collectionView(_ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: collectCellReuseID, for: indexPath) as! GraphCollectionCell

            //DDLogInfo("GraphContainerView cellForItemAtIndexPath \(indexPath.row)")
            // index determines center time...
            let cellStartTime = startTimeOfCellAtIndex(indexPath)
            cell.layout = layout
            cell.configureCell(cellStartTime, timeInterval: layout.cellTimeInterval, cellIndex: indexPath.row)
            delegate?.containerCellUpdated()
            return cell
    }
}

extension GraphContainerView: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        //DDLogInfo("collect view willDisplayCell at indexPath row: \(indexPath.row)")
        delegate?.willDisplayGraphCell(indexPath.row)
    }
    
}

//
// MARK: - UICollectionViewDelegateFlowLayout
//

extension GraphContainerView: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int) -> CGFloat
    {
        return 0.0
    }
}
