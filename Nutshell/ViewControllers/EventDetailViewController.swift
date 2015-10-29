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
import CoreData

class EventDetailViewController: BaseUIViewController {
    
    var eventItem: NutEventItem?
    var eventGroup: NutEvent?
    private var viewExistingEvent = false
    
    var graphCollectionView: UICollectionView?
    private var graphCenterTime: NSDate = NSDate()
    private var graphViewTimeInterval: NSTimeInterval = 0.0
    private let graphCellsInCollection = 7
    private let graphCenterCellInCollection = 3
    
    @IBOutlet weak var graphSectionView: UIView!
    @IBOutlet weak var missingDataAdvisoryView: UIView!
    
    @IBOutlet weak var photoUIImageView: UIImageView!

    @IBOutlet weak var titleLabel: NutshellUILabel!
    @IBOutlet weak var notesLabel: NutshellUILabel!
    
    @IBOutlet weak var dateLabel: NutshellUILabel!
    @IBOutlet weak var locationContainerView: UIView!
    @IBOutlet weak var locationLabel: NutshellUILabel!
    
    @IBOutlet weak var nutCrackedButton: NutshellUIButton!
    
    private var eventTime = NSDate()
    private var placeholderLocationString = "Note location here!"

    //
    // MARK: - Base methods
    //

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDetailView()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //
    // MARK: - Navigation
    //
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        super.prepareForSegue(segue, sender: sender)
        if segue.identifier == EventViewStoryboard.SegueIdentifiers.EventItemEditSegue {
            let eventItemVC = segue.destinationViewController as! EventAddOrEditViewController
            eventItemVC.eventItem = eventItem
            eventItemVC.eventGroup = eventGroup
        } else if segue.identifier == EventViewStoryboard.SegueIdentifiers.EventItemAddSegue {
            let eventItemVC = segue.destinationViewController as! EventAddOrEditViewController
            // no existing item to pass along...
            eventItemVC.eventGroup = eventGroup
        } else {
            NSLog("Unknown segue from eventDetail \(segue.identifier)")
        }
    }
    
    @IBAction func done(segue: UIStoryboardSegue) {
        print("unwind segue to eventDetail done")
        reloadView()
    }
    
    @IBAction func cancel(segue: UIStoryboardSegue) {
        print("unwind segue to eventDetail cancel")
    }

    //
    // MARK: - Button handlers
    //

    @IBAction func backButtonHandler(sender: AnyObject) {
        // If either title or location have changed, we need to exit back to list...
        if let eventGroup = eventGroup, eventItem = eventItem {
            if eventItem.nutEventIdString() != eventGroup.nutEventIdString() {
                self.performSegueWithIdentifier("unwindSequeToEventList", sender: self)
                return
            }
        }
        self.performSegueWithIdentifier("unwindSegueToDone", sender: self)
    }
    
    @IBAction func nutCrackedButtonHandler(sender: AnyObject) {
        nutCrackedButton.selected = !nutCrackedButton.selected
        // TODO: need to actually save this change in database!
        if let eventItem = eventItem {
            eventItem.nutCracked = nutCrackedButton.selected
        }
    }
    
    @IBAction func photoOverlayTouchHandler(sender: AnyObject) {
        if let mealItem = eventItem as? NutMeal {
            if !mealItem.photo.isEmpty {
                let storyboard = UIStoryboard(name: "EventView", bundle: nil)
                let photoVC = storyboard.instantiateViewControllerWithIdentifier("ShowPhotoViewController") as! ShowPhotoViewController
                photoVC.imageUrl = mealItem.photo
                self.navigationController?.pushViewController(photoVC, animated: true)
            }
        }
    }
    
    //
    // MARK: - Configuration
    //
    
    private func configureDetailView() {
        if let eventItem = eventItem {
            viewExistingEvent = true
            titleLabel.text = eventItem.title
            notesLabel.text = eventItem.notes
            eventTime = eventItem.time
            nutCrackedButton.selected = eventItem.nutCracked
            photoUIImageView.hidden = true
            dateLabel.text = NutUtils.standardUIDateString(eventTime, relative: true)
            
            locationContainerView.hidden = true
            if eventItem.location.characters.count > 0 {
                locationLabel.text = eventItem.location
                locationContainerView.hidden = false
            }

            if let mealItem = eventItem as? NutMeal {
                photoUIImageView.hidden = true
                if mealItem.photo.characters.count > 0 {
                    if let image = UIImage(named: mealItem.photo) {
                        photoUIImageView.hidden = false
                        photoUIImageView.image = image
                    }
                }
            } else {
                // TODO: show other workout-specific items
            }
        }
        
        graphCenterTime = eventTime
        // set up graph area later when we know size of view
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
        if viewExistingEvent && (graphCollectionView == nil) {
            
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
        
        if viewExistingEvent && (graphCollectionView != nil) {
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
    
    //
    // MARK: - Deal with layout changes
    //
    
    private func reloadView() {
        configureDetailView()
        deleteGraphView()
        configureGraphViewIfNil()
    }
    
    //
    //    private func leftAndRightItems() -> (NutEventItem?, NutEventItem?) {
    //        var result = (eventItem, eventItem)
    //        var sawCurrentItem = false
    //        if let eventItem = eventItem {
    //            for item in (eventGroup?.itemArray)! {
    //                if item.time == eventItem.time {
    //                    sawCurrentItem = true
    //                } else if !sawCurrentItem {
    //                    result.0 = item
    //                } else {
    //                    result.1 = item
    //                    break
    //                }
    //            }
    //        }
    //        return result
    //    }
    //
    //    private func configureArrows() {
    //        if !AppDelegate.testMode {
    //            leftArrow.hidden = true
    //            rightArrow.hidden = true
    //        } else {
    //            let leftAndRight = leftAndRightItems()
    //            leftArrow.hidden = leftAndRight.0?.time == eventItem?.time
    //            rightArrow.hidden = leftAndRight.1?.time == eventItem?.time
    //        }
    //    }
    
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



