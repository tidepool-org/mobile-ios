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


class EventDetailViewController: BaseUIViewController {

    var eventItem: NutMeal?
    var eventGroup: NutEvent?

    var graphCollectionView: UICollectionView?
    private var graphCenterTime: NSDate = NSDate()
    private var graphViewTimeInterval: NSTimeInterval = 0.0
    private let graphCellsInCollection = 7
    private let graphCenterCellInCollection = 3
    
    @IBOutlet weak var graphSectionView: UIView!
    @IBOutlet weak var missingDataAdvisoryView: UIView!
    
    @IBOutlet weak var photoUIImageView: UIImageView!
    @IBOutlet weak var missingPhotoView: UIView!
    
    @IBOutlet weak var eventNotes: NutshellUILabel!
    @IBOutlet weak var eventDate: NutshellUILabel!
    @IBOutlet weak var leftArrow: UIButton!
    @IBOutlet weak var rightArrow: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureDetailView()
    }

    private func configureDetailView() {
        if let eventItem = eventItem {
            eventNotes.text = eventItem.notes
            eventDate.text = NutUtils.dateFormatter.stringFromDate(eventItem.time)
            graphCenterTime = eventItem.time
            if eventItem.photo.characters.count > 0 {
                if let image = UIImage(named: eventItem.photo) {
                    missingPhotoView.hidden = true
                    photoUIImageView.hidden = false
                    photoUIImageView.image = image
                }
            } else {
                missingPhotoView.hidden = false
                photoUIImageView.hidden = true
            }
            configureArrows()
            // set up graph area later when we know size of view
        }
    }
    
    private func deleteGraphView() {
        if (graphCollectionView != nil) {
            graphCollectionView?.removeFromSuperview();
            graphCollectionView = nil;
        }
    }
    
    private let collectCellReuseID = "graphViewCell"
    private func configureGraphViewIfNil() {
        if (graphCollectionView == nil) {
            
            let flow = UICollectionViewFlowLayout()
            flow.itemSize = graphSectionView.bounds.size
            flow.scrollDirection = UICollectionViewScrollDirection.Horizontal
            graphCollectionView = UICollectionView(frame: graphSectionView.bounds, collectionViewLayout: flow)
            if let graphCollectionView = graphCollectionView {
                graphCollectionView.backgroundColor = UIColor.whiteColor()
                graphCollectionView.showsHorizontalScrollIndicator = false
                graphCollectionView.showsVerticalScrollIndicator = false
                graphCollectionView.dataSource = self
                graphCollectionView.delegate = self
                graphCollectionView.pagingEnabled = true
                graphCollectionView.registerClass(EventDetailGraphCollectionCell.self, forCellWithReuseIdentifier: collectCellReuseID)
                // event is in the center cell, see cellForItemAtIndexPath below...
                graphCollectionView.scrollToItemAtIndexPath(NSIndexPath(forRow: graphCenterCellInCollection, inSection: 0), atScrollPosition: UICollectionViewScrollPosition.CenteredHorizontally, animated: false)

                graphSectionView.addSubview(graphCollectionView)
                graphSectionView.sendSubviewToBack(graphCollectionView)
            }

            // need about 60 pixels per hour...
             graphViewTimeInterval = NSTimeInterval(graphSectionView.bounds.width*60/* *60/60 */)
        }
    }
    
    override func viewDidLayoutSubviews() {
        
        if (graphCollectionView != nil) {
            // self.view's direct subviews are laid out.
            // force my subview to layout its subviews:
            graphSectionView.setNeedsLayout()
            graphSectionView.layoutIfNeeded()
            if (graphCollectionView!.frame.size != graphSectionView.frame.size) {
                deleteGraphView()
            }
        }
        configureGraphViewIfNil()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
  
    // MARK: - Deal with layout changes

    private func reloadForNewEvent() {
        configureDetailView()
        deleteGraphView()
        configureGraphViewIfNil()
    }
    
    private func leftAndRightItems() -> (NutMeal?, NutMeal?) {
        var result = (eventItem, eventItem)
        var sawCurrentItem = false
        if let eventItem = eventItem {
            for item in (eventGroup?.itemArray)! {
                if item.time == eventItem.time {
                    sawCurrentItem = true
                } else if !sawCurrentItem {
                    result.0 = item
                } else {
                    result.1 = item
                    break
                }
            }
        }
        return result
    }
    
    private func configureArrows() {
        if !AppDelegate.testMode {
            leftArrow.hidden = true
            rightArrow.hidden = true
        } else {
            let leftAndRight = leftAndRightItems()
            leftArrow.hidden = leftAndRight.0?.time == eventItem?.time
            rightArrow.hidden = leftAndRight.1?.time == eventItem?.time
        }
    }
    
    // MARK: - Button handlers

    @IBAction func leftArrowButtonHandler(sender: AnyObject) {
        let leftAndRight = leftAndRightItems()
        self.eventItem = leftAndRight.0
        reloadForNewEvent()
    }

    @IBAction func rightArrowButtonHandler(sender: AnyObject) {
    let leftAndRight = leftAndRightItems()
    self.eventItem = leftAndRight.1
    reloadForNewEvent()
    }
    
}

extension EventDetailViewController: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return graphCellsInCollection
    }
    
    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(collectCellReuseID, forIndexPath: indexPath) as! EventDetailGraphCollectionCell
            
            // index determines center time...
            var cellCenterTime = graphCenterTime
            let collectionOffset = indexPath.row - graphCenterCellInCollection
            
            if collectionOffset != 0 {
                cellCenterTime = NSDate(timeInterval: graphViewTimeInterval*Double(collectionOffset), sinceDate: graphCenterTime)
            }
            if cell.configureCell(cellCenterTime, timeInterval: graphViewTimeInterval) {
                // TODO: really want to scan the entire width to see if any of the time span has data...
                missingDataAdvisoryView.hidden = true;
            }
            
            return cell
    }
}

extension EventDetailViewController: UICollectionViewDelegate {
    
}

extension EventDetailViewController: UICollectionViewDelegateFlowLayout {
   
    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat
    {
        return 0.0
    }
}
