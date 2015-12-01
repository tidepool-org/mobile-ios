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

    @IBOutlet weak var graphLayerContainer: UIView!
    @IBOutlet weak var graphSectionView: UIView!
    @IBOutlet weak var missingDataAdvisoryView: UIView!
    @IBOutlet weak var fixedGraphBackground: UIView!
    var fixedBackgroundImageView: UIImageView?
    
    @IBOutlet weak var photoUIImageView: UIImageView!

    @IBOutlet weak var headerOverlayContainer: UIControl!
    @IBOutlet weak var topSectionContainer: NutshellUIView!
    var titleLabel: UILabel?
    var notesLabel: UILabel?
    var dateLabel: UILabel?
    var locationLabel: UILabel?
    var locationIcon: UIImageView?
    
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
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "databaseChanged:", name: NewBlockRangeLoadedNotification, object: nil)
    }
 
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private var viewIsForeground: Bool = false
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //NSLog("viewWillAppear")
        viewIsForeground = true
        layoutHeaderView()
        checkUpdateGraph()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        viewIsForeground = false
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

    private func checkUpdateGraph() {
        if graphNeedsUpdate {
            graphNeedsUpdate = false
            if let graphCollectionView = graphCollectionView {
                graphCollectionView.reloadData()
            }
        }
    }
    
    private var graphNeedsUpdate: Bool  = false
    func databaseChanged(note: NSNotification) {
        graphNeedsUpdate = true
        if viewIsForeground {
            NSLog("EventDetailView: database load finished, reloading")
            checkUpdateGraph()
        } else {
            NSLog("EventDetailView: database load finished in background")
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
        centerGraphOnEvent(true)
//        if let mealItem = eventItem as? NutMeal {
//            let firstPhotoUrl = mealItem.firstPictureUrl()
//            if !firstPhotoUrl.isEmpty {
//                let storyboard = UIStoryboard(name: "EventView", bundle: nil)
//                let photoVC = storyboard.instantiateViewControllerWithIdentifier("ShowPhotoViewController") as! ShowPhotoViewController
//                photoVC.imageUrl = firstPhotoUrl
//                self.navigationController?.pushViewController(photoVC, animated: true)
//            }
//        }
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
                configurePhotoBackground()
            }
        }
    }
    
    private func configureGraphPixelsTimeInterval(pixelsPerHour: CGFloat) {
        if pixelsPerHour > kMaxPixelsPerHour || pixelsPerHour < kMinPixelsPerHour {
            return
        }
        NSLog("New pixels per hour: \(pixelsPerHour)")
        graphPixelsPerHour = pixelsPerHour
        graphViewTimeInterval = NSTimeInterval(graphSectionView.bounds.width * 3600.0/graphPixelsPerHour)
    }
    
    @IBAction func zoomInButtonHandler(sender: AnyObject) {
        configureGraphPixelsTimeInterval(graphPixelsPerHour + kDeltaPixelsPerHour)
        if let graphCollectionView = graphCollectionView {
            graphCollectionView.reloadData()
            centerGraphOnEvent(true)
        }
    }
    
    @IBAction func zoomOutButtonHandler(sender: AnyObject) {
        configureGraphPixelsTimeInterval(graphPixelsPerHour - kDeltaPixelsPerHour)
        if let graphCollectionView = graphCollectionView {
            graphCollectionView.reloadData()
            centerGraphOnEvent(true)
        }
    }
    
    //
    // MARK: - Configuration
    //
    
    private func configurePhotoBackground() {
        if let eventItem = eventItem {
            photoUIImageView.hidden = true
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
    }
    
    private func configureDetailView() {
        if let eventItem = eventItem {
            viewExistingEvent = true
            configureNutCracked()

            titleLabel = addLabel(eventItem.title, labelStyle: "detailHeaderTitle", currentView: titleLabel)
            notesLabel = addLabel(eventItem.notes, labelStyle: "detailHeaderNotes", currentView: notesLabel)
            notesLabel!.hidden = eventItem.notes.isEmpty

            eventTime = eventItem.time
            let dateLabelText = NutUtils.standardUIDateString(eventTime, relative: true)
            dateLabel = addLabel(dateLabelText, labelStyle: "detailHeaderDate", currentView: dateLabel)

            locationLabel = addLabel(eventItem.location, labelStyle: "detailHeaderLocation", currentView: locationLabel)
            locationLabel!.hidden = eventItem.location.isEmpty
            if !eventItem.location.isEmpty {
                let icon = UIImage(named:"placeSmallIcon")
                if let locationIcon = locationIcon {
                    locationIcon.removeFromSuperview()
                }
                locationIcon = UIImageView(image: icon)
                headerOverlayContainer.addSubview(locationIcon!)
            }
            configurePhotoBackground()
        }
        // set up graph area later when we know size of view
        graphCenterTime = eventTime
    }

    private func updateTimescale(newScale: Double) {
        graphTimeScale = startGraphTimeScale / newScale
        if graphTimeScale > kMaxGraphTimeScale {
            graphTimeScale = kMaxGraphTimeScale
        } else if graphTimeScale < kMinGraphTimeScale {
            graphTimeScale = kMinGraphTimeScale
        }
    }
    
    private func addLabel(labelText: String, labelStyle: String, currentView: UILabel?) -> UILabel {
        
        let paragraphStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.alignment = .Center
        paragraphStyle.lineBreakMode = .ByWordWrapping
        paragraphStyle.lineHeightMultiple = 0.9
        
        let label = NutshellUILabel(frame: CGRectZero)
        label.usage = labelStyle
        label.numberOfLines = 0
        label.attributedText = NSMutableAttributedString(string: labelText, attributes: [NSFontAttributeName: label.font, NSForegroundColorAttributeName: label.textColor, NSParagraphStyleAttributeName:paragraphStyle])
        if let currentView = currentView {
            currentView.removeFromSuperview()
        }
        headerOverlayContainer.addSubview(label)
        return label
    }

    //
    // MARK: - Layout Header
    //

    private let kMinTopMargin: CGFloat = 5.0
    private let kTargetTopMargin: CGFloat = 20.0
    private let kMinBottomMargin: CGFloat = 5.0
    private let kTargetBottomMargin: CGFloat = 20.0
    private let kMinTitleSubtitleSeparation: CGFloat = 2.0
    private let kTargetTitleSubtitleSeparation: CGFloat = 10.0
    private let kMinSubtitleDateSeparation: CGFloat = 2.0
    private let kTargetSubtitleDateSeparation: CGFloat = 10.0
    private let kMinDateLocationSeparation: CGFloat = 2.0
    private let kTargetDateLocationSeparation: CGFloat = 10.0
    private let klocationIconOffset: CGFloat = 8.0
    
    private func sizeNeededForLabel(availWidth: CGFloat, availHeight: CGFloat, label: UILabel?) -> CGSize {
        if let attribStr = label?.attributedText {
            let sizeNeeded = attribStr.boundingRectWithSize(CGSize(width: availWidth, height: availHeight), options: NSStringDrawingOptions.UsesLineFragmentOrigin, context: nil)
            return CGSize(width: ceil(sizeNeeded.width), height: ceil(sizeNeeded.height))
        } else {
            return CGSizeZero
        }
    }
    
    private func centerLabelInTopFrame(label: UILabel?, frame: CGRect) -> CGSize {
        var calcFrame = CGRectZero
        if let label = label {
            let sizeNeeded = sizeNeededForLabel(frame.size.width, availHeight: frame.size.height, label: label)
            calcFrame = frame
            calcFrame.size.height = ceil(sizeNeeded.height)
            calcFrame.origin.x += ceil((frame.size.width - sizeNeeded.width)/2)
            calcFrame.origin.y = ceil(calcFrame.origin.y)
            calcFrame.size.width = ceil(sizeNeeded.width)
            label.frame = calcFrame
            return sizeNeeded
        } else {
            return CGSizeZero
        }
    }
    
    private func growHeaderOverlayContainer(newMultiplier: CGFloat) -> CGRect {
        for c in topSectionContainer.constraints {
            // remove current constraint because multiplier can't be set
            if c.firstAttribute == NSLayoutAttribute.Width {
                topSectionContainer.removeConstraint(c)
                break
            }
        }
        let newC = NSLayoutConstraint(item: topSectionContainer, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: topSectionContainer, attribute: NSLayoutAttribute.Height, multiplier: newMultiplier, constant: 0.0)
        topSectionContainer.addConstraint(newC)
        topSectionContainer.setNeedsLayout()
        topSectionContainer.layoutIfNeeded()
        headerOverlayContainer.setNeedsLayout()
        headerOverlayContainer.layoutIfNeeded()
        return headerOverlayContainer.bounds
    }
    
    private func shrinkLabelHeight(curAllocation: CGFloat, minAllocation: CGFloat, width: CGFloat, label: UILabel) -> CGFloat {
        // trim label height allocation to minAllocation, returning reclaimed delta
        if curAllocation > minAllocation {
            let newAllocation = sizeNeededForLabel(width, availHeight: minAllocation, label: label).height
            let reclaimable = curAllocation - newAllocation
            if reclaimable > 0 {
                return reclaimable
            }
        }
        return 0.0
    }

/*
    Top section size should be minimum of half the screen width (for 2:1 aspect ratio), up to perhaps a 4:3 aspect ratio (to leave enough room for the graph at the bottom after subtracting space for the top and middle bars).
    
    Measure what is needed for all fields; date field is one line, the others can be multiple lines. If that fits with some space to distribute between fields, we're pretty much done.
    
    If not, start by growing the section size, trying aspect ratios of 3:2 and then 4:3. If we still don't have enough room for all fields, start limiting those fields to some % of the space, first location, then title, then notes.
    
    Distribute the remaining space proportionally between the fields, with slightly more space at top and bottom margins.
*/

    private func layoutHeaderView() {
        
        //NSLog("EventDetailVC layoutHeaderView")
        headerOverlayContainer.setNeedsLayout()
        headerOverlayContainer.layoutIfNeeded()
        var containerframe = headerOverlayContainer.bounds
        
        let titleHeightNeeded = sizeNeededForLabel(containerframe.width, availHeight: containerframe.height, label: titleLabel).height
        let dateHeightNeeded = sizeNeededForLabel(containerframe.width, availHeight: containerframe.height, label: dateLabel).height
        // note subtitle and location are optional
        let subtitleHeightNeeded = notesLabel!.hidden ? 0.0 : sizeNeededForLabel(containerframe.width, availHeight: containerframe.height, label: notesLabel).height
        let locationHeightNeeded = locationLabel!.hidden ? 0.0 : sizeNeededForLabel(containerframe.width, availHeight: containerframe.height, label: locationLabel).height
        var totalHeightNeeded = titleHeightNeeded + subtitleHeightNeeded + dateHeightNeeded + locationHeightNeeded
        let minSpacing = kMinTopMargin + kMinBottomMargin + kMinTitleSubtitleSeparation + kMinSubtitleDateSeparation + kMinDateLocationSeparation
        let targetSpacing = kTargetTopMargin + kTargetBottomMargin + kTargetTitleSubtitleSeparation + kTargetSubtitleDateSeparation + kTargetDateLocationSeparation
        
        // if we are short space, try growing the container to a 3:2 aspect ratio from 2:1
        if (containerframe.height < totalHeightNeeded + targetSpacing) {
            //NSLog("increase container to 3:2 aspect ratio to fit large text")
            containerframe = growHeaderOverlayContainer(1.5)
        }
        
        // if we are still short space, try a 4:3 aspect ratio
        if (containerframe.height < totalHeightNeeded + targetSpacing) {
            //NSLog("increase container to 4:3 aspect ratio to fit large text")
            containerframe = growHeaderOverlayContainer(4.0/3.0)
        }
        
        // next try min spacing - if we still don't fit, need to start reducing field sizes...
        
        var titleHeightAllocated = titleHeightNeeded
        var subtitleHeightAllocated = subtitleHeightNeeded
        let dateHeightAllocated = dateHeightNeeded
        var locationHeightAllocated = locationHeightNeeded
        var locationIconWidth: CGFloat = 0.0
        if let locationIcon = locationIcon {
            if !locationIcon.hidden {
                locationIconWidth = locationIcon.bounds.width + 2*klocationIconOffset
            }
        }
        
        let spaceTarget = containerframe.height - minSpacing
        if locationHeightNeeded != 0.0 && (containerframe.height < totalHeightNeeded + minSpacing) {
            // still need space, try limiting location field...
            let reclaimable = shrinkLabelHeight(locationHeightNeeded, minAllocation: spaceTarget/4, width: headerOverlayContainer.bounds.width - locationIconWidth, label: locationLabel!)
            totalHeightNeeded -= reclaimable
            locationHeightAllocated -= reclaimable
            //NSLog("save space by decreasing allocation to location by \(reclaimable)")
        }
        
        if subtitleHeightNeeded != 0.0 && (containerframe.height < totalHeightNeeded + minSpacing) {
            // still need space, try limiting title field...
            let reclaimable = shrinkLabelHeight(titleHeightNeeded, minAllocation: spaceTarget/4, width: headerOverlayContainer.bounds.width, label: titleLabel!)
            totalHeightNeeded -= reclaimable
            titleHeightAllocated -= reclaimable
            //NSLog("save space by decreasing allocation to title by \(reclaimable)")
        }
        
        if (containerframe.height < totalHeightNeeded + minSpacing) {
            // still need space, try limiting notes field...
            let reclaimable = shrinkLabelHeight(subtitleHeightNeeded, minAllocation: spaceTarget/3, width: headerOverlayContainer.bounds.width, label: notesLabel!)
            totalHeightNeeded -= reclaimable
            subtitleHeightAllocated -= reclaimable
            //NSLog("save space by decreasing allocation to subtitle by \(reclaimable)")
        }
        
        // distribute space remaining
        var spaceRemaining: CGFloat = containerframe.height - totalHeightNeeded
        //NSLog("space remaining to distribute: \(spaceRemaining)")
        if spaceRemaining < 0.0 {
            spaceRemaining = 0.0
            NSLog("Error: Still too large!!")
        }
        
        var yAdvance = spaceRemaining == 0.0 ? kMinTopMargin : (kTargetTopMargin/targetSpacing) * spaceRemaining
        var nextFrame = CGRect(x: 0.0, y: yAdvance, width: containerframe.width, height: titleHeightAllocated)
        
        var heightUsed = centerLabelInTopFrame(titleLabel, frame: nextFrame).height
        var spacing = spaceRemaining == 0.0 ? kMinTitleSubtitleSeparation : (kTargetTitleSubtitleSeparation/targetSpacing) * spaceRemaining
        yAdvance = centerLabelInTopFrame(titleLabel, frame: nextFrame).height + spacing
        nextFrame.size.height = subtitleHeightAllocated
        nextFrame.origin.y += yAdvance
        
        heightUsed = centerLabelInTopFrame(notesLabel, frame: nextFrame).height
        spacing = spaceRemaining == 0.0 ? kMinSubtitleDateSeparation : (kTargetSubtitleDateSeparation/targetSpacing) * spaceRemaining
        yAdvance =  heightUsed + spacing
        nextFrame.size.height = dateHeightAllocated
        nextFrame.origin.y += yAdvance
        
        heightUsed = centerLabelInTopFrame(dateLabel, frame: nextFrame).height
        spacing = spaceRemaining == 0.0 ? kMinDateLocationSeparation : (kTargetDateLocationSeparation/targetSpacing) * spaceRemaining
        yAdvance =  heightUsed + spacing
        nextFrame.size.height = locationHeightAllocated
        nextFrame.origin.y += yAdvance
        
        if !locationLabel!.hidden {
            nextFrame.origin.x += locationIconWidth/2.0
            nextFrame.size.width -= locationIconWidth
            centerLabelInTopFrame(locationLabel, frame: nextFrame)
            if let locationIcon = locationIcon, locationLabel = locationLabel {
                // place icon to left of first line of location...
                var iconFrame: CGRect = locationIcon.bounds
                iconFrame.origin.x = ceil(locationLabel.frame.origin.x - iconFrame.width - klocationIconOffset)
                iconFrame.origin.y = locationLabel.frame.origin.y - 2.0
                locationIcon.frame = iconFrame
            }
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
    
    private func centerGraphOnEvent(animated: Bool = false) {
        if let graphCollectionView = graphCollectionView {
            graphCollectionView.scrollToItemAtIndexPath(NSIndexPath(forRow: graphCenterCellInCollection, inSection: 0), atScrollPosition: UICollectionViewScrollPosition.CenteredHorizontally, animated: animated)
        }
    }
    
    private let collectCellReuseID = "graphViewCell"
    private func configureGraphViewIfNil() {
        if viewExistingEvent && (graphCollectionView == nil) {
            
            // first put in the fixed background
            let graphView = GraphUIView.init(frame: fixedGraphBackground.bounds, centerTime: graphCenterTime, timeIntervalForView: graphViewTimeInterval*graphTimeScale, timeOfMainEvent: eventItem!.time)
            if let fixedBackgroundImageView = fixedBackgroundImageView {
                fixedBackgroundImageView.removeFromSuperview()
            }
            fixedBackgroundImageView = UIImageView(image: graphView.fixedBackgroundImage())
            fixedGraphBackground.addSubview(fixedBackgroundImageView!)
            
            let flow = UICollectionViewFlowLayout()
            flow.itemSize = graphSectionView.bounds.size
            flow.scrollDirection = UICollectionViewScrollDirection.Horizontal
            graphCollectionView = UICollectionView(frame: graphSectionView.bounds, collectionViewLayout: flow)
            if let graphCollectionView = graphCollectionView {
                graphCollectionView.backgroundColor = UIColor.clearColor()
                graphCollectionView.showsHorizontalScrollIndicator = false
                graphCollectionView.showsVerticalScrollIndicator = false
                graphCollectionView.dataSource = self
                graphCollectionView.delegate = self
                graphCollectionView.pagingEnabled = false
                graphCollectionView.registerClass(EventDetailGraphCollectionCell.self, forCellWithReuseIdentifier: collectCellReuseID)
                // event is in the center cell, see cellForItemAtIndexPath below...
                centerGraphOnEvent()
                graphLayerContainer.addSubview(graphCollectionView)
                //graphSectionView.insertSubview(graphCollectionView, aboveSubview: fixedBackgroundImageView!)
                
                // add pinch gesture recognizer
                let recognizer = UIPinchGestureRecognizer(target: self, action: "pinchGestureHandler:")
                graphCollectionView.addGestureRecognizer(recognizer)
                
            }
            
            // Now that graph width is known, configure time span
            configureGraphPixelsTimeInterval(kInitPixelsPerHour)
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
                            if let graphCell = curCell as? EventDetailGraphCollectionCell {
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
    
    override func viewDidLayoutSubviews() {
        //NSLog("EventDetailVC viewDidLayoutSubviews")
        if viewExistingEvent && (graphCollectionView != nil) {
            // self.view's direct subviews are laid out, force graph subview to layout its subviews:
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

    
}

extension EventDetailViewController: UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return graphCellsInCollection
    }
    
    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(collectCellReuseID, forIndexPath: indexPath) as! EventDetailGraphCollectionCell
            
            // index determines center time...
            let cellCenterTime = centerTimeOfCellAtIndex(indexPath)
            if cell.configureCell(cellCenterTime, timeInterval: graphViewTimeInterval*graphTimeScale, mainEventTime: eventItem!.time) {
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



