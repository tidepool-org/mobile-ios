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
import Photos

class EventAddOrEditViewController: BaseUIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    var eventItem: NutEventItem?
    var eventGroup: NutEvent?
    var newEventItem: EventItem?
    private var viewExistingEvent = false
    
    @IBOutlet weak var titleTextField: NutshellUITextField!
    @IBOutlet weak var titleHintLabel: NutshellUILabel!
    @IBOutlet weak var notesTextField: NutshellUITextField!
    @IBOutlet weak var notesHintLabel: NutshellUILabel!
    
    @IBOutlet weak var placeIconButton: UIButton!
    @IBOutlet weak var photoIconButton: UIButton!
    @IBOutlet weak var calendarIconButton: UIButton!
    
    @IBOutlet weak var headerForModalView: NutshellUIView!
    @IBOutlet weak var sceneContainer: UIView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var addSuccessView: NutshellUIView!
    @IBOutlet weak var addSuccessImageView: UIImageView!
    
    @IBOutlet weak var datePickerView: UIView!
    @IBOutlet weak var datePicker: UIDatePicker!
    
    @IBOutlet weak var locationTextField: UITextField!
    @IBOutlet weak var date1Label: NutshellUILabel!
    @IBOutlet weak var date2Label: NutshellUILabel!
    
    @IBOutlet weak var picture0Image: UIImageView!
    @IBOutlet weak var picture1Image: UIImageView!
    @IBOutlet weak var picture2Image: UIImageView!
    
    private var eventTime = NSDate()
    private var pictureImageURLs: [String] = []
    private var editingPictureItem: Int = 0

    //
    // MARK: - Base methods
    //

    override func viewDidLoad() {
        super.viewDidLoad()
        var saveButtonTitle = NSLocalizedString("saveButtonTitle", comment:"Save")
        if let eventItem = eventItem {
            viewExistingEvent = true
            eventTime = eventItem.time
            // hide modal header when used as a nav view
            for c in headerForModalView.constraints {
                if c.firstAttribute == NSLayoutAttribute.Height {
                    c.constant = 0.0
                    break
                }
            }
        }  else  {
            locationTextField.text = Styles.placeholderLocationString
            saveButtonTitle = NSLocalizedString("saveAndEatButtonTitle", comment:"Save and eat!")
        }
        saveButton.setTitle(saveButtonTitle, forState: UIControlState.Normal)
        configureInfoSection()
        titleHintLabel.text = Styles.titleHintString
        notesHintLabel.text = Styles.noteHintString
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "textFieldDidChange", name: UITextFieldTextDidChangeNotification, object: nil)
        notificationCenter.addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
    }

    deinit {
        let nc = NSNotificationCenter.defaultCenter()
        nc.removeObserver(self, name: nil, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //
    // MARK: - Navigation
    //

    @IBAction func done(segue: UIStoryboardSegue) {
        print("unwind segue to eventAddOrEdit done")
        // Deal with possible delete/edit of photo from viewer...
        if segue.identifier == EventViewStoryboard.SegueIdentifiers.UnwindSegueFromShowPhoto {
            if let photoVC = segue.sourceViewController as? ShowPhotoViewController {
                pictureImageURLs = photoVC.photoURLs
                configurePhotos()
                updateSaveButtonState()
            }
            editingPictureItem = 0
        }
    }

    //
    // MARK: - Configuration
    //
    
    private func configureInfoSection() {
        var titleText = Styles.placeholderTitleString
        var notesText = Styles.placeholderNotesString
        
        if let eventItem = eventItem {
            if eventItem.title.characters.count > 0 {
                titleText = eventItem.title
            }
            if eventItem.notes.characters.count > 0 {
                notesText = eventItem.notes
            }
            
            picture0Image.hidden = true
            picture1Image.hidden = true
            picture2Image.hidden = true
           
            if let mealItem = eventItem as? NutMeal {
                if !mealItem.location.isEmpty {
                    locationTextField.text = mealItem.location
                } else {
                    locationTextField.text = Styles.placeholderLocationString
                }
                pictureImageURLs = mealItem.photoUrlArray()
            } else {
                // TODO: workout support! Add workout-specific items...
            }
        } else if let eventGroup = eventGroup {
                titleText = eventGroup.title
                locationTextField.text = eventGroup.location
        }

        titleTextField.text = titleText
        notesTextField.text = notesText
        configureTitleHint()
        configureNotesHint()
        configureDateView()
        configurePhotos()
        updateSaveButtonState()
    }
    
    private func configureTitleHint() {
        let isBeingEdited = titleTextField.isFirstResponder()
        if isBeingEdited {
            titleHintLabel.hidden = false
        } else {
            let titleIsSet = titleTextField.text != "" && titleTextField.text != Styles.placeholderTitleString
            titleHintLabel.hidden = titleIsSet
        }
    }

    private func configureNotesHint() {
        let isBeingEdited = notesTextField.isFirstResponder()
        if isBeingEdited {
            notesHintLabel.hidden = false
        } else {
            let notesIsSet = notesTextField.text != "" && notesTextField.text != Styles.placeholderNotesString
            notesHintLabel.hidden = notesIsSet
        }
    }

    private func configurePhotos() {
        for item in 0...2 {
            let picture = itemToPicture(item)
            let url = itemToImageUrl(item)
            if url.isEmpty {
                picture.hidden = true
            } else {
                picture.hidden = false
                NutUtils.loadImage(url, imageView: picture)
            }
        }
    }
    
    private func updateSaveButtonState() {
        if viewExistingEvent {
            saveButton.hidden = !existingEventChanged()
        } else {
            if !newEventChanged() || titleTextField.text?.characters.count == 0 ||  titleTextField.text == Styles.placeholderTitleString {
                saveButton.hidden = true
            } else {
                saveButton.hidden = false
            }
        }
    }

    // When the keyboard is up, the save button moves up
    private var viewAdjustAnimationTime: Float = 0.25
    private func configureSaveViewPosition(bottomOffset: CGFloat) {
        for c in sceneContainer.constraints {
            if c.firstAttribute == NSLayoutAttribute.Bottom {
                if let secondItem = c.secondItem {
                    if secondItem as! NSObject == saveButton {
                        c.constant = bottomOffset
                        break
                    }
                }
            }
        }
        UIView.animateWithDuration(NSTimeInterval(viewAdjustAnimationTime)) {
            self.saveButton.layoutIfNeeded()
        }
    }

    private func hideDateIfOpen() {
        if !datePickerView.hidden {
            configureDateView()
        }
    }
    
    // Bold all but last suffixCnt characters of string (Note: assumes date format!
    private func boldFirstPartOfDateString(dateStr: String, suffixCnt: Int) -> NSAttributedString {
        let attrStr = NSMutableAttributedString(string: dateStr, attributes: [NSFontAttributeName: Styles.smallBoldFont, NSForegroundColorAttributeName: Styles.whiteColor])
         attrStr.addAttribute(NSFontAttributeName, value: Styles.smallRegularFont, range: NSRange(location: attrStr.length - suffixCnt, length: suffixCnt))
        return attrStr
    }
    
    private func updateDateLabels() {
        let df = NSDateFormatter()
        df.dateFormat = "MMM d, yyyy"
        date1Label.attributedText = boldFirstPartOfDateString(df.stringFromDate(eventTime), suffixCnt: 6)
        df.dateFormat = "h:mm a"
        date2Label.attributedText = boldFirstPartOfDateString(df.stringFromDate(eventTime), suffixCnt: 2)
    }

    private func configureDateView() {
        updateDateLabels()
        datePicker.date = eventTime
        datePickerView.hidden = true
    }

    // UIKeyboardWillShowNotification
    func keyboardWillShow(notification: NSNotification) {
        // adjust save button up when keyboard is up
        let keyboardFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        viewAdjustAnimationTime = notification.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! Float
        self.configureSaveViewPosition(keyboardFrame.height)
    }
    
    // UIKeyboardWillHideNotification
    func keyboardWillHide(notification: NSNotification) {
        // reposition save button view if needed
        self.configureSaveViewPosition(0.0)
    }

    //
    // MARK: - Button and text field handlers
    //
    
    @IBAction func titleTextLargeHitAreaButton(sender: AnyObject) {
        titleTextField.becomeFirstResponder()
    }
    
    func textFieldDidChange() {
        updateSaveButtonState()
    }
    
    @IBAction func titleEditingDidBegin(sender: AnyObject) {
        hideDateIfOpen()
        configureTitleHint()
        if titleTextField.text == Styles.placeholderTitleString {
            titleTextField.text = ""
        }
    }
    
    @IBAction func titleEditingDidEnd(sender: AnyObject) {
        updateSaveButtonState()
        configureTitleHint()
        if titleTextField.text == "" {
            titleTextField.text = Styles.placeholderTitleString
        }
    }

    @IBAction func notesTextLargeHitAreaButton(sender: AnyObject) {
        notesTextField.becomeFirstResponder()
    }

    @IBAction func notesEditingDidBegin(sender: AnyObject) {
        hideDateIfOpen()
        configureNotesHint()
        if notesTextField.text == Styles.placeholderNotesString {
            notesTextField.text = ""
        }
    }
    
    @IBAction func notesEditingDidEnd(sender: AnyObject) {
        updateSaveButtonState()
        configureNotesHint()
        if notesTextField.text == "" {
            notesTextField.text = Styles.placeholderNotesString
        }
    }
    
    @IBAction func locationButtonHandler(sender: AnyObject) {
        locationTextField.becomeFirstResponder()
    }
    
    @IBAction func locationEditingDidBegin(sender: AnyObject) {
        hideDateIfOpen()
        if locationTextField.text == Styles.placeholderLocationString {
            locationTextField.text = ""
        }
    }
    
    @IBAction func locationEditingDidEnd(sender: AnyObject) {
        updateSaveButtonState()
        locationTextField.resignFirstResponder()
        if locationTextField.text == "" {
            locationTextField.text = Styles.placeholderLocationString
        }
    }

    @IBAction func saveButtonHandler(sender: AnyObject) {
        
        if viewExistingEvent {
            updateCurrentEvent()
            self.performSegueWithIdentifier("unwindSegueToDone", sender: self)
            return
        } else {
            updateNewEvent()
        }
        
    }

    @IBAction func backButtonHandler(sender: AnyObject) {
        // this is a cancel for the role of addEvent and editEvent
        // for viewEvent, we need to check whether the title has changed
        if viewExistingEvent {
            // cancel of edit
            if existingEventChanged() {
                alertOnCancelAndReturn(NSLocalizedString("discardEditsAlertTitle", comment:"Discard changes?"), alertMessage: NSLocalizedString("discardEditsAlertMessage", comment:"If you press discard, your changes to this meal will be lost."))
            } else {
                self.performSegueWithIdentifier("unwindSegueToCancel", sender: self)
            }
        } else {
            // cancel of add
            if newEventChanged() {
                alertOnCancelAndReturn(NSLocalizedString("discardMealAlertTitle", comment:"Discard meal?"), alertMessage: NSLocalizedString("closeMealAlertMessage", comment:"If you close this meal, your meal will be lost."))
            } else {
                self.performSegueWithIdentifier("unwindSegueToCancel", sender: self)
            }
        }
    }
    
    @IBAction func deleteButtonHandler(sender: AnyObject) {
        // this is a delete for the role of editEvent
        if let eventItem = eventItem, eventGroup = eventGroup {
            alertOnDeleteAndReturn(eventItem, nutEvent: eventGroup)
        }
    }
    
    private func pictureUrlEmptySlots() -> Int {
        return 3 - pictureImageURLs.count
    }

    private func itemToImageUrl(itemNum: Int) -> String {
        if itemNum >= pictureImageURLs.count {
            return ""
        } else {
            return pictureImageURLs[itemNum]
        }
    }
    
    private func itemToPicture(itemNum: Int) -> UIImageView {
        switch itemNum {
        case 0:
            return picture0Image
        case 1:
            return picture1Image
        case 2:
            return picture2Image
        default:
            NSLog("Error: asking for out of range picture image!")
            return picture0Image
        }
    }
    
    private func appendPictureUrl(url: String) {
        if pictureImageURLs.count < 3 {
            pictureImageURLs.append(url)
        }
    }

    private func showPicture(itemNum: Int) {
        let pictureUrl = itemToImageUrl(itemNum)
        if !pictureUrl.isEmpty {
            let storyboard = UIStoryboard(name: "EventView", bundle: nil)
            let photoVC = storyboard.instantiateViewControllerWithIdentifier("ShowPhotoViewController") as! ShowPhotoViewController
            photoVC.photoURLs = pictureImageURLs
            photoVC.imageIndex = itemNum
            photoVC.editAllowed = true
            editingPictureItem = itemNum
            self.navigationController?.pushViewController(photoVC, animated: true)
        }
    }
    
    @IBAction func picture0ButtonHandler(sender: AnyObject) {
        showPicture(0)
    }
    
    @IBAction func picture1ButtonHandler(sender: AnyObject) {
        showPicture(1)
    }

    @IBAction func picture2ButtonHandler(sender: AnyObject) {
        showPicture(2)
    }

    @IBAction func photoButtonHandler(sender: AnyObject) {
        if pictureUrlEmptySlots() == 0 {
            simpleInfoAlert(NSLocalizedString("photoSlotsFullTitle", comment:"No empty photo slot"), alertMessage: NSLocalizedString("photoSlotsFullMessage", comment:"Three photos are supported. Please discard one before adding a new photo."))
        } else {
            let pickerC = UIImagePickerController()
            pickerC.delegate = self
            self.presentViewController(pickerC, animated: true, completion: nil)
        }
    }

    //
    // MARK: - UIImagePickerControllerDelegate
    //
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        self.dismissViewControllerAnimated(true, completion: nil)
        print(info)
        
        if let photoUrl = info[UIImagePickerControllerReferenceURL] as? NSURL {
            appendPictureUrl(photoUrl.absoluteString)
            updateSaveButtonState()
            configurePhotos()
        }
    }
    
    //
    // MARK: - Event updating
    //

    private func newEventChanged() -> Bool {
        if let _ = eventGroup {
            // for "eat again" new events, we already have a title and location from the NutEvent, so consider this "changed"
            return true
        }
        if titleTextField.text != Styles.placeholderTitleString {
            return true
        }
        if locationTextField.text != Styles.placeholderLocationString {
            return true
        }
        if notesTextField.text != Styles.placeholderNotesString {
            return true
        }
        if !pictureImageURLs.isEmpty {
            return true
        }
        return false
    }

    private func existingEventChanged() -> Bool {
        if let eventItem = eventItem {
            if eventItem.title != titleTextField.text {
                NSLog("title changed, enabling save")
                return true
            }
            if eventItem.notes != notesTextField.text {
                NSLog("notes changed, enabling save")
                return true
            }
            if eventItem.time != eventTime {
                NSLog("event time changed, enabling save")
                return true
            }
            if let meal = eventItem as? NutMeal {
                if meal.location != locationTextField.text && locationTextField.text != Styles.placeholderLocationString {
                    NSLog("location changed, enabling save")
                    return true
                }
                if meal.photo != itemToImageUrl(0) {
                NSLog("photo1 changed, enabling save")
                   return true
                }
                if meal.photo2 != itemToImageUrl(1) {
                    NSLog("photo2 changed, enabling save")
                    return true
                }
                if meal.photo3 != itemToImageUrl(2) {
                    NSLog("photo3 changed, enabling save")
                    return true
                }
           }
       }
        return false
    }
    
    private func filteredLocationText() -> String {
        var location = ""
        if let locationText = locationTextField.text {
            if locationText != Styles.placeholderLocationString {
                location = locationText
            }
        }
        return location
    }

    private func filteredNotesText() -> String {
        var notes = ""
        if let notesText = notesTextField.text {
            if notesText != Styles.placeholderNotesString {
                notes =  notesText
            }
        }
        return notes
    }

    private func updateCurrentEvent() {
        
        // TODO: workout support! Allow editing workout items as well!
        if let mealItem = eventItem as? NutMeal {
            
            let location = filteredLocationText()
            let notes = filteredNotesText()

            mealItem.title = titleTextField.text!
            mealItem.time = eventTime
            mealItem.notes = notes
            mealItem.location = location
            mealItem.photo = itemToImageUrl(0)
            mealItem.photo2 = itemToImageUrl(1)
            mealItem.photo3 = itemToImageUrl(2)
            
             // Save the database
            if mealItem.saveChanges() {
                // note event changed as "new" event
                newEventItem = mealItem.eventItem
                updateItemAndGroupForNewEventItem()
            } else {
                newEventItem = nil
            }
        }
    }

    private func updateNewEvent() {
        if titleTextField.text!.localizedCaseInsensitiveCompare("testmode") == NSComparisonResult.OrderedSame  {
            AppDelegate.testMode = !AppDelegate.testMode
            self.performSegueWithIdentifier("unwindSequeToEventList", sender: self)
            return
        }

        // This is a good place to splice in demo and test data. For now, entering "demo" as the title will result in us adding a set of demo events to the model, and "delete" will delete all food events.
        if titleTextField.text!.localizedCaseInsensitiveCompare("demo") == NSComparisonResult.OrderedSame {
            DatabaseUtils.deleteAllNutEvents()
            addDemoData()
            self.performSegueWithIdentifier("unwindSequeToEventList", sender: self)
            return
        } else if titleTextField.text!.localizedCaseInsensitiveCompare("nodemo") == NSComparisonResult.OrderedSame {
            DatabaseUtils.deleteAllNutEvents()
            self.performSegueWithIdentifier("unwindSequeToEventList", sender: self)
            return
        }
        
        newEventItem = NutEvent.createMealEvent(titleTextField.text!, notes: filteredNotesText(), location: filteredLocationText(), photo: itemToImageUrl(0), photo2: itemToImageUrl(1), photo3: itemToImageUrl(2), time: eventTime)
        
        if newEventItem != nil {
            updateItemAndGroupForNewEventItem()
            showSuccessView()
        } else {
            // TODO: handle internal error...
            NSLog("Error: Failed to save new event!")
        }
    }

    private func updateItemAndGroupForNewEventItem() {
        // Update eventGroup and eventItem based on new event created, for return values to calling VC
        if let eventGroup = eventGroup, newEventItem = newEventItem {
            if newEventItem.nutEventIdString() == eventGroup.nutEventIdString() {
                if let currentItem = eventItem {
                    // if we're editing an existing item...
                    if currentItem.nutEventIdString() == eventGroup.nutEventIdString() {
                        // if title/location haven't changed, we're done...
                        return
                    }
                }
                self.eventItem = eventGroup.addEvent(newEventItem)
            } else {
                // eventGroup is no longer valid, create a new one!
                self.eventGroup = NutEvent(firstEvent: newEventItem)
                self.eventItem = self.eventGroup?.itemArray[0]
            }
        }
        
    }
    
    private func deleteItemAndReturn(eventItem: NutEventItem, eventGroup: NutEvent) {
        if eventItem.deleteItem() {
            // now remove it from the group
            eventGroup.itemArray = eventGroup.itemArray.filter() {
                $0 != eventItem
            }
            // segue back to group or list, depending...
            if eventGroup.itemArray.isEmpty {
                self.performSegueWithIdentifier("unwindSequeToEventList", sender: self)
            } else {
                self.performSegueWithIdentifier("unwindSequeToEventGroup", sender: self)
            }
        }
        // TODO: handle delete error?
        NSLog("Error: Failed to delete item!")
    }
    
    //
    // MARK: - Alerts
    //
    
    private func simpleInfoAlert(alertTitle: String, alertMessage: String) {
        // use dialog to confirm cancel with user!
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("notifyAlertOkay", comment:"OK"), style: .Cancel, handler: { Void in
            return
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
   
    private func alertOnCancelAndReturn(alertTitle: String, alertMessage: String) {
        // use dialog to confirm cancel with user!
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("discardAlertCancel", comment:"Cancel"), style: .Cancel, handler: { Void in
            return
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("discardAlertOkay", comment:"Discard"), style: .Default, handler: { Void in
            self.performSegueWithIdentifier("unwindSegueToCancel", sender: self)
            self.dismissViewControllerAnimated(true, completion: nil)
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    private func alertOnDeleteAndReturn(nutItem: NutEventItem, nutEvent: NutEvent) {
        // use dialog to confirm delete with user!
        let alert = UIAlertController(title: NSLocalizedString("discardMealAlertTitle", comment:"Discard meal?"), message: NSLocalizedString("discardMealAlertMessage", comment:"If you discard this meal, your meal will be lost."), preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("discardAlertCancel", comment:"Cancel"), style: .Cancel, handler: { Void in
            return
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("discardAlertOkay", comment:"Discard"), style: .Default, handler: { Void in
            self.deleteItemAndReturn(nutItem, eventGroup: nutEvent)
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }

    //
    // MARK: - Misc private funcs
    //
    
    private func showSuccessView() {
        titleTextField.resignFirstResponder()
        notesTextField.resignFirstResponder()
        locationTextField.resignFirstResponder()
        
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
            if let newEventItem = self.newEventItem, eventGroup = self.eventGroup {
                if newEventItem.nutEventIdString() != eventGroup.nutEventIdString() {
                    self.performSegueWithIdentifier("unwindSequeToEventList", sender: self)
                    return
                }
            }
            self.performSegueWithIdentifier("unwindSegueToDone", sender: self)
        }
    }
    
    //
    // MARK: - Date picking
    //
    
    private var savedTime: NSDate?
    @IBAction func dateButtonHandler(sender: AnyObject) {
        // user tapped on date, bring up date picker
        datePickerView.hidden = !datePickerView.hidden
        if !datePickerView.hidden {
            titleTextField.resignFirstResponder()
            notesTextField.resignFirstResponder()
            locationTextField.resignFirstResponder()
            savedTime = eventTime
        }
    }
    
    @IBAction func cancelDatePickButtonHandler(sender: AnyObject) {
        if let savedTime = savedTime {
            eventTime = savedTime
        }
        configureDateView()
    }
    
    @IBAction func doneDatePickButtonHandler(sender: AnyObject) {
        eventTime = datePicker.date
        configureDateView()
        updateSaveButtonState()
    }
    
    @IBAction func datePickerValueChanged(sender: AnyObject) {
        eventTime = datePicker.date
        updateDateLabels()
    }
    //
    // MARK: - Test code!
    //
    
    private func addDemoData() {
        
        let demoMeals = [
            ["Three tacos", "with 15 chips & salsa", "2015-08-20T10:03:21.000Z", "238 Garrett St", "ThreeTacosDemoPic"],
            ["Three tacos", "after ballet", "2015-08-09T19:42:40.000Z", "238 Garrett St", "applejuicedemopic"],
            ["Three tacos", "Apple Juice before", "2015-07-29T04:55:27.000Z", "238 Garrett St", "applejuicedemopic"],
            ["Three tacos", "and horchata", "2015-07-28T14:25:21.000Z", "238 Garrett St", "applejuicedemopic"],
            ["CPK 5 cheese margarita", "", "2015-07-27T12:25:21.000Z", "", ""],
            ["Bagel & cream cheese fruit", "", "2015-07-27T16:25:21.000Z", "", ""],
            ["Birthday Party", "", "2015-07-26T14:25:21.000Z", "", ""],
            ["This is a meal with a very long title that should wrap onto multiple lines in most devices", "And these are notes about this meal, which are also very long and should certainly wrap as well. It might be more usual to see long notes!", "2015-07-26T14:25:21.000Z", "This is a long place name, something like Taco Place at 238 Garrett St, San Francisco, California", ""],
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
            me.id = "demo" + NSUUID().UUIDString // required!
            me.userid = NutDataController.controller().currentUserId // required!
            let now = NSDate()
            me.createdTime = now
            me.modifiedTime = now
        }
        
        let demoWorkouts = [
            ["Runs", "regular 3 mile", "2015-07-28T12:25:21.000Z", "6000"],
            ["Workout", "running in park", "2015-07-27T04:23:20.000Z", "2100"],
            ["Workout", "running around the neighborhood", "2015-07-24T02:43:20.000Z", "2100"],
            ["Workout", "running at Rancho San Antonio", "2015-07-21T03:53:20.000Z", "2100"],
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
            we.id = "demo" + NSUUID().UUIDString // required!
            we.userid = NutDataController.controller().currentUserId // required!
            let now = NSDate()
            we.createdTime = now
            we.modifiedTime = now
        }
        
        let moc = NutDataController.controller().mocForNutEvents()!
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
        DatabaseUtils.databaseSave(moc)
    }
}

