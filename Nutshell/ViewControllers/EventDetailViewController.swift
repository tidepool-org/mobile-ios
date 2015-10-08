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
    var eventTitleString: String = ""
    var newMealEvent: Meal?
    private var viewExistingEvent = false

    var graphCollectionView: UICollectionView?
    private var graphCenterTime: NSDate = NSDate()
    private var graphViewTimeInterval: NSTimeInterval = 0.0
    private let graphCellsInCollection = 7
    private let graphCenterCellInCollection = 3
    
    @IBOutlet weak var graphSectionView: UIView!
    @IBOutlet weak var missingDataAdvisoryView: UIView!
    
    @IBOutlet weak var titleEventButton: NutshellUIButton!
    @IBOutlet weak var photoUIImageView: UIImageView!
    @IBOutlet weak var missingPhotoView: UIView!
    @IBOutlet weak var photoIconButton: UIButton!
    @IBOutlet weak var photoIconContainer: UIView!

    @IBOutlet weak var titleTextField: NutshellUITextField!
    @IBOutlet weak var notesTextField: NutshellUITextField!

    @IBOutlet weak var leftArrow: UIButton!
    @IBOutlet weak var rightArrow: UIButton!

    @IBOutlet weak var rightBarItem: UIBarButtonItem!

    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var addSuccessView: NutshellUIView!
    @IBOutlet weak var addSuccessImageView: UIImageView!
    
    @IBOutlet weak var datePickerView: UIView!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var dateButton: NutshellUIButton!
    
    @IBOutlet weak var locationContainerView: UIView!
    @IBOutlet weak var locationTextField: UITextField!

    private var eventTime = NSDate()
    private var placeholderNoteString = "Anything else to note?"
    private var placeholderLocationString = "Note location here!"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureDetailView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //
    // MARK: - configuration
    //

    private func configureDetailView() {
        
        if let eventItem = eventItem {
            viewExistingEvent = true
            titleTextField.text = eventItem.title
            notesTextField.text = eventItem.notes
            eventTime = eventItem.time
            graphCenterTime = eventItem.time
            missingPhotoView.hidden = false
            photoUIImageView.hidden = true
            configureCameraImageViewUp(true)
            if eventItem.notes.characters.count > 0 {
                notesTextField.text = eventItem.notes
            } else {
                notesTextField.text = placeholderNoteString
            }

            if let mealItem = eventItem as? NutMeal {
                if mealItem.location.characters.count > 0 {
                    locationTextField.text = mealItem.location
                } else {
                    locationTextField.text = placeholderLocationString
                }
                if mealItem.photo.characters.count > 0 {
                    if let image = UIImage(named: mealItem.photo) {
                        missingPhotoView.hidden = true
                        photoUIImageView.hidden = false
                        photoUIImageView.image = image
                    }
                }
            } else {
                // TODO: show other workout-specific items
                locationContainerView.hidden = true
            }
            configureArrows()
            // set up graph area later when we know size of view
        } else  {
            leftArrow.hidden = true
            rightArrow.hidden = true
            notesTextField.text = placeholderNoteString
            locationTextField.text = placeholderLocationString
            // title may be passed in...
            titleTextField.text = eventTitleString
            missingDataAdvisoryView.hidden = true
            
        }
        configureDateView()
        updateSaveButtonState()
        
    }
    
    //
    // MARK: - graph view
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

    private func reloadForNewEvent() {
        configureDetailView()
        deleteGraphView()
        configureGraphViewIfNil()
    }
    
    private func leftAndRightItems() -> (NutEventItem?, NutEventItem?) {
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
    
    //
    // MARK: - Button and text field handlers
    //

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
    
    @IBAction func titleEventButtonHandler(sender: NutshellUIButton) {
        titleTextField.becomeFirstResponder()
        hideDateIfOpen()
        configureCameraImageViewUp(true)
    }
    
    @IBAction func titleEditingDidBegin(sender: AnyObject) {
        hideDateIfOpen()
        configureCameraImageViewUp(true)
    }
    
    @IBAction func titleEditingDidEnd(sender: AnyObject) {
        updateSaveButtonState()
    }
    
    @IBAction func notesEditingDidBegin(sender: AnyObject) {
        hideDateIfOpen()
        if notesTextField.text == placeholderNoteString {
            notesTextField.text = ""
        }
    }
    
    @IBAction func notesEditingDidEnd(sender: AnyObject) {
        updateSaveButtonState()
        notesTextField.resignFirstResponder()
        if notesTextField.text == "" {
            notesTextField.text = placeholderNoteString
        }
    }
    
    @IBAction func locationEditingDidBegin(sender: AnyObject) {
        hideDateIfOpen()
        if locationTextField.text == placeholderLocationString {
            locationTextField.text = ""
        }
    }
    
    @IBAction func locationEditingDidEnd(sender: AnyObject) {
        updateSaveButtonState()
        locationTextField.resignFirstResponder()
        if locationTextField.text == "" {
            locationTextField.text = placeholderLocationString
        }
    }
    
    private func existingEventChanged() -> Bool {
         if let eventItem = eventItem {
            if eventItem.title != titleTextField.text {
                print("title changed, enabling save")
                return true
            }
            if eventItem.notes != notesTextField.text {
                print("notes changed, enabling save")
                return true
            }
            if eventItem.time != eventTime {
                print("event time changed, enabling save")
                return true
            }
            if let meal = eventItem as? NutMeal {
                if meal.location != locationTextField.text {
                    print("location changed, enabling save")
                    return true
                }
            }
        }
        return false
    }
    
    private func updateSaveButtonState() {
        if viewExistingEvent {
            saveButton.hidden = !existingEventChanged()
        } else {
            if titleTextField.text?.characters.count == 0 {
                saveButton.hidden = true
                configureCameraImageViewUp(false)
            } else {
                saveButton.hidden = false
                configureCameraImageViewUp(true)
            }
        }
    }
    
    private func updateCurrentEvent() {
        
        if let mealItem = eventItem as? NutMeal {
            // find the item...
            let ad = UIApplication.sharedApplication().delegate as! AppDelegate
            let moc = ad.managedObjectContext
           
            do {
                let events = try DatabaseUtils.getMealItem(moc, atTime: mealItem.time, title: mealItem.title)
                if events.count == 1 {
                    let event = events[0]
                    event.title = titleTextField.text
                    event.time = eventTime
                    event.notes = notesTextField.text
                    event.location = locationTextField.text
                    event.modifiedTime = NSDate()
                    moc.refreshObject(event, mergeChanges: true)
                    
                    mealItem.title = titleTextField.text!
                    mealItem.time = eventTime
                    mealItem.notes = notesTextField.text!
                    mealItem.location = locationTextField.text!
                    newMealEvent = event

                    // Save the database
                    do {
                        try moc.save()
                        print("addEvent: Database saved!")
                    } catch let error as NSError {
                        // TO DO: error message!
                        print("Failed to save MOC: \(error)")
                        newMealEvent = nil
                    }

                    // reload current view, save button should disappear and on exit the new event should trigger caller to update...
                    reloadForNewEvent()
                } else {
                    print("error: item count is \(events.count)")
                }
            } catch let error as NSError {
                print("Error: \(error)")
            }
         }
    }
    
    @IBAction func saveButtonHandler(sender: AnyObject) {
        
        if viewExistingEvent {
            updateCurrentEvent()
            return
        }
        
        if titleTextField.text == "testmode" {
            AppDelegate.testMode = !AppDelegate.testMode
            self.performSegueWithIdentifier("unwindSequeToEventList", sender: self)
            return
        }
        
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = ad.managedObjectContext
        
        if let entityDescription = NSEntityDescription.entityForName("Meal", inManagedObjectContext: moc) {
            
            // This is a good place to splice in demo and test data. For now, entering "demo" as the title will result in us adding a set of demo events to the model, and "delete" will delete all food events.
            if titleTextField.text == "demo" {
                DatabaseUtils.deleteAllNutEvents(moc)
                addDemoData()
            } else if titleTextField.text == "nodemo" {
                DatabaseUtils.deleteAllNutEvents(moc)
            } else {
                let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Meal
                
                var location = locationTextField.text
                if location == placeholderLocationString {
                    location = ""
                }
                me.location = location
                
                me.title = titleTextField.text
                var notes = notesTextField.text
                if notes == placeholderNoteString {
                    notes = ""
                }
                me.notes = notes
                me.photo = ""
                me.type = "meal"
                me.time = eventTime // required!
                let now = NSDate()
                me.createdTime = now
                me.modifiedTime = now
                moc.insertObject(me)
                newMealEvent = me
            }
            
            // Save the database
            do {
                try moc.save()
                print("addEvent: Database saved!")
                if let eventGroup = eventGroup {
                    if eventGroup.title == (newMealEvent?.title)! {
                        eventGroup.addEvent(newMealEvent!)
                    }
                }
                showSuccessView()
            } catch let error as NSError {
                // TO DO: error message!
                print("Failed to save MOC: \(error)")
                newMealEvent = nil
            }
        }
    }
    
    @IBAction func backButtonHandler(sender: AnyObject) {
        // this is a cancel for the role of addEvent
        // for viewEvent, we need to check whether the title has changed
        if viewExistingEvent {
            if let newMealEvent = newMealEvent, eventGroup = eventGroup {
                if eventGroup.title != newMealEvent.title {
                    self.performSegueWithIdentifier("unwindSequeToEventList", sender: self)
                    return
                }
            }
        }
        // just a normal cancel, but
        self.performSegueWithIdentifier("unwindSegueToCancel", sender: self)
    }
    
    //
    // MARK: - Misc private funcs
    //
    
    private func showSuccessView() {
        let animations: [UIImage]? = [UIImage(named: "addAnimation-01")!,
            UIImage(named: "addAnimation-02")!,
            UIImage(named: "addAnimation-03")!,
            UIImage(named: "addAnimation-04")!,
            UIImage(named: "addAnimation-05")!,
            UIImage(named: "addAnimation-06")!]
        addSuccessImageView.animationImages = animations
        addSuccessImageView.animationDuration = 1.0
        addSuccessImageView.animationRepeatCount = 1
        addSuccessImageView.startAnimating()
        addSuccessView.hidden = false
        
        NutUtils.delay(1.25) {
            if let newMealEvent = self.newMealEvent, eventGroup = self.eventGroup {
                if newMealEvent.title != eventGroup.title {
                    self.performSegueWithIdentifier("unwindSequeToEventList", sender: self)
                    return
                }
            }
            self.performSegueWithIdentifier("unwindSegueToDone", sender: self)
        }
    }
    
    // When the event has a title, the "Title this event" button disappears, and the photo icon is recentered in its container view. This is reversed if the title goes back to an empty string.
    private func configureCameraImageViewUp(up: Bool) {
        
        titleEventButton.hidden = up
        
        for c in photoIconContainer.constraints {
            if c.firstAttribute == NSLayoutAttribute.CenterY {
                c.constant = up ? 0.0 : 20.0
                break
            }
        }
        UIView.animateWithDuration(0.25) {
            self.photoIconContainer.layoutIfNeeded()
        }
    }
    
    //
    // MARK: - Date picking
    //
    
    private func hideDateIfOpen() {
        if !datePickerView.hidden {
            configureDateView()
        }
    }
    
    private func configureDateView() {
        
        dateButton.setTitle(NutUtils.dateFormatter.stringFromDate(eventTime), forState: UIControlState.Normal)
        datePicker.date = eventTime
        datePickerView.hidden = true
    }
    
    @IBAction func dateButtonHandler(sender: AnyObject) {
        // user tapped on date, bring up date picker
        datePickerView.hidden = !datePickerView.hidden
    }
    
    @IBAction func cancelDatePickButtonHandler(sender: AnyObject) {
        configureDateView()
    }
    
    @IBAction func doneDatePickButtonHandler(sender: AnyObject) {
        eventTime = datePicker.date
        configureDateView()
        updateSaveButtonState()
    }
    
    //
    // MARK: - Test code!
    //
    
    private func addDemoData() {
        
        let demoMeals = [
            ["Three tacos", "with 15 chips & salsa", "2015-08-20T10:03:21.000Z", "home", "ThreeTacosDemoPic"],
            ["Three tacos", "after ballet", "2015-08-09T19:42:40.000Z", "238 Garrett St", "applejuicedemopic"],
            ["Three tacos", "Apple Juice before", "2015-07-29T04:55:27.000Z", "Golden Gate Park", "applejuicedemopic"],
            ["Three tacos", "and horchata", "2015-07-28T14:25:21.000Z", "Golden Gate Park", "applejuicedemopic"],
            ["CPK 5 cheese margarita", "", "2015-07-27T12:25:21.000Z", "", ""],
            ["Bagel & cream cheese fruit", "", "2015-07-27T16:25:21.000Z", "", ""],
            ["Birthday Party", "", "2015-07-26T14:25:21.000Z", "", ""],
        ]
        
        func addMeal(me: Meal, event: [String]) {
            me.title = event[0]
            me.notes = event[1]
            if (event[2] == "") {
                me.time = NSDate()
            } else {
                me.time = NutUtils.dateFromJSON(event[2])
            }
            me.location = event[3]
            me.photo = event[4]
            me.type = "meal"
            me.id = NSUUID().UUIDString // required!
            let now = NSDate()
            me.createdTime = now
            me.modifiedTime = now
        }
        
        let demoWorkouts = [
            ["Runs", "regular 3 mile", "2015-07-28T12:25:21.000Z", "6000"],
            ["Workout", "running in park", "2015-07-27T04:23:20.000Z", "2100"],
            ["PE class", "some notes for this one", "2015-07-27T08:25:21.000Z", "3600"],
            ["Soccer Practice", "", "2015-07-25T14:25:21.000Z", "4800"],
        ]
        
        func addWorkout(we: Workout, event: [String]) {
            we.title = event[0]
            we.notes = event[1]
            if (event[2] == "") {
                we.time = NSDate().dateByAddingTimeInterval(-60*60)
                we.duration = (-60*60)
            } else {
                we.time = NutUtils.dateFromJSON(event[2])
                we.duration = NSTimeInterval(event[3])
            }
            we.type = "workout"
            we.id = NSUUID().UUIDString // required!
            let now = NSDate()
            we.createdTime = now
            we.modifiedTime = now
        }
        
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = ad.managedObjectContext
        if let entityDescription = NSEntityDescription.entityForName("Meal", inManagedObjectContext: moc) {
            for event in demoMeals {
                let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Meal
                addMeal(me, event: event)
                moc.insertObject(me)
            }
        }
        if let entityDescription = NSEntityDescription.entityForName("Workout", inManagedObjectContext: moc) {
            for event in demoWorkouts {
                let we = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Workout
                addWorkout(we, event: event)
                moc.insertObject(we)
            }
        }
        
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
