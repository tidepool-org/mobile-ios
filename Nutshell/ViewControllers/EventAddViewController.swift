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
import CocoaLumberjack

class EventAddViewController: BaseUIViewController, UITextViewDelegate {

    @IBOutlet weak var sceneContainerView: NutshellUIView!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    // Global so it can be removed and added back at will
    let closeButton: UIBarButtonItem = UIBarButtonItem()
    
    // Current time and 'button' to change time
    let timedateLabel: UILabel = UILabel()
    let changeDateLabel: UILabel = UILabel()
    
    // datePicker and helpers for animation
    var datePickerShown: Bool = false
    var isAnimating: Bool = false
    let datePicker: UIDatePicker = UIDatePicker()
    private var previousDate: Date!
    
    // Separator between date/time and hashtags
    let separatorOne: UIView = UIView()
    
    // hashtagsView for putting hashtags in your messages
    let hashtagsScrollView = HashtagsScrollView()
    
    // Separator between hashtags and messageBox
    let separatorTwo: UIView = UIView()
    
    // UI Elements
    let messageBox: UITextView = UITextView()
    
    /*
     Post button sizing: 
     TODO: removed for now by making this zero height and changing some configuration...
     */
    let postButtonW: CGFloat = 112
    let postButtonH: CGFloat = 0

    let postButton: UIButton = UIButton()
    
    // Data
    // Group and user must be set by launching controller in prepareForSegue!
    var group: BlipUser!
    var user: BlipUser!
    // Returns newNote if successful
    var newNote: BlipNote? = nil

    private var note: BlipNote!
    
    // Keyboard frame for positioning UI Elements, initially zero
    var keyboardFrame: CGRect = CGRect.zero
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // data
        note = BlipNote()
        note.user = user
        note.groupid = group.userid
        note.messagetext = ""
        
        self.previousDate = datePicker.date

        // Set background color to light grey color
        self.sceneContainerView.backgroundColor = lightGreyColor
        
