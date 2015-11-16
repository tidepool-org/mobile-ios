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
    @IBOutlet weak var nutCrackedLabel: NutshellUILabel!
    
    @IBOutlet weak var photoDisplayImageView: UIImageView!
    
    private var eventTime = NSDate()
    private var placeholderLocationString = "Note location here!"

    //
    // MARK: - Base methods
    //

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDetailView()
        // We use a custom back button so we can redirect back when the event has changed. This tweaks the arrow positioning to match the iOS back arrow position
        self.navigationItem.leftBarButtonItem?.imageInsets = UIEdgeInsetsMake(0.0, -8.0, -1.0, 0.0)
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
            // "Edit" case
            let eventEditVC = segue.destinationViewController as! EventAddOrEditViewController
            eventEditVC.eventItem = eventItem
            eventEditVC.eventGroup = eventGroup
        } else if segue.identifier == EventViewStoryboard.SegueIdentifiers.EventItemAddSegue {
            // "Eat again" case...
            let eventAddVC = segue.destinationViewController as! EventAddOrEditViewController
            // no existing item to pass along...
            eventAddVC.eventGroup = eventGroup
        } else {
            NSLog("Unknown segue from eventDetail \(segue.identifier)")
        }
    }
    
    @IBAction func done(segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventDetail done")
        if let eventAddOrEditVC = segue.sourceViewController as? EventAddOrEditViewController {
            // update group and item!
            if let group = eventAddOrEditVC.eventGroup, item = eventAddOrEditVC.eventItem {
                self.eventGroup = group
                self.eventItem = item
            }
            reloadView()
        }
     }
    
    @IBAction func cancel(segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventDetail cancel")
    }

    //
    // MARK: - Button handlers
    //

    @IBAction func backButtonHandler(sender: AnyObject) {
        self.performSegueWithIdentifier("unwindSegueToDone", sender: self)
    }
    
    private func configureNutCracked() {
        if let eventItem = eventItem {
            nutCrackedLabel.text = eventItem.nutCracked ? NSLocalizedString("successButtonTitle", comment:"Success!") : NSLocalizedString("nutCrackedButtonTitle", comment:"Nut cracked?")
            nutCrackedButton.selected = eventItem.nutCracked
        }
    }
    
    @IBAction func nutCrackedButtonHandler(sender: AnyObject) {
        nutCrackedButton.selected = !nutCrackedButton.selected

        if let eventItem = eventItem {
            eventItem.nutCracked = nutCrackedButton.selected
            // Save changes to database
            eventItem.saveChanges()
            configureNutCracked()
        }
    }
    
    @IBAction func photoOverlayTouchHandler(sender: AnyObject) {
        if let mealItem = eventItem as? NutMeal {
            let firstPhotoUrl = mealItem.firstPictureUrl()
            if !firstPhotoUrl.isEmpty {
                let storyboard = UIStoryboard(name: "EventView", bundle: nil)
                let photoVC = storyboard.instantiateViewControllerWithIdentifier("ShowPhotoViewController") as! ShowPhotoViewController
                photoVC.imageUrl = firstPhotoUrl
                self.navigationController?.pushViewController(photoVC, animated: true)
            }
        }
    }
    
    @IBAction func photoDisplayButtonHandler(sender: AnyObject) {
        if let mealItem = eventItem as? NutMeal {
            let photoUrls = mealItem.photoUrlArray()
            if photoUrls.count > 1 {
                // shift photo urls - either 2 or 3...
                mealItem.photo = photoUrls[1]
                if photoUrls.count == 3 {
                    mealItem.photo2 = photoUrls[2]
                    mealItem.photo3 = photoUrls[0]
                } else {
                    mealItem.photo2 = photoUrls[0]
                    mealItem.photo3 = ""
                }
                // Save changes to database
                mealItem.saveChanges()
                configureDetailView()
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
            configureNutCracked()
            photoUIImageView.hidden = true
            dateLabel.text = NutUtils.standardUIDateString(eventTime, relative: true)
            
            locationContainerView.hidden = true
            if eventItem.location.characters.count > 0 {
                locationLabel.text = eventItem.location
                locationContainerView.hidden = false
            }

            photoUIImageView.hidden = true
            photoDisplayImageView.hidden = true
            let photoUrls = eventItem.photoUrlArray()
            if photoUrls.count > 0 {
                photoUIImageView.hidden = false
                photoDisplayImageView.hidden = false
                photoDisplayImageView.image = photoUrls.count == 1 ? UIImage(named: "singlePhotoIcon") : UIImage(named: "multiPhotoIcon")
                NutUtils.loadImage(photoUrls[0], imageView: photoUIImageView)
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



