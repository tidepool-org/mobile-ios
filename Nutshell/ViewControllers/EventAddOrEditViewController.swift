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
import MobileCoreServices

class EventAddOrEditViewController: BaseUIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    var eventItem: NutEventItem?
    var eventGroup: NutEvent?
    var newEventItem: EventItem?
    private var editExistingEvent = false
    private var isWorkout: Bool = false
    
    @IBOutlet weak var titleTextField: NutshellUITextField!
    @IBOutlet weak var titleHintLabel: NutshellUILabel!
    @IBOutlet weak var notesTextField: NutshellUITextField!
    @IBOutlet weak var notesHintLabel: NutshellUILabel!
    
    @IBOutlet weak var placeIconButton: UIButton!
    @IBOutlet weak var photoIconButton: UIButton!
    @IBOutlet weak var calendarIconButton: UIButton!
    
    @IBOutlet weak var placeControlContainer: UIView!
    @IBOutlet weak var calendarControlContainer: UIView!
    @IBOutlet weak var photoControlContainer: UIView!
    
    @IBOutlet weak var workoutCalorieContainer: UIView!
    @IBOutlet weak var caloriesLabel: NutshellUILabel!
    
    @IBOutlet weak var workoutDurationContainer: UIView!
    @IBOutlet weak var durationLabel: NutshellUILabel!
    
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
    // Note: time zone offset is only used for display; new items are always created with the offset for the current calendar time zone, and time zones are not editable!
    private var eventTimeOffsetSecs: Int = 0
    private var pictureImageURLs: [String] = []

    @IBOutlet weak var bottomSectionContainer: UIView!
    //
    // MARK: - Base methods
    //

    override func viewDidLoad() {
        super.viewDidLoad()
        var saveButtonTitle = NSLocalizedString("saveButtonTitle", comment:"Save")
        if let eventItem = eventItem {
            editExistingEvent = true
            eventTime = eventItem.time
            eventTimeOffsetSecs = eventItem.tzOffsetSecs

            // hide location and photo controls for workouts
            if let workout = eventItem as? NutWorkout {
                isWorkout = true
                placeControlContainer.hidden = true
                photoControlContainer.hidden = true
                if workout.duration > 0 {
                    workoutDurationContainer.hidden = false
                    let dateComponentsFormatter = NSDateComponentsFormatter()
                    dateComponentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyle.Abbreviated
                    durationLabel.text = dateComponentsFormatter.stringFromTimeInterval(workout.duration)
                }
                if let calories = workout.calories {
                    if Int(calories) > 0 {
                        workoutCalorieContainer.hidden = false
                        caloriesLabel.text = String(Int(calories)) + " Calories"
                    }
                }
            }

            // hide modal header when used as a nav view
            for c in headerForModalView.constraints {
                if c.firstAttribute == NSLayoutAttribute.Height {
                    c.constant = 0.0
                    break
                }
            }
        }  else  {
            eventTimeOffsetSecs = NSCalendar.currentCalendar().timeZone.secondsFromGMT
            locationTextField.text = Styles.placeholderLocationString
            saveButtonTitle = NSLocalizedString("saveAndEatButtonTitle", comment:"Save and eat!")
        }
        saveButton.setTitle(saveButtonTitle, forState: UIControlState.Normal)
        configureInfoSection()
        titleHintLabel.text = Styles.titleHintString
        notesHintLabel.text = Styles.noteHintString
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(EventAddOrEditViewController.textFieldDidChange), name: UITextFieldTextDidChangeNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(EventAddOrEditViewController.keyboardWillShow(_:)), name: UIKeyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(EventAddOrEditViewController.keyboardWillHide(_:)), name: UIKeyboardWillHideNotification, object: nil)
    }

    deinit {
        let nc = NSNotificationCenter.defaultCenter()
        nc.removeObserver(self, name: nil, object: nil)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        APIConnector.connector().trackMetric("Viewed Edit Screen (Edit Screen)")
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

                // handle the case of a new photo replacing a new (not yet saved) photo: the older one should be immediately deleted since will be no reference to it left!
                for url in pictureImageURLs {
                    if !preExistingPhoto(url) {
                        if !photoVC.photoURLs.contains(url) {
                            NutUtils.deleteLocalPhoto(url)
                        }
                    }
                }
                // new pending list of photos...
                pictureImageURLs = photoVC.photoURLs
                configurePhotos()
                updateSaveButtonState()
            }
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
                // Add workout-specific items...
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
        if !datePickerView.hidden {
            saveButton.hidden = true
            return
        }
        if editExistingEvent {
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
            cancelDatePickButtonHandler(self)
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
        // Note: Time zones created with this method never have daylight savings, and the offset is constant no matter the date
        df.timeZone = NSTimeZone(forSecondsFromGMT:eventTimeOffsetSecs)
        df.dateFormat = "MMM d, yyyy"
        date1Label.attributedText = boldFirstPartOfDateString(df.stringFromDate(eventTime), suffixCnt: 6)
        df.dateFormat = "h:mm a"
        date2Label.attributedText = boldFirstPartOfDateString(df.stringFromDate(eventTime), suffixCnt: 2)
    }

    private func configureDateView() {
        updateDateLabels()
        datePicker.date = eventTime
        // Note: Time zones created with this method never have daylight savings, and the offset is constant no matter the date
        datePicker.timeZone = NSTimeZone(forSecondsFromGMT: eventTimeOffsetSecs)
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
    
    @IBAction func dismissKeyboard(sender: AnyObject) {
        titleTextField.resignFirstResponder()
        notesTextField.resignFirstResponder()
        locationTextField.resignFirstResponder()
        hideDateIfOpen()
    }
    
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
        if editExistingEvent {
            APIConnector.connector().trackMetric("Edited Meal Name (Edit Screen)")
        } else {
            APIConnector.connector().trackMetric("Clicked to Add Meal Name (Add Meal Screen)")
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
        if editExistingEvent {
            APIConnector.connector().trackMetric("Edited Notes (Edit Screen)")
        } else {
            APIConnector.connector().trackMetric("Clicked to Add Notes (Add Meal Screen)")
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
        if editExistingEvent {
            APIConnector.connector().trackMetric("Edited Location (Edit Screen)")
        } else {
            APIConnector.connector().trackMetric("Clicked to Add Location (Add Meal Screen)")
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
        
        if editExistingEvent {
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
        if editExistingEvent {
            // cancel of edit
            APIConnector.connector().trackMetric("Clicked Cancel (Edit Screen)")
            if existingEventChanged() {
                var alertString = NSLocalizedString("discardMealEditsAlertMessage", comment:"If you press discard, your changes to this meal will be lost.")
                if let _ = eventItem as? NutWorkout {
                    alertString = NSLocalizedString("discardWorkoutEditsAlertMessage", comment:"If you press discard, your changes to this workout will be lost.")
                }
                alertOnCancelAndReturn(NSLocalizedString("discardEditsAlertTitle", comment:"Discard changes?"), alertMessage: alertString, okayButtonString: NSLocalizedString("discardAlertOkay", comment:"Discard"))
            } else {
                self.performSegueWithIdentifier("unwindSegueToCancel", sender: self)
            }
        } else {
            // cancel of add
            APIConnector.connector().trackMetric("Clicked ‘X’ to Close (Add Screen)")
            if newEventChanged() {
                var alertTitle = NSLocalizedString("deleteMealAlertTitle", comment:"Are you sure?")
                var alertMessage = NSLocalizedString("deleteMealAlertMessage", comment:"If you delete this meal, it will be gone forever.")
                if let _ = eventItem as? NutWorkout {
                    alertTitle = NSLocalizedString("deleteWorkoutAlertTitle", comment:"Discard workout?")
                    alertMessage = NSLocalizedString("deleteWorkoutAlertMessage", comment:"If you close this workout, your workout will be lost.")
                }
                alertOnCancelAndReturn(alertTitle, alertMessage: alertMessage, okayButtonString: NSLocalizedString("deleteAlertOkay", comment:"Delete"))
            } else {
                self.performSegueWithIdentifier("unwindSegueToCancel", sender: self)
            }
        }
    }
    
    @IBAction func deleteButtonHandler(sender: AnyObject) {
        // this is a delete for the role of editEvent
        APIConnector.connector().trackMetric("Clicked Trashcan to Discard (Edit Screen)")
        alertOnDeleteAndReturn()
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
            if !editExistingEvent {
                switch pictureImageURLs.count {
                case 1: APIConnector.connector().trackMetric("First Photo Added (Add Meal Screen)")
                case 2: APIConnector.connector().trackMetric("Second Photo Added (Add Meal Screen)")
                case 3: APIConnector.connector().trackMetric("Third Photo Added (Add Meal Screen)")
                default: break
                }
            }
        }
    }

    private func showPicture(itemNum: Int) -> Bool {
        let pictureUrl = itemToImageUrl(itemNum)
        if !pictureUrl.isEmpty {
            if editExistingEvent {
                APIConnector.connector().trackMetric("Clicked Photos (Edit Screen)")
            }
            let storyboard = UIStoryboard(name: "EventView", bundle: nil)
            let photoVC = storyboard.instantiateViewControllerWithIdentifier("ShowPhotoViewController") as! ShowPhotoViewController
            photoVC.photoURLs = pictureImageURLs
            photoVC.mealTitle = titleTextField.text
            photoVC.imageIndex = itemNum
            photoVC.editAllowed = true
            if editExistingEvent {
                self.navigationController?.pushViewController(photoVC, animated: true)
            } else {
                photoVC.modalPresentation = true
                self.presentViewController(photoVC, animated: true, completion: nil)
            }
            return true
        } else {
            return false
        }
    }
    
    @IBAction func picture0ButtonHandler(sender: AnyObject) {
        if !showPicture(0) {
            photoButtonHandler(sender)
        }
    }
    
    @IBAction func picture1ButtonHandler(sender: AnyObject) {
        if !showPicture(1) {
            photoButtonHandler(sender)
        }
    }

    @IBAction func picture2ButtonHandler(sender: AnyObject) {
        if !showPicture(2) {
            photoButtonHandler(sender)
        }
    }

    @IBAction func photoButtonHandler(sender: AnyObject) {
        if pictureUrlEmptySlots() == 0 {
            simpleInfoAlert(NSLocalizedString("photoSlotsFullTitle", comment:"No empty photo slot"), alertMessage: NSLocalizedString("photoSlotsFullMessage", comment:"Three photos are supported. Please discard one before adding a new photo."))
        } else {
            if !editExistingEvent {
                switch pictureImageURLs.count {
                case 0: APIConnector.connector().trackMetric("Clicked to Add First Photo (Add Meal Screen)")
                case 1: APIConnector.connector().trackMetric("Clicked to Add Second Photo (Add Meal Screen)")
                case 2: APIConnector.connector().trackMetric("Clicked to Add Third Photo (Add Meal Screen)")
                default: break
                }
            }
            showPhotoActionSheet()
        }
    }

    func showPhotoActionSheet() {
        let photoActionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        photoActionSheet.modalPresentationStyle = .Popover

        photoActionSheet.addAction(UIAlertAction(title: NSLocalizedString("discardAlertCancel", comment:"Cancel"), style: .Cancel, handler: { Void in
            return
        }))

        photoActionSheet.addAction(UIAlertAction(title: "Photo Library", style: .Default, handler: { Void in
            let pickerC = UIImagePickerController()
            pickerC.delegate = self
            self.presentViewController(pickerC, animated: true, completion: nil)
        }))
        
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera) {
            photoActionSheet.addAction(UIAlertAction(title: "Take Photo", style: .Default, handler: { Void in
                let pickerC = UIImagePickerController()
                pickerC.delegate = self
                pickerC.sourceType = UIImagePickerControllerSourceType.Camera
                pickerC.mediaTypes = [kUTTypeImage as String]
                self.presentViewController(pickerC, animated: true, completion: nil)
            }))
        }
        
        if let popoverController = photoActionSheet.popoverPresentationController {
            popoverController.sourceView = self.photoIconButton
            popoverController.sourceRect = self.photoIconButton.bounds
        }
        
        self.presentViewController(photoActionSheet, animated: true, completion: nil)
    }

    //
    // MARK: - UIImagePickerControllerDelegate
    //
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        self.dismissViewControllerAnimated(true, completion: nil)
        print(info)
        
        if let photoImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            //let compressedImage = NutUtils.compressImage(photoImage)
            let photoUrl = NutUtils.urlForNewPhoto()
            if let filePath = NutUtils.filePathForPhoto(photoUrl) {
                // NOTE: we save photo with high compression, typically 0.2 to 0.4 MB
                if let photoData = UIImageJPEGRepresentation(photoImage, 0.1) {
                    let savedOk = photoData.writeToFile(filePath, atomically: true)
                    if !savedOk {
                        NSLog("Failed to save photo successfully!")
                    }
                    appendPictureUrl(photoUrl)
                    updateSaveButtonState()
                    configurePhotos()
                }
            }
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
            if eventItem.notes != notesTextField.text && notesTextField.text != Styles.placeholderNotesString {
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
        
        if let mealItem = eventItem as? NutMeal {
            
            let location = filteredLocationText()
            let notes = filteredNotesText()

            mealItem.title = titleTextField.text!
            mealItem.time = eventTime
            mealItem.notes = notes
            mealItem.location = location
            
            // first delete any photos going away...
            for url in mealItem.photoUrlArray() {
                if !pictureImageURLs.contains(url) {
                    NutUtils.deleteLocalPhoto(url)
                }
            }
            // now update the event...
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
        } else if let workoutItem = eventItem as? NutWorkout {
            let location = filteredLocationText()
            let notes = filteredNotesText()
            
            workoutItem.title = titleTextField.text!
            workoutItem.time = eventTime
            workoutItem.notes = notes
            workoutItem.location = location

            // Save the database
            if workoutItem.saveChanges() {
                // note event changed as "new" event
                newEventItem = workoutItem.eventItem
                updateItemAndGroupForNewEventItem()
            } else {
                newEventItem = nil
            }
        }
    }

    var crashValue: String?
    func testCrash() {
        // force crash to test crash reporting...
        if crashValue! == "crash" {
            self.performSegueWithIdentifier("unwindSegueToHome", sender: self)
            return
        }
    }
    
    private func updateNewEvent() {
        if titleTextField.text!.localizedCaseInsensitiveCompare("test mode") == NSComparisonResult.OrderedSame  {
            AppDelegate.testMode = !AppDelegate.testMode
            self.performSegueWithIdentifier("unwindSegueToHome", sender: self)
            return
        }

        // This is a good place to splice in demo and test data. For now, entering "demo" as the title will result in us adding a set of demo events to the model, and "delete" will delete all food events.
        if titleTextField.text!.localizedCaseInsensitiveCompare("demo") == NSComparisonResult.OrderedSame {
            DatabaseUtils.deleteAllNutEvents()
            addDemoData()
            self.performSegueWithIdentifier("unwindSegueToHome", sender: self)
            return
        } else if titleTextField.text!.localizedCaseInsensitiveCompare("no demo") == NSComparisonResult.OrderedSame {
            DatabaseUtils.deleteAllNutEvents()
            self.performSegueWithIdentifier("unwindSegueToHome", sender: self)
            return
        } else if titleTextField.text!.localizedCaseInsensitiveCompare("kill token") == NSComparisonResult.OrderedSame {
            APIConnector.connector().sessionToken = "xxxx"
            self.performSegueWithIdentifier("unwindSegueToHome", sender: self)
            return
        }
        
        if titleTextField.text!.localizedCaseInsensitiveCompare("test crash") == NSComparisonResult.OrderedSame {
            self.testCrash()
        }
        
        // Note: we only create meal events in this app - workout events come from other apps via HealthKit...
        newEventItem = NutEvent.createMealEvent(titleTextField.text!, notes: filteredNotesText(), location: filteredLocationText(), photo: itemToImageUrl(0), photo2: itemToImageUrl(1), photo3: itemToImageUrl(2), time: eventTime, timeZoneOffset: eventTimeOffsetSecs)
        
        if newEventItem != nil {
            if eventGroup == nil {
                APIConnector.connector().trackMetric("New Meal Added (Add Meal Screen)")
            } else {
                APIConnector.connector().trackMetric("New Instance of Existing Meal (Add Meal Screen)")
            }
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
    
    private func preExistingPhoto(url: String) -> Bool {
        var preExisting = false
        // if we are editing a current event, don't delete the photo if it already exists in the event
        if let eventItem = eventItem {
            preExisting = eventItem.photoUrlArray().contains(url)
        }
        return preExisting
    }
    
    /// Delete new photos we may have created so we don't leave them orphaned in the local file system.
    private func deleteNewPhotos() {
        for url in pictureImageURLs {
            if !preExistingPhoto(url) {
                NutUtils.deleteLocalPhoto(url)
            }
        }
        pictureImageURLs = []
    }
    
    private func deleteItemAndReturn() {
        // first delete any new photos user may have added
        deleteNewPhotos()
        if let eventItem = eventItem, eventGroup = eventGroup {
            if eventItem.deleteItem() {
                // now remove it from the group
                eventGroup.itemArray = eventGroup.itemArray.filter() {
                    $0 != eventItem
                }
                
                // mark it as deleted so controller we return to can handle correctly...
                self.eventItem = nil
                if eventGroup.itemArray.isEmpty {
                    self.eventGroup = nil
                    // segue back to home as there are no events remaining...
                    self.performSegueWithIdentifier("unwindSegueToHome", sender: self)
               } else {
                    // segue back to home or group list viewer depending...
                    self.performSegueWithIdentifier("unwindSegueToDoneItemDeleted", sender: self)
                }
            } else {
                // TODO: handle delete error?
                NSLog("Error: Failed to delete item!")
                // segue back to home as this event probably was deleted out from under us...
                self.performSegueWithIdentifier("unwindSegueToHome", sender: self)
            }
        }
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
   
    private func alertOnCancelAndReturn(alertTitle: String, alertMessage: String, okayButtonString: String) {
        // use dialog to confirm cancel with user!
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("discardAlertCancel", comment:"Cancel"), style: .Cancel, handler: { Void in
            if self.editExistingEvent {
                APIConnector.connector().trackMetric("Clicked Cancel Cancel to Stay on Edit (Edit Screen)")
            }
            return
        }))
        alert.addAction(UIAlertAction(title: okayButtonString, style: .Default, handler: { Void in
            if self.editExistingEvent {
                APIConnector.connector().trackMetric("Clicked Discard Changes to Cancel (Edit Screen)")
            }
            self.deleteNewPhotos()
            self.performSegueWithIdentifier("unwindSegueToCancel", sender: self)
            self.dismissViewControllerAnimated(true, completion: nil)
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    private func alertOnDeleteAndReturn() {
        if let nutItem = eventItem {
            // use dialog to confirm delete with user!
            var titleString = NSLocalizedString("deleteMealAlertTitle", comment:"Are you sure?")
            var messageString = NSLocalizedString("deleteMealAlertMessage", comment:"If you delete this meal, it will be gone forever..")
            if let _ = nutItem as? NutWorkout {
                titleString = NSLocalizedString("deleteWorkoutAlertTitle", comment:"Are you sure?")
                messageString = NSLocalizedString("deleteWorkoutAlertMessage", comment:"If you delete this workout, it will be gone forever.")
            }
            
            let alert = UIAlertController(title: titleString, message: messageString, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("deleteAlertCancel", comment:"Cancel"), style: .Cancel, handler: { Void in
                APIConnector.connector().trackMetric("Clicked Cancel Discard (Edit Screen)")
                return
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("deleteAlertOkay", comment:"Delete"), style: .Default, handler: { Void in
                APIConnector.connector().trackMetric("Clicked Confirmed Delete (Edit Screen)")
                self.deleteItemAndReturn()
            }))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }

    //
    // MARK: - Misc private funcs
    //
    
    private func showSuccessView() {
        dismissKeyboard(self)
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
                    self.performSegueWithIdentifier("unwindSegueToHome", sender: self)
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
        if datePickerView.hidden {
            dismissKeyboard(self)
            datePickerView.hidden = false
            savedTime = eventTime
            updateSaveButtonState()
            if editExistingEvent {
                APIConnector.connector().trackMetric("Edited Datetime (Edit Screen)")
            } else {
                APIConnector.connector().trackMetric("Clicked to Update Datetime (Add Meal Screen)")
            }
        } else {
            cancelDatePickButtonHandler(self)
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
        
        // Note: for new events, if the user creates a time in the past that crosses a daylight savings time zone boundary, we want to adjust the time zone offset from the local one, ASSUMING THE USER IS EDITING IN THE SAME TIME ZONE IN WHICH THEY HAD THE MEAL. 
        // Without this adjustment, they would create the time in the past, say at 9 pm, and return to the meal view and see it an hour different, because we show event times in the UI in the time zone offset in which the event is created.
        // This is the one case we are basically allowing an event to be created in a different time zone offset from the present: if we provided a UI to allow the user to select a time zone, this might be handled more easily.
        // We truly only know the actual time zone of meals when they are created and their times are not edited (well, unless they are on a plane): allowing this edit, while practical, does put in some question the actual time zone of the event! What is key is the GMT time since that is what will be used to show the meal relatively to the blood glucose and insulin events.
        if !editExistingEvent {
            let dstAdjust = NutUtils.dayLightSavingsAdjust(datePicker.date)
            eventTimeOffsetSecs = NSCalendar.currentCalendar().timeZone.secondsFromGMT + dstAdjust
        }
        
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
    
    // TODO: Move to NutshellTests!
    
    private func addDemoData() {
        
        let demoMeals = [
            // brandon account
            ["Extended Bolus", "100% extended", "2015-10-30T03:03:00.000Z", "brandon", ""],
            ["Extended Bolus", "2% extended", "2015-10-31T08:08:00.000Z", "brandon", ""],
            ["Extended Bolus", "various extended", "2015-10-29T03:08:00.000Z", "brandon", ""],
            ["Extended Bolus", "various extended", "2015-10-28T21:00:00.000Z", "brandon", ""],
            ["Temp Basal", "Higher than scheduled", "2015-12-14T18:57:00.000Z", "brandon", ""],
            ["Temp Basal", "Shift in scheduled during temp", "2015-12-16T05:00:00.000Z", "brandon", ""],
            ["Interrupted Bolus", "Both regular and extended", "2015-11-17T04:00:00.000Z", "brandon", ""],
            ["Interrupted Bolus", "Extended, only 2%", "2015-10-11T08:00:00.000Z", "brandon", ""],
            ["Interrupted Bolus", "Extended, 63% delivered", "2015-10-10T04:00:00.000Z", "brandon", ""],
            // larry account
            ["Overridden Bolus", "Suggested .15, delivered 1, suggested .2, delivered 2.5", "2015-08-15T04:47:00.000Z", "larry", ""],
            ["Overridden Bolus", "Suggested 1.2, overrode to .6, suggested 1.2, overrode to .8", "2015-08-09T19:14:00.000Z", "larry", ""],
            ["Interrupted Bolus", "3.8 delivered, 4.0 expected", "2015-08-09T11:03:21.000Z", "larry", ""],
            ["Interrupted Bolus", "Two 60 wizard bolus events, 1.4 (expected 6.1), 2.95", "2015-05-27T03:03:21.000Z", "larry", ""],
            ["Interrupted Bolus", "2.45 delivered, 2.5 expected", "2014-06-26T06:45:21.000Z", "larry", ""],
            // Demo
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
            // TODO: really should specify time zone offset in the data so we can test some time zone related issues
            me.timezoneOffset = NSCalendar.currentCalendar().timeZone.secondsFromGMT/60
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
            we.timezoneOffset = NSCalendar.currentCalendar().timeZone.secondsFromGMT/60
        }
        
        let moc = NutDataController.controller().mocForNutEvents()!
        if let entityDescription = NSEntityDescription.entityForName("Meal", inManagedObjectContext: moc) {
            for event in demoMeals {
                let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Meal
                addMeal(me, event: event)
                moc.insertObject(me)
            }
        }
        
        if AppDelegate.healthKitUIEnabled {
            if let entityDescription = NSEntityDescription.entityForName("Workout", inManagedObjectContext: moc) {
                for event in demoWorkouts {
                    let we = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Workout
                    addWorkout(we, event: event)
                    moc.insertObject(we)
                }
            }
        }
        
        DatabaseUtils.databaseSave(moc)
    }
}