        // Add observers for notificationCenter to handle keyboard events
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(EventAddViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(EventAddViewController.keyboardDidShow(_:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(EventAddViewController.keyboardWillHide(_:)), name:NSNotification.Name.UIKeyboardWillHide, object: nil)
        // Add an observer to notificationCenter to handle hashtagPress events from HashtagsView
        notificationCenter.addObserver(self, selector: #selector(EventAddViewController.hashtagPressed(_:)), name: NSNotification.Name(rawValue: "hashtagPressed"), object: nil)
     }

     deinit {
        NotificationCenter.default.removeObserver(self)
     }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        messageBox.becomeFirstResponder()
    }
    
    // delay manual layout until we know actual size of container view (at viewDidLoad it will be the current storyboard size)
    private var subviewsInitialized = false
    override func viewDidLayoutSubviews() {
        let frame = self.sceneContainerView.frame
        NSLog("viewDidLayoutSubviews: \(frame)")
        
        if (subviewsInitialized) {
            return
        }
        subviewsInitialized = true

        configureTitleView()
        
        // configure date label
        let dateFormatter = DateFormatter()
        timedateLabel.attributedText = dateFormatter.attributedStringFromDate(note.timestamp)
        timedateLabel.sizeToFit()
        timedateLabel.frame.origin.x = labelInset
        timedateLabel.frame.origin.y = labelInset
        
        // configure change date label
        changeDateLabel.text = changeDateText
        changeDateLabel.font = smallRegularFont
        changeDateLabel.textColor = Styles.brightBlueColor
        changeDateLabel.sizeToFit()
        changeDateLabel.frame.origin.x = self.sceneContainerView.frame.width - (labelInset + changeDateLabel.frame.width)
        changeDateLabel.frame.origin.y = timedateLabel.frame.midY - changeDateLabel.frame.height / 2
        
        // Create a whole view to add the date label and change label to
        //      --> user can click anywhere in view to trigger change date animation
        let changeDateH = labelInset + timedateLabel.frame.height + labelInset
        let changeDateView = UIView(frame: CGRect(x: 0, y: 0, width: self.sceneContainerView.frame.width, height: changeDateH))
        changeDateView.backgroundColor = UIColor.clear
        // tapGesture in view triggers animation
        let tap = UITapGestureRecognizer(target: self, action: #selector(EventAddViewController.changeDatePressed(_:)))
        changeDateView.addGestureRecognizer(tap)
        // add labels to view
        changeDateView.addSubview(timedateLabel)
        changeDateView.addSubview(changeDateLabel)
        
        self.sceneContainerView.addSubview(changeDateView)
        
        // configure date picker
        datePicker.datePickerMode = .dateAndTime
        datePicker.frame.origin.x = 0
        datePicker.frame.origin.y = timedateLabel.frame.maxY + labelInset / 2
        datePicker.isHidden = true
        datePicker.addTarget(self, action: #selector(EventAddViewController.datePickerAction(_:)), for: .valueChanged)
        
        self.sceneContainerView.addSubview(datePicker)
        
        // configure first separator between date and hashtags
        separatorOne.backgroundColor = darkestGreyColor
        separatorOne.frame.size = CGSize(width: self.sceneContainerView.frame.size.width, height: 1)
        separatorOne.frame.origin.x = 0
        separatorOne.frame.origin.y = timedateLabel.frame.maxY + labelInset
        
        self.sceneContainerView.addSubview(separatorOne)
        
        // configure hashtags view --> begins with expanded height
        hashtagsScrollView.frame.size = CGSize(width: self.sceneContainerView.frame.width, height: expandedHashtagsViewH)
        hashtagsScrollView.frame.origin.x = 0
        hashtagsScrollView.frame.origin.y = separatorOne.frame.maxY
        hashtagsScrollView.configureHashtagsScrollView()
        
        self.sceneContainerView.addSubview(hashtagsScrollView)
        
        // configure second separator between hashtags and messageBox
        separatorTwo.backgroundColor = darkestGreyColor
        separatorTwo.frame.size = CGSize(width: self.sceneContainerView.frame.size.width, height: 1)
        separatorTwo.frame.origin.x = 0
        separatorTwo.frame.origin.y = hashtagsScrollView.frame.maxY
        
        self.sceneContainerView.addSubview(separatorTwo)
        
        // configure post button
        // TODO: with post/save button now in navigation bar, hide for now, and make zero height - eventually remove when all this goes to storyboard
        postButton.isHidden = true

        //        postButton.setAttributedTitle(NSAttributedString(string:postButtonText,
        //                                                         attributes:[NSForegroundColorAttributeName: postButtonTextColor, NSFontAttributeName: mediumRegularFont]), for: UIControlState())
        //        postButton.backgroundColor = Styles.brightBlueColor
        //        postButton.alpha = 0.5
        //        postButton.addTarget(self, action: #selector(EventAddViewController.postNote(_:)), for: .touchUpInside)
        postButton.frame.size = CGSize(width: postButtonW, height: postButtonH)
        postButton.frame.origin.x = self.sceneContainerView.frame.size.width - (labelInset + postButton.frame.width)
        let statusBarH = UIApplication.shared.statusBarFrame.size.height
        postButton.frame.origin.y = self.sceneContainerView.frame.size.height - (labelInset + postButton.frame.height + statusBarH)
        
        self.sceneContainerView.addSubview(postButton)
        
        // configure message box
        //      initializes with default placeholder text
        messageBox.backgroundColor = lightGreyColor
        messageBox.font = mediumRegularFont
        messageBox.text = defaultMessage
        messageBox.textColor = messageTextColor
        let messageBoxW = self.sceneContainerView.frame.width - 2 * labelInset
        let messageBoxH = (postButton.frame.minY - separatorTwo.frame.maxY) - 2 * labelInset
        messageBox.frame.size = CGSize(width: messageBoxW, height: messageBoxH)
        messageBox.frame.origin.x = labelInset
        messageBox.frame.origin.y = separatorTwo.frame.maxY + labelInset
        messageBox.delegate = self
        messageBox.autocapitalizationType = UITextAutocapitalizationType.sentences
        messageBox.autocorrectionType = UITextAutocorrectionType.yes
        messageBox.spellCheckingType = UITextSpellCheckingType.yes
        messageBox.keyboardAppearance = UIKeyboardAppearance.dark
        messageBox.keyboardType = UIKeyboardType.default
        messageBox.returnKeyType = UIReturnKeyType.default
        messageBox.isSecureTextEntry = false
        
        self.sceneContainerView.addSubview(messageBox)
    }
    
        
    // Configure title of navigationBar to given string
    func configureTitleView() {
        // TODO: Change to name?
        self.navigationItem.title = "New Note"
    }
    
    // close the VC on button press from leftBarButtonItem
    @IBAction func cancelButtonPressed(_ sender: Any) {
        APIConnector.connector().trackMetric("Clicked Close Add or Edit Note")
        
        if (!messageBox.text.isEmpty && messageBox.text != defaultMessage) {
            // If the note has been edited, show an alert
            // DOES NOT show alert if date or group has been changed
            let alert = UIAlertController(title: addAlertTitle, message: addAlertMessage, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: addAlertCancel, style: .cancel, handler: { Void in
                DDLogVerbose("Cancel alert and return to note")
            }))
            alert.addAction(UIAlertAction(title: addAlertOkay, style: .default, handler: { Void in
                DDLogVerbose("Do not add note and close view controller")
                
                self.view.endEditing(true)
                self.closeDatePicker(false)
                // close the VC
                self.performSegue(withIdentifier: "unwindToDone", sender: self)
            }))
            self.present(alert, animated: true, completion: nil)
        } else {
            // Note has not been edited, dismiss the VC
            self.view.endEditing(true)
            self.closeDatePicker(false)
            // close the VC
            self.performSegue(withIdentifier: "unwindToDone", sender: self)
        }
    }
    
    // Toggle the datepicker open or closed depending on if it is currently showing
    // Called by the changeDateView
    func changeDatePressed(_ sender: UIView!) {
        APIConnector.connector().trackMetric("Clicked Change Date")
        if (!datePicker.isHidden) {
            closeDatePicker(false)
        } else {
            openDatePicker()
        }
    }
    
    // Closes the date picker with an animation
    //      if hashtagsAfter, will toggleHashtags following completion
    func closeDatePicker(_ hashtagsAfter: Bool) {
        if (!datePicker.isHidden && !isAnimating) {
            isAnimating = true
            // Fade out the date picker with an animation
            UIView.animate(withDuration: datePickerFadeTime, animations: {
                self.datePicker.alpha = 0.0
            })
            // Move all affected UI elements with animation
            UIView.animateKeyframes(withDuration: animationTime, delay: 0.0, options: [], animations: { () -> Void in
                
                // UI element location (and some sizing)
                self.separatorOne.frame.origin.y = self.timedateLabel.frame.maxY + labelInset
                //          note: hashtagsView completely expanded
                self.hashtagsScrollView.pagedHashtagsView()
                self.hashtagsScrollView.frame.origin.y = self.separatorOne.frame.maxY
                self.separatorTwo.frame.origin.y = self.hashtagsScrollView.frame.maxY
                let messageBoxH = (self.postButton.frame.minY - self.separatorTwo.frame.maxY) - 2 * labelInset
                self.messageBox.frame.size = CGSize(width: self.messageBox.frame.width, height: messageBoxH)
                self.messageBox.frame.origin.y = self.separatorTwo.frame.maxY + labelInset
                
            }, completion: { (completed: Bool) -> Void in
                // On completion, hide datePicker completely
                self.datePicker.isHidden = true
                self.isAnimating = false
                // change the changeDateLabel back to 'change'
                self.changeDateLabel.text = changeDateText
                self.changeDateLabel.sizeToFit()
                self.changeDateLabel.frame.origin.x = self.sceneContainerView.frame.width - (labelInset + self.changeDateLabel.frame.width)
                if (hashtagsAfter) {
                    self.toggleHashtags()
                }
            })
        }
    }
    
    // Opens the date picker with an animation
    func openDatePicker() {
        if (datePicker.isHidden && !isAnimating) {
            isAnimating = true
            UIView.animateKeyframes(withDuration: animationTime, delay: 0.0, options: [], animations: { () -> Void in
                
                // UI element location (and some sizing)
                self.separatorOne.frame.origin.y = self.datePicker.frame.maxY + labelInset / 2
                //          note: hashtags view completely closed, with height 0.0
                self.hashtagsScrollView.sizeZeroHashtagsView()
                self.hashtagsScrollView.frame.origin.y = self.separatorOne.frame.maxY
                self.separatorTwo.frame.origin.y = self.separatorOne.frame.minY
                let messageBoxH = (self.postButton.frame.minY - self.separatorTwo.frame.maxY) - 2 * labelInset
                self.messageBox.frame.size = CGSize(width: self.messageBox.frame.width, height: messageBoxH)
                self.messageBox.frame.origin.y = self.separatorTwo.frame.maxY + labelInset
                
            }, completion: { (completed: Bool) -> Void in
                // On completion, fade in the datePicker
                UIView.animate(withDuration: datePickerFadeTime, animations: {
                    self.datePicker.alpha = 1.0
                })
                // Set datePicker to show
                self.datePicker.isHidden = false
                self.isAnimating = false
                if (completed) {
                    // change the changeDateLabel to prompt done/close action
                    self.changeDateLabel.text = doneDateText
                    self.changeDateLabel.sizeToFit()
                    self.changeDateLabel.frame.origin.x = self.sceneContainerView.frame.width - (labelInset + self.changeDateLabel.frame.width)
                }
            })
        }
    }
    
    // Toggle the hashtags view between open completely and condensed
    func toggleHashtags() {
        if (hashtagsScrollView.hashtagsCollapsed) {
            openHashtagsCompletely()
        } else {
            closeHashtagsPartially()
        }
    }
    
    // Animations for resizing the hashtags view to be condensed
    func closeHashtagsPartially() {
        if (!hashtagsScrollView.hashtagsCollapsed && !isAnimating) {
            isAnimating = true
            UIView.animateKeyframes(withDuration: animationTime, delay: 0.0, options: [], animations: { () -> Void in
                
                // size hashtags view to condensed size
                self.hashtagsScrollView.linearHashtagsView()
                self.hashtagsScrollView.frame.origin.y = self.separatorOne.frame.maxY
                // position affected UI elements
                self.separatorTwo.frame.origin.y = self.hashtagsScrollView.frame.maxY
                let separatorToBottom: CGFloat = self.sceneContainerView.frame.height - self.separatorTwo.frame.maxY
                if (separatorToBottom > 300) {
                    // Small Device
                    
                    // Move up controls
                    self.postButton.frame.origin.y = self.sceneContainerView.frame.height - (self.keyboardFrame.height + labelInset + self.postButton.frame.height)
                    // Resize messageBox
                    let messageBoxH = (self.postButton.frame.minY - self.separatorTwo.frame.maxY) - 2 * labelInset
                    self.messageBox.frame.size = CGSize(width: self.messageBox.frame.width, height: messageBoxH)
                    self.messageBox.frame.origin.y = self.separatorTwo.frame.maxY + labelInset
                } else {
                    // Larger device
                    
                    // Do not move up controls, just resize messageBox
                    let messageBoxH = self.sceneContainerView.frame.height - (self.separatorTwo.frame.maxY + self.keyboardFrame.height + 2 * labelInset)
                    self.messageBox.frame.size = CGSize(width: self.messageBox.frame.width, height: messageBoxH)
                    self.messageBox.frame.origin.y = self.separatorTwo.frame.maxY + labelInset
                }
                
            }, completion: { (completed: Bool) -> Void in
                self.isAnimating = false
                if (completed) {
                    let separatorToBottom: CGFloat = self.sceneContainerView.frame.height - self.separatorTwo.frame.maxY
                    if (separatorToBottom < 300) {
                        // For small view, change the button to be 'done'
                        self.changeDateLabel.text = doneDateText
                        self.changeDateLabel.font = smallBoldFont
                        self.changeDateLabel.sizeToFit()
                        self.changeDateLabel.frame.origin.x = self.sceneContainerView.frame.width - (labelInset + self.changeDateLabel.frame.width)
                    }
                    
                    // hashtags now collapsed
                    self.hashtagsScrollView.hashtagsCollapsed = true
                }
            })
        }
    }
    
    // Open hashtagsView completely to full view
    func openHashtagsCompletely() {
        if (hashtagsScrollView.hashtagsCollapsed && !isAnimating) {
            isAnimating = true
            UIView.animateKeyframes(withDuration: animationTime, delay: 0.0, options: [], animations: { () -> Void in
                
                // hashtagsView has expanded size
                self.hashtagsScrollView.pagedHashtagsView()
                self.hashtagsScrollView.frame.origin.y = self.separatorOne.frame.maxY
                // position affected UI elements
                self.separatorTwo.frame.origin.y = self.hashtagsScrollView.frame.maxY
                self.postButton.frame.origin.y = self.sceneContainerView.frame.height - (labelInset + self.postButton.frame.height)
                let messageBoxH = (self.postButton.frame.minY - self.separatorTwo.frame.maxY) - 2 * labelInset
                self.messageBox.frame.size = CGSize(width: self.messageBox.frame.width, height: messageBoxH)
                self.messageBox.frame.origin.y = self.separatorTwo.frame.maxY + labelInset
                
            }, completion: { (completed: Bool) -> Void in
                self.isAnimating = false
                if (completed) {
                    if (self.changeDateLabel.text == doneDateText) {
                        // Label says 'done', change back to 'change'
                        self.changeDateLabel.text = changeDateText
                        self.changeDateLabel.font = smallRegularFont
                        self.changeDateLabel.sizeToFit()
                        self.changeDateLabel.frame.origin.x = self.sceneContainerView.frame.width - (labelInset + self.changeDateLabel.frame.width)
                    }
                    
                    // hashtagsView no longer collapsed
                    self.hashtagsScrollView.hashtagsCollapsed = false
                }
            })
        }
    }
    
    // Called when date picker date has changed
    func datePickerAction(_ sender: UIDatePicker) {
        let calendar = Calendar.current
        let compCurr = (calendar as NSCalendar).components(([.year, .month, .day, .hour, .minute]), from: datePicker.date)
        let compWas = (calendar as NSCalendar).components(([.year, .month, .day, .hour, .minute]), from: previousDate)
        
        if (compCurr.day != compWas.day || compCurr.month != compWas.month || compCurr.year != compWas.year) {
            APIConnector.connector().trackMetric("Date Changed")
        }
        if (compCurr.hour != compWas.hour) {
            APIConnector.connector().trackMetric("Hour Changed")
        }
        if (compCurr.minute != compWas.minute) {
            APIConnector.connector().trackMetric("Minute Changed")
        }
        
        let dateFormatter = DateFormatter()
        timedateLabel.attributedText = dateFormatter.attributedStringFromDate(datePicker.date)
        timedateLabel.sizeToFit()
    }
    
    @IBAction func saveButtonHandler(_ sender: Any) {
        doPostNote()
    }
    
    // postNote action from postNoteButton
    func postNote(_ sender: UIButton!) {
        doPostNote()
    }
    
    func doPostNote() {
        if (messageBox.text != defaultMessage && !messageBox.text.isEmpty) {
            APIConnector.connector().trackMetric("Clicked Post Note")
            
            // if messageBox has text (not default message or empty) --> set the note to have values
            self.note.messagetext = self.messageBox.text
            self.note.groupid = self.group.userid
            self.note.timestamp = self.datePicker.date
            self.note.userid = self.note.user!.userid
            
            // Identify hashtags
            let words = self.note.messagetext.components(separatedBy: " ")
            
            for word in words {
                if (word.hasPrefix("#")) {
                    // hashtag found!
                    // algorithm to determine length of hashtag without symbols or punctuation (common practice)
                    var charsInHashtag: Int = 0
                    let symbols = CharacterSet.symbols
                    let punctuation = CharacterSet.punctuationCharacters
                    for char in word.unicodeScalars {
                        if (char == "#" && charsInHashtag == 0) {
                            charsInHashtag += 1
                            continue
                        }
                        if (!punctuation.contains(UnicodeScalar(char.value)!) && !symbols.contains(UnicodeScalar(char.value)!)) {
                            charsInHashtag += 1
                        } else {
                            break
                        }
                    }
                    
                    let newword = (word as NSString).substring(to: charsInHashtag)
                    
                    // Save the hashtag in CoreData
                    self.hashtagsScrollView.hashtagsView.handleHashtagCoreData(newword)
                }
            }
            
            // End editing and close the datePicker
            self.view.endEditing(true)
            self.closeDatePicker(false)
            
            // close the VC, passing along new note...
            self.newNote = note
            self.performSegue(withIdentifier: "unwindToDone", sender: self)
        }
    }
    
    // Handle hashtagPressed notification from hashtagsView (hashtag button was pressed)
    func hashtagPressed(_ notification: Notification) {
        // unwrap the hashtag from userInfo
        
        APIConnector.connector().trackMetric("Clicked Hashtag")
        
        // TODO: replace use of notification with protocol callback...
        if let hashtag = notification.userInfo?["hashtag"] as? String {
            // append hashtag to messageBox.text
            if (messageBox.text == defaultMessage || messageBox.text.isEmpty) {
                // currently default message
                messageBox.text = hashtag
            } else {
                // not default message, check if there's already a space
                if (self.messageBox.text.hasSuffix(" ")) {
                    // already a space, append hashtag
                    messageBox.text = messageBox.text + hashtag
                } else {
                    // no space yet, throw a space in before hashtag
                    messageBox.text = messageBox.text + " " + hashtag
                }
            }
            // call textViewDidChange to format hashtags with bolding
            textViewDidChange(messageBox)
        }
    }
    
    // Handle touches in the view
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            
            // determine if the touch (first touch) is in the hashtagsView
            let touchLocation = touch.location(in: self.sceneContainerView)
            let viewFrame = self.sceneContainerView.convert(hashtagsScrollView.frame, from: hashtagsScrollView.superview)
            
            if !viewFrame.contains(touchLocation) {
                // if outside hashtagsView, endEditing, close keyboard, animate, etc.
                if (!isAnimating) {
                    view.endEditing(true)
                }
            }
        }
        super.touchesBegan(touches, with: event)
    }
    
    // UIKeyboardWillShowNotification
    func keyboardWillShow(_ notification: Notification) {
        // Take the keyboardFrame for positioning
        keyboardFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        if (!datePicker.isHidden) {
            // datePicker shown, close it, then condense the hashtags
            self.closeDatePicker(true)
        } else {
            // condense the hashtags
            self.closeHashtagsPartially()
        }
    }
    
    // UIKeyboardDidShowNotification
    func keyboardDidShow(_ notification: Notification) {
        // Take the keyboard frame for positioning
        keyboardFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
    }
    
    // UIKeyboardWillHideNotification
    func keyboardWillHide(_ notification: Notification) {
        // Open up the hashtagsView all the way!
        self.openHashtagsCompletely()
    }
    
    
    // Lock in portrait orientation
    override var shouldAutorotate : Bool {
        return false
    }

    //
    //  MARK: - UITextViewDelegate
    //

    // textViewDidBeginEditing, clear the messageBox if default message
    func textViewDidBeginEditing(_ textView: UITextView) {
        APIConnector.connector().trackMetric("Clicked On Message Box")
        
        if (textView.text == defaultMessage) {
            textView.text = nil
        }
    }
    
    // textViewDidEndEditing, if empty set back to default message
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = defaultMessage
            textView.font = mediumRegularFont
            textView.textColor = messageTextColor
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if (textView.text != defaultMessage) {
            // take the cursor position
            let range = textView.selectedTextRange
            
            // use hashtagBolder extension to bold the hashtags
            let hashtagBolder = HashtagBolder()
            let attributedText = hashtagBolder.boldHashtags(textView.text as NSString)
            
            // set textView (messageBox) text to new attributed text
            textView.attributedText = attributedText
            
            // put the cursor back in the same position
            textView.selectedTextRange = range
        }
        if (textView.text != defaultMessage && !textView.text.isEmpty) {
            self.postButton.alpha = 1.0
            self.saveButton.isEnabled = true
        } else {
            self.postButton.alpha = 0.5
            self.saveButton.isEnabled = false
        }
    }
}


