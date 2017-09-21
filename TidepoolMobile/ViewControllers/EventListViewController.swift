/*
* Copyright (c) 2017, Tidepool Project
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
import MessageUI
import CocoaLumberjack

class EventListViewController: BaseUIViewController, ENSideMenuDelegate, NoteAPIWatcher, UIScrollViewDelegate, UITextViewDelegate, MFMailComposeViewControllerDelegate {

    
    @IBOutlet weak var eventListSceneContainer: UIControl!
    @IBOutlet weak var navItem: UINavigationItem!
    
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var searchTextField: TidepoolMobileUITextField!
    @IBOutlet weak var searchPlaceholderLabel: TidepoolMobileUILabel!
    @IBOutlet weak var searchView: TidepoolMobileUIView!
    
    @IBOutlet weak var tableView: TidepoolMobileUITableView!
    @IBOutlet weak var coverView: UIControl!

    // refresh control...
    var refreshControl:UIRefreshControl = UIRefreshControl()

    // first time screens
    @IBOutlet weak var firstTimeHealthTip: TidepoolMobileUIView!
    @IBOutlet weak var firstTimeAddNoteTip: TidepoolMobileUIView!
    @IBOutlet weak var firstTimeNeedUploaderTip: UIView!
    
    fileprivate struct NoteInEventListTable {
        var note: BlipNote
        var opened: Bool = false
        var comments: [BlipNote] = []
    }

    // All notes, kept sorted chronologically. Second tuple is non-nil count of comments if note is "open".
    fileprivate var sortedNotes: [NoteInEventListTable] = []
    fileprivate var filteredNotes: [NoteInEventListTable] = []
    fileprivate var filterString = ""
    // Fetch all notes for now...
    var loadingNotes = false
    
    // misc
    let dataController = TidepoolMobileDataController.sharedInstance

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = dataController.currentViewedUser?.fullName ?? ""
        
        // Note: these notifications may fire when this VC is in the background!
        // Add a notification for when the database changes
        let moc = dataController.mocForLocalEvents()
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.databaseChanged(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: moc)
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.textFieldDidChangeNotifyHandler(_:)), name: NSNotification.Name.UITextFieldTextDidChange, object: nil)
        // graph data changes
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.graphDataChanged(_:)), name: NSNotification.Name(rawValue: NewBlockRangeLoadedNotification), object: nil)
        // need to update when day changes
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.calendarDayDidChange(notification:)), name: NSNotification.Name.NSCalendarDayChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.appDidEnterForeground(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.appDidEnterBackground(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.handleUploadSuccessfulNotification(_:)), name: NSNotification.Name(rawValue: HealthKitNotifications.UploadSuccessful), object: nil)

        
        if let sideMenu = self.sideMenuController()?.sideMenu {
            sideMenu.delegate = self
            menuButton.target = self
            menuButton.action = #selector(EventListViewController.toggleSideMenu(_:))
            let revealWidth = min(ceil((255.0/320.0) * self.view.bounds.width), 280.0)
            sideMenu.menuWidth = revealWidth
            sideMenu.bouncingEnabled = false
        }
        
        // Note: one-time check to show first time healthKit connect tip. This needs to be shown first, before other first time screens, so check for it here. If this is up, the other screens will be deferred...
        firstTimeHealthKitConnectCheck()
    }
   
    private var appIsForeground: Bool = true
    private var viewIsForeground: Bool = false
    private var updateDisplayPending = false

    private func eventListShowing() -> Bool {
        return appIsForeground && viewIsForeground
    }
    
    // Because many notes have times written as "Today at 2:00 pm" for example, they may be out of date when a day changes. Also, this will refresh UI the first time the user opens the app in the day.
    internal func calendarDayDidChange(notification : NSNotification)
    {
        updateDisplayPending = true
        checkRefresh()
    }
    
    private func checkRefresh() {
        if !eventListShowing() {
            // wait until app is foreground and this vc is showing
            return
        }
        if updateDisplayPending {
            updateDisplayPending = false
            graphNeedsUpdate = false // reload will also update graphs
            tableView.reloadData()
            return
        }
        checkUpdateGraph()
    }
    
    // delay manual layout until we know actual size of container view (at viewDidLoad it will be the current storyboard size)
    private var subviewsInitialized = false
    override func viewDidLayoutSubviews() {
        if (subviewsInitialized) {
            return
        }
        subviewsInitialized = true
        
        eventListSceneContainer.setNeedsLayout()
        eventListSceneContainer.layoutIfNeeded()

        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh", attributes: [NSFontAttributeName: smallRegularFont, NSForegroundColorAttributeName: blackishColor])
        self.refreshControl.addTarget(self, action: #selector(EventListViewController.refreshControlHandler), for: UIControlEvents.valueChanged)
        self.refreshControl.setNeedsLayout()
        self.tableView.addSubview(refreshControl)
        self.tableView.rowHeight = UITableViewAutomaticDimension
        // table seems to need a header for latest iOS, give it a small one...
        self.tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.size.width, height: 1.0))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func appDidEnterForeground(_ notification: Notification) {
        NSLog("EventListViewController:appDidEnterForeground")
        appIsForeground = true
        checkRefresh()
    }
    
    func appDidEnterBackground(_ notification: Notification) {
        NSLog("EventListViewController:appDidEnterBackground")
        appIsForeground = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewIsForeground = true

        configureSearchUI()
        if let sideMenu = self.sideMenuController()?.sideMenu {
            sideMenu.allowLeftSwipe = true
            sideMenu.allowRightSwipe = true
            sideMenu.allowPanGesture = true
       }

        if sortedNotes.isEmpty || eventListNeedsUpdate {
            eventListNeedsUpdate = false
            loadNotes()
        }

        // periodically check for authentication issues in case we need to force a new login
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.checkConnection()
        APIConnector.connector().trackMetric("Viewed Home Screen (Home Screen)")

        checkRefresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchTextField.resignFirstResponder()
        viewIsForeground = false
        if let sideMenu = self.sideMenuController()?.sideMenu {
            //NSLog("swipe disabled")
            sideMenu.allowLeftSwipe = false
            sideMenu.allowRightSwipe = false
            sideMenu.allowPanGesture = false
        }
    }
    
    @IBAction func toggleSideMenu(_ sender: AnyObject) {
        APIConnector.connector().trackMetric("Clicked Hamburger (Home Screen)")
        toggleSideMenuView()
    }

    //
    // MARK: - ENSideMenu Delegate
    //

    fileprivate func configureForMenuOpen(_ open: Bool) {
         if open {
            if let sideMenuController = self.sideMenuController()?.sideMenu?.menuViewController as? MenuAccountSettingsViewController {
                // give sidebar a chance to update
                // TODO: this should really be in ENSideMenu!
                sideMenuController.menuWillOpen()
            }
        }
        
        tableView.isUserInteractionEnabled = !open
        self.navigationItem.rightBarButtonItem?.isEnabled = !open
        coverView.isHidden = !open
    }
    
    func sideMenuWillOpen() {
        NSLog("EventList sideMenuWillOpen")
        configureForMenuOpen(true)
        // one-time check for health tip screen!
        if !firstTimeHealthTip.isHidden {
            firstTimeHealthTip.isHidden = true
            // after hiding the health tip, other tips may be shown!
            checkDisplayFirstTimeScreens()
        }
    }
    
    func sideMenuWillClose() {
        NSLog("EventList sideMenuWillClose")
        configureForMenuOpen(false)
    }
    
    func sideMenuShouldOpenSideMenu() -> Bool {
        NSLog("EventList sideMenuShouldOpenSideMenu")
        return true
    }
    
    func sideMenuDidClose() {
        NSLog("EventList sideMenuDidClose")
        configureForMenuOpen(false)
        if let sideMenuController = self.sideMenuController()?.sideMenu?.menuViewController as? MenuAccountSettingsViewController {
            if sideMenuController.userSelectedLoggedInUser {
                if let loggedInUser = dataController.currentLoggedInUser {
                    if loggedInUser.userid != dataController.currentViewedUser?.userid {
                        NSLog("Switching to logged in user, id: \(String(describing: loggedInUser.fullName))")
                        switchProfile(loggedInUser)
                    } else {
                        NSLog("Ignore select of logged in user, already selected!")
                    }
                }
            } else if sideMenuController.userSelectedSwitchProfile {
                sideMenuController.userSelectedSwitchProfile = false
                performSegue(withIdentifier: "segueToSwitchProfile", sender: self)
            } else if sideMenuController.userSelectedLogout {
                APIConnector.connector().trackMetric("Clicked Log Out (Hamburger)")
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.logout()
                viewIsForeground = false
            } else if let url = sideMenuController.userSelectedExternalLink {
                UIApplication.shared.openURL(url)
            }
        }
    }
    
    func sideMenuDidOpen() {
        NSLog("EventList sideMenuDidOpen")
        configureForMenuOpen(true)
        APIConnector.connector().trackMetric("Viewed Hamburger Menu (Hamburger)")
    }
    
    //
    // MARK: - Nav Bar right button handling
    //
    
    @IBAction func navBarRightButtonHandler(_ sender: Any) {
        if APIConnector.connector().alertIfNetworkIsUnreachable() {
            return
        }
        performSegue(withIdentifier: "segueToAddNote", sender: self)
        if !firstTimeAddNoteTip.isHidden {
            firstTimeAddNoteTip.isHidden = true
        }
    }
    
    //
    // MARK: - Notes methods
    //
    
    func switchProfile(_ newUser: BlipUser) {
        // change the world!
        dataController.currentViewedUser = newUser
        self.title = newUser.fullName ?? ""
        HashTagManager.sharedInstance.resetTags()
        refreshTable()
    }
    
    // Sort notes chronologically
    func sortNotesAndReload() {
        sortedNotes.sort(by: {$0.note.timestamp.timeIntervalSinceNow > $1.note.timestamp.timeIntervalSinceNow})
        
        updateFilteredAndReload()
     }

    func indexPathForNoteId(_ noteId: String) -> IndexPath? {
        for i in 0..<filteredNotes.count {
            if filteredNotes[i].note.id == noteId {
                let path = IndexPath(row: 0, section: i)
                return path
            }
        }
        return nil
    }

    func sortedNotesIndexPathForNoteId(_ noteId: String) -> IndexPath? {
        for i in 0..<sortedNotes.count {
            if sortedNotes[i].note.id == noteId {
                let path = IndexPath(row: 0, section: i)
                return path
            }
        }
        return nil
    }

    func noteForIndexPath(_ indexPath: IndexPath) -> BlipNote? {
        let noteIndex = indexPath.section
        if noteIndex < self.filteredNotes.count {
            return filteredNotes[noteIndex].note
        } else {
            NSLog("\(#function): index \(noteIndex) out of range of note count \(self.filteredNotes.count)!!!")
            return nil
        }
    }
 
    func commentForIndexPath(_ indexPath: IndexPath) -> BlipNote? {
        let noteIndex = indexPath.section
        if noteIndex < self.filteredNotes.count {
            let comments = filteredNotes[noteIndex].comments
            let commentIndex = indexPath.row - kFirstCommentRow
            if commentIndex < comments.count {
                return comments[commentIndex]
            }
            NSLog("\(#function): index \(noteIndex) out of range of comment count \(comments.count)!!!")
        } else {
            NSLog("\(#function): index \(noteIndex) out of range of note count \(self.filteredNotes.count)!!!")
        }
        return nil
    }

    //
    // MARK: - NoteAPIWatcher Delegate
    //
    
    func loadingNotes(_ loading: Bool) {
        NSLog("NoteAPIWatcher.loadingNotes: \(loading)")
        loadingNotes = loading
        if loadingNotes {
            return
        }
        
        // done loading, won't call addNotes if there are no notes, so have to splice in here for first time dialogs...
        checkDisplayFirstTimeScreens()
    }
    
    func endRefresh() {
        NSLog("NoteAPIWatcher.endRefresh")
        refreshControl.endRefreshing()
    }
    
    func addNotes(_ notes: [BlipNote]) {
        NSLog("NoteAPIWatcher.addNotes")
        self.sortedNotes = []
        for note in notes {
            self.sortedNotes.append(NoteInEventListTable(note: note, opened: false, comments: []))
        }
        // When notes are loaded, generate hashtag cache... could delay until needed (in add note).
        HashTagManager.sharedInstance.reloadTagsFromNotes(notes)
        // Note: Important to reload table as backing array has changed!
        sortNotesAndReload()
    }
    
    func addComments(_ notes: [BlipNote], messageId: String) {
        NSLog("NoteAPIWatcher.addComments, count: \(notes.count)")
        if let notePath = self.indexPathForNoteId(messageId) {
            if let sortedNotePath = sortedNotesIndexPathForNoteId(messageId) {
                var comments: [BlipNote] = []
                for comment in notes {
                    if comment.id != messageId {
                        comments.append(comment)
                    }
                }
                if comments.count > 0 {
                    comments.sort(by: {$0.timestamp.timeIntervalSinceNow < $1.timestamp.timeIntervalSinceNow})
                }

                // no need to re-sort since adding comments won't change the sort order
                // add to both sorted and filtered note arrays
                let startCommentCount = filteredNotes[notePath.section].comments.count
                sortedNotes[sortedNotePath.section].comments = comments
                filteredNotes[notePath.section].comments = comments
                // note may be closed by the time the comments come in, so don't do table adjusts in that case!
                if filteredNotes[notePath.section].opened {
                    tableView.beginUpdates()
                    
                    // if number of rows changed, need to add/delete rows
                    if startCommentCount != comments.count {
                        // first delete any current comment rows
                        var deletedRows: [IndexPath] = []
                        // need to also delete row 2 (add comment) since it will move to last row...
                        for i in 0..<startCommentCount+1 {
                            deletedRows.append(IndexPath(row: kFirstCommentRow+i, section: notePath.section))
                        }
                        tableView.deleteRows(at: deletedRows, with: .automatic)
                        
                        // next add any we got with this fetch, plus one for the "add comment" row.
                        var addedRows: [IndexPath] = []
                        for i in 0..<comments.count+1 {
                            addedRows.append(IndexPath(row: kFirstCommentRow+i, section: notePath.section))
                        }
                        tableView.insertRows(at: addedRows, with: .automatic)
                    }
                    
                    tableView.endUpdates()
                }
            }
        }
    }
  
    func postComplete(_ note: BlipNote) {
        NSLog("NoteAPIWatcher.postComplete")
        if note.parentmessage != nil {
            // added a comment, insert and update!
            let notePath = self.indexPathForNoteId(note.parentmessage!)
            let sortedNotePath = sortedNotesIndexPathForNoteId(note.parentmessage!)
            if let notePath = notePath, let sortedNotePath = sortedNotePath {
                let noteIndex = notePath.section
                let sortedNoteIndex = sortedNotePath.section
                var comments = filteredNotes[noteIndex].comments
                comments.append(note)
                comments.sort(by: {$0.timestamp.timeIntervalSinceNow < $1.timestamp.timeIntervalSinceNow})
                filteredNotes[noteIndex].comments = comments
                sortedNotes[sortedNoteIndex].comments = comments
                tableView.reloadSections(IndexSet(integer: noteIndex), with: .automatic)
            }
         } else {
            // added a note...
            // keep hashtags up-to-date
            HashTagManager.sharedInstance.updateTagsForNote(oldNote: nil, newNote: note)
            self.sortedNotes.insert(NoteInEventListTable(note: note, opened: false, comments: []), at: 0)
            // sort the notes, reload notes table
            sortNotesAndReload()
        }
    }
    
    func deleteComplete(_ deletedNote: BlipNote) {
        NSLog("NoteAPIWatcher.deleteComplete")
        if deletedNote.parentmessage == nil {
            // keep hashtags up-to-date
            HashTagManager.sharedInstance.updateTagsForNote(oldNote: deletedNote, newNote: nil)
            if let deletedNotePath = self.indexPathForNoteId(deletedNote.id) {
                self.sortedNotes.remove(at: deletedNotePath.section)
                sortNotesAndReload()
                // in case we went to zero...
                checkDisplayFirstTimeScreens()
            }
        } else {
            // deleted comment, only need to refetch comments for this note...
            if let deletedNotePath = self.indexPathForNoteId(deletedNote.parentmessage!) {
                let noteIndex = deletedNotePath.section
                var comments = filteredNotes[noteIndex].comments
                for i in 0..<comments.count {
                    if comments[i].id == deletedNote.id {
                        comments.remove(at: i)
                        filteredNotes[noteIndex].comments = comments
                        tableView.reloadSections(IndexSet(integer: noteIndex), with: .automatic)
                        break
                    }
                }
            }
        }
    }
    
    func updateComplete(_ originalNote: BlipNote, editedNote: BlipNote) {
        NSLog("NoteAPIWatcher.updateComplete")
        NSLog("Updating note \(originalNote.id) with text \(editedNote.messagetext)")
        if originalNote.parentmessage == nil {
            // keep hashtags up-to-date
            HashTagManager.sharedInstance.updateTagsForNote(oldNote: originalNote, newNote: editedNote)
        }
        originalNote.messagetext = editedNote.messagetext
        let timeChanged = originalNote.timestamp != editedNote.timestamp
        originalNote.timestamp = editedNote.timestamp
        if originalNote.parentmessage == nil {
            let indexPathOfEditedNote = self.indexPathForNoteId(originalNote.id)
            if indexPathOfEditedNote != nil {
                if timeChanged {
                    // sort order may have changed...
                    sortNotesAndReload()
                } else {
                    self.tableView.beginUpdates()
                    self.tableView.reloadRows(at: [indexPathOfEditedNote!], with: .middle)
                    self.tableView.endUpdates()
                }
            }
        } else {
            // edited a comment...
            let indexPathOfEditedNote = self.indexPathForNoteId(originalNote.parentmessage!)
            if let noteIndexPath = indexPathOfEditedNote {
                let noteIndex = noteIndexPath.section
                var comments = filteredNotes[noteIndex].comments
                for i in 0..<comments.count {
                    if comments[i].id == originalNote.id {
                        tableView.reloadRows(at: [IndexPath(row: i+kFirstCommentRow, section: noteIndex)], with: .automatic)
                        break
                    }
                }
            }
        }
    }
    
    func loadNotes() {
        DDLogVerbose("trace")
        
        if (!loadingNotes) {
            // TODO: implement incremental fetch and update if this takes too long!
            if let user = dataController.currentViewedUser {
                APIConnector.connector().getNotesForUserInDateRange(self, userid: user.userid, start: nil, end: nil)
            }
        } else {
           DDLogVerbose("already loading notes...")
        }
    }
    
    func refreshControlHandler() {
        APIConnector.connector().trackMetric("Swiped down to refresh")
        refreshTable()
    }
    
    func refreshTable() {
        DDLogVerbose("trace)")
        clearTable()
        loadNotes()
    }

    func clearTable() {
        sortedNotes = []
        filteredNotes = []
        filterString = ""
        // Note: important to reload here after clearing out sortedNotes!
        tableView.reloadData()
    }

    //
    // MARK: - Navigation
    //
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if dataController.currentLoggedInUser == nil {
            return false
        }
        return true
    }
    
    // index path to comment to add...
    fileprivate var currentCommentEditIndexPath: IndexPath?
    // note to edit...
    private var noteToEdit: BlipNote?
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        super.prepare(for: segue, sender: sender)
        if (segue.identifier) == "segueToEditNote" {
            let eventEditVC = segue.destination as! EventAddEditViewController
            eventEditVC.note = self.noteToEdit
            eventEditVC.isAddNote = false
            self.noteToEdit = nil
            APIConnector.connector().trackMetric("Clicked edit a note (Home screen)")
        } else if segue.identifier == "segueToAddNote" {
            let eventAddVC = segue.destination as! EventAddEditViewController
            // Pass along group (logged in user) and selected profile user...
            eventAddVC.isAddNote = true
            eventAddVC.user = dataController.currentLoggedInUser!
            eventAddVC.group = dataController.currentViewedUser!
            APIConnector.connector().trackMetric("Clicked add a note (Home screen)")
        } else if segue.identifier == "segueToSwitchProfile" {
            let _ = segue.destination as! SwitchProfileTableViewController
            APIConnector.connector().trackMetric("Clicked switch profile (Home screen)")
        } else if segue.identifier == "segueToEditComment" {
            let addCommentVC = segue.destination as! EditCommentViewController
            if let noteIndex = currentCommentEditIndexPath?.section {
                addCommentVC.note = filteredNotes[noteIndex].note
                addCommentVC.comments = filteredNotes[noteIndex].comments
                if let comment = self.noteToEdit {
                    // edit existing comment
                    addCommentVC.commentToEdit = comment
                    self.noteToEdit = nil
                    APIConnector.connector().trackMetric("Clicked edit comment")
                } else {
                    APIConnector.connector().trackMetric("Clicked add comment")
                }
            }
        } else {
            NSLog("Unprepped segue from eventList \(String(describing: segue.identifier))")
        }
    }
    
    @IBAction func doneEditNote(_ segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventListVC doneEditNote!")
        if let eventEditVC = segue.source as? EventAddEditViewController {
            if let originalNote = eventEditVC.note, let editedNote = eventEditVC.editedNote {
                APIConnector.connector().updateNote(self, editedNote: editedNote, originalNote: originalNote)
                // will be called back on at updateComplete on successful update!
                // TODO: also handle unsuccessful updates?
            } else {
                NSLog("No note to update!")
            }
        } else {
            NSLog("Unknown segue source!")
        }
    }
    
    @IBAction func doneAddNote(_ segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventListVC doneAddNote!")
        if let eventAddVC = segue.source as? EventAddEditViewController {
            if let newNote = eventAddVC.newNote {
                APIConnector.connector().doPostWithNote(self, note: newNote)
                // will be called back at postComplete on successful post!
                // TODO: also handle unsuccessful posts?
            } else {
                // add was cancelled... need to ensure graph is correctly configured.
            }
        } else {
            NSLog("Unknown segue source!")
        }
    }

    // Save button from edit comment.
    @IBAction func doneEditComment(_ segue: UIStoryboardSegue) {
        if let commentEditVC = segue.source as? EditCommentViewController {
            if let comment = commentEditVC.commentToEdit, let commentEdits = commentEditVC.newComment {
                APIConnector.connector().updateNote(self, editedNote: commentEdits, originalNote: comment)
                APIConnector.connector().trackMetric("Clicked save edited comment")
                // will be called back on at updateComplete on successful update!
                // TODO: also handle unsuccessful updates?
            }
        }
    }

    // Post button from add comment.
    @IBAction func doneAddComment(_ segue: UIStoryboardSegue) {
        if let commentEditVC = segue.source as? EditCommentViewController {
            if let newNote = commentEditVC.newComment {
                APIConnector.connector().doPostWithNote(self, note: newNote)
                APIConnector.connector().trackMetric("Clicked post comment")
                // will be called back at addComments
            }
        }
    }
    
    // Multiple VC's on the navigation stack return all the way back to this initial VC via this segue, when nut events go away due to deletion, for test purposes, etc.
    @IBAction func home(_ segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventList home!")
        if let switchProfileVC = segue.source as? SwitchProfileTableViewController {
            if let newViewedUser = switchProfileVC.newViewedUser {
                if newViewedUser.userid != dataController.currentViewedUser?.userid {
                    NSLog("Switch to user \(String(describing: newViewedUser.fullName))")
                    switchProfile(newViewedUser)
                }
            } else {
                NSLog("User did not change!")
            }
        } else {
            NSLog("Unknown segue source!")
        }
    }

    @IBAction func cancel(_ segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventList cancel")
    }

    fileprivate var eventListNeedsUpdate: Bool  = false
    func databaseChanged(_ note: Notification) {
        NSLog("EventList: Database Change Notification")
        if eventListShowing() {
            // TODO: This will be needed if notes go into a database but unused right now...
            //loadNotes()
        } else {
            // Note: this event can be triggered by update of hashtags in database, resulting in a refresh just as we are saving edits to a note. We update the note, but then get the refresh which overwrites it, and then the update goes out, and we miss the new edits until a later refresh.
            //eventListNeedsUpdate = true
        }
    }
    
    //
    // MARK: - First time screen support
    //

    // Note: to test celebrate, change the following to true, and it will come up once on each app launch...
    static var oneShotTestCelebrate = false
    private func firstTimeHealthKitConnectCheck() {
        // Show connect to health celebration
        if (EventListViewController.oneShotTestCelebrate || (appHealthKitConfiguration.shouldShowHealthKitUI() && oneShotIncompleteCheck("ConnectToHealthCelebrationHasBeenShown"))) {
            EventListViewController.oneShotTestCelebrate = false
            // One-shot finished!
            oneShotCompleted("ConnectToHealthCelebrationHasBeenShown")
            firstTimeHealthTip.isHidden = false
        }
    }
    
    private func checkDisplayFirstTimeScreens() {
        if loadingNotes {
            // wait until note loading is completed
            NSLog("\(#function) loading notes...")
            return
        }
        var hideAddNoteTip = true
        var hideNeedUploaderTip = true
        
        // only show other first time tips if we are not showing the healthkit tip!
        if firstTimeHealthTip.isHidden {
            if self.sortedNotes.count == 0 {
                hideAddNoteTip = false
            } else if self.sortedNotes.count == 1 {
                if oneShotIncompleteCheck("NeedUploaderTipHasBeenShown") {
                    hideNeedUploaderTip = false
                    oneShotCompleted("NeedUploaderTipHasBeenShown")
                }
            }
        }
        
        firstTimeAddNoteTip.isHidden = hideAddNoteTip
        firstTimeNeedUploaderTip.isHidden = hideNeedUploaderTip
    }
    
    fileprivate func oneShotIncompleteCheck(_ oneShotId: String) -> Bool {
        return !UserDefaults.standard.bool(forKey: oneShotId)
    }

    fileprivate func oneShotCompleted(_ oneShotId: String) {
        UserDefaults.standard.set(true, forKey: oneShotId)
    }
    
    @IBAction func emailALinkButtonHandler(_ sender: Any) {
        
        var onSimulator = false
        #if (TARGET_IPHONE_SIMULATOR)
            onSimulator = true
        #endif

        if !MFMailComposeViewController.canSendMail() || onSimulator {
            NSLog("Mail services are not available")
            let alertController = UIAlertController(title: "Error", message: "You must set up a mail service account in order to email a log!", preferredStyle: UIAlertControllerStyle.alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }

        APIConnector.connector().trackMetric("Clicked email a link")

        let emailVC = MFMailComposeViewController()
        emailVC.mailComposeDelegate = self
        
        // Configure the fields of the interface.
        emailVC.setSubject("How to set up the Tidepool Uploader")
        let messageText = "Please go to the following link on your computer to learn about setting up the Tidepool Uploader: http://support.tidepool.org/article/6-how-to-install-or-update-the-tidepool-uploader-gen"
        emailVC.setMessageBody(messageText, isHTML: false)
        if let email = dataController.currentLoggedInUserEmail {
            emailVC.setToRecipients([email])
        }
        
        // Present the view controller modally.
        self.present(emailVC, animated: true, completion: nil)

        firstTimeNeedUploaderTip.isHidden = true
}
    
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult, error: Error?) {
        // Check the result or perform other tasks.
        switch result
        {
        case .cancelled:
            NSLog("Mail cancelled")
        case .saved:
            NSLog("Mail saved")
        case .sent:
            NSLog("Mail sent")
        case .failed:
            if let error = error {
                NSLog("Mail sent failure: \(error.localizedDescription)")
            } else {
                NSLog("Mail sent failure!")
            }
        }
        // Dismiss the mail compose view controller.
        controller.dismiss(animated: true, completion: nil)
    }

    @IBAction func firstTimeNeedUploaderOkButtonHandler(_ sender: Any) {
        APIConnector.connector().trackMetric("Clicked first time need uploader")
        firstTimeNeedUploaderTip.isHidden = true
    }
    
    //
    // MARK: - Search 
    //
    
    private var viewAdjustAnimationTime: TimeInterval = 0.25
    @IBOutlet weak var searchViewHeightConstraint: NSLayoutConstraint!
    let kSearchHeight: CGFloat = 50.0
    private var searchOpen: Bool = true
    private func openSearchView(_ open: Bool) {
        if searchOpen == open {
            return
        }
        searchOpen = open
        searchViewHeightConstraint.constant = open ? kSearchHeight : 0.0
        UIView.animate(withDuration: TimeInterval(viewAdjustAnimationTime), animations: {
            self.eventListSceneContainer.layoutIfNeeded()
        })
    }
    
    @IBAction func dismissKeyboard(_ sender: AnyObject) {
        searchTextField.resignFirstResponder()
    }
    
    func textFieldDidChangeNotifyHandler(_ note: Notification) {
        if !eventListShowing() {
            // not for us...
            return
        }
        if let textField = note.object as? UITextField {
            if textField == searchTextField {
                updateFilteredAndReload()
            }
        }
    }

    @IBAction func searchEditingDidEnd(_ sender: AnyObject) {
        configureSearchUI()
    }
    
    @IBAction func searchEditingDidBegin(_ sender: AnyObject) {
        configureSearchUI()
        APIConnector.connector().trackMetric("Typed into Search (Home Screen)")
    }
    
    fileprivate func searchMode() -> Bool {
        var searchMode = false
        if searchTextField.isFirstResponder {
            searchMode = true
        } else if let searchText = searchTextField.text {
            if !searchText.isEmpty {
                searchMode = true
            }
        }
        return searchMode
    }
    
    private func configureSearchUI() {
        let searchOn = searchMode()
        searchPlaceholderLabel.isHidden = searchOn
    }

    fileprivate func updateFilteredAndReload() {
        if !searchMode() {
            filteredNotes = sortedNotes
            filterString = ""
        } else if let searchText = searchTextField.text {
            if !searchText.isEmpty {
                if searchText.localizedCaseInsensitiveContains(filterString) {
                    // if the search is just getting longer, no need to check already filtered out items
                    filteredNotes = filteredNotes.filter() {
                        $0.note.containsSearchString(searchText)
                    }
                } else {
                    filteredNotes = sortedNotes.filter() {
                        $0.note.containsSearchString(searchText)
                    }
                }
                filterString = searchText
            } else {
                filteredNotes = sortedNotes
                filterString = ""
            }
            // Do this last, after filterString is configured
            configureSearchUI()
        }
        tableView.reloadData()
    }
    
    /// Works with graphDataChanged to ensure graph is up-to-date after notification of database changes whether this VC is in the foreground or background.
    fileprivate func checkUpdateGraph() {
        NSLog("\(#function)")
        if graphNeedsUpdate {
            graphNeedsUpdate = false
            for cell in tableView.visibleCells {
                guard let graphCell = cell as? NoteListGraphCell else { continue }
                graphCell.updateGraph()
            }
        }
    }

    //
    // MARK: - Graph support
    //

    internal func handleUploadSuccessfulNotification(_ note: Notification) {
        DDLogInfo("inval cache and update graphs on successful upload")
        // TODO: make this more specific; for now, since uploads happen at most every 5 minutes, just do a graph update
        // reset cache fetch timeout so data will be refetched
        DatabaseUtils.sharedInstance.resetTidepoolEventLoader()
        graphDataChanged(note)
    }

    fileprivate var graphNeedsUpdate: Bool  = false
    func graphDataChanged(_ note: Notification) {
        DDLogInfo("\(#function)")
        graphNeedsUpdate = true
        checkRefresh()
    }
    
    @IBAction func howToUploadButtonHandler(_ sender: Any) {
        APIConnector.connector().trackMetric("Clicked how to upload button")
        let url = URL(string: TPConstants.kHowToUploadURL)
        if let url = url {
            UIApplication.shared.openURL(url)
        }
    }
    

    //
    // MARK: - Table UIScrollViewDelegate
    //
    
    // Show/hide the search view based on user scroll behavior...
    
    private var startScrollY: CGFloat = 0.0
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        startScrollY = scrollView.contentOffset.y
        NSLog("scrollViewWillBeginDragging: start offset is \(startScrollY)")
    }
    
    private var lastScrollY: CGFloat = 0.0
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let yOffset = scrollView.contentOffset.y
        var yIncreasing = true
        let deltaY = yOffset - lastScrollY
        if deltaY < 0 {
            yIncreasing = false
        }
        //NSLog("scrollViewDidScroll: offset is \(yOffset), delta y: \(deltaY), increasing: \(yIncreasing), isTracking: \(scrollView.isTracking)")
        lastScrollY = yOffset
        if yOffset <= kSearchHeight {
            NSLog("yOffset within search height!")
        } else if scrollView.isTracking {
            if searchOpen && yIncreasing && deltaY > 5.0 {
                openSearchView(false)
            } else if !searchOpen && !yIncreasing && deltaY < -5.0 {
                openSearchView(true)
            }
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let y = targetContentOffset.pointee.y
        NSLog("scrollViewWillEndDragging: y is \(y)")
        if y <= kSearchHeight {
            if y <= kSearchHeight/2 {
                openSearchView(true)
            } else {
                openSearchView(false)
            }
        }
    }
    
    //
    // MARK: - Table Misc
    //
    
    fileprivate let kFooterHeight: CGFloat = 10.0
    fileprivate let kNoteRow: Int = 0
    fileprivate let kGraphRow: Int = 1
    fileprivate let kPreCommentRows: Int = 2
    fileprivate let kDefaultAddCommentRow: Int = 2 // when there are no comments!
    fileprivate let kFirstCommentRow: Int = 2
    
    fileprivate func addCommentRow(commentCount: Int) -> Int {
        return kPreCommentRows + commentCount
    }

    func configureEdit(_ indexPath: IndexPath, note: BlipNote, editButton: TidepoolMobileSimpleUIButton, largeHitAreaButton: TPUIButton, hide: Bool = false) {
        if !hide && note.userid == dataController.currentUserId {
            // editButton stores indexPath so can be used in editPressed notification handling
            editButton.isHidden = false
            editButton.cellIndexPath = indexPath
            largeHitAreaButton.isHidden = false
            largeHitAreaButton.cellIndexPath = indexPath
            editButton.addTarget(self, action: #selector(EventListViewController.editPressed(_:)), for: .touchUpInside)
            largeHitAreaButton.addTarget(self, action: #selector(EventListViewController.editPressed(_:)), for: .touchUpInside)
            
        } else {
            editButton.isHidden = true
            largeHitAreaButton.isHidden = true
        }
    }
    
    func editPressed(_ sender: TidepoolMobileSimpleUIButton!) {
        NSLog("cell with tag \(sender.tag) was pressed!")
        
        if APIConnector.connector().alertIfNetworkIsUnreachable() {
            return
        }
        
        if let indexPath = sender.cellIndexPath {
            if indexPath.row == 0 {
                if let note = self.noteForIndexPath(indexPath) {
                    self.noteToEdit = note
                    self.performSegue(withIdentifier: "segueToEditNote", sender: self)
                }
            } else if let comment = commentForIndexPath(indexPath) {
                self.noteToEdit = comment
                self.currentCommentEditIndexPath = indexPath
                performSegue(withIdentifier: "segueToEditComment", sender: self)
                NSLog("Segue to edit comment!")
            }
        }
    }

    func howToUploadPressed(_ sender: UIButton!) {
        NSLog("howToUploadPressed was pressed!")
        if let url = URL(string: TPConstants.kHowToUploadURL) {
            UIApplication.shared.openURL(url)
        }
    }
    
}

//
// MARK: - Table view delegate
//

extension EventListViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt estimatedHeightForRowAtIndexPath: IndexPath) -> CGFloat {
        let row = estimatedHeightForRowAtIndexPath.row
        if row == kGraphRow {
            return TPConstants.kGraphViewHeight
        } else {
            return 90.0;
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt heightForRowAtIndexPath: IndexPath) -> CGFloat {
        let row = heightForRowAtIndexPath.row
        if row == kGraphRow {
            return TPConstants.kGraphViewHeight
        } else {
            return UITableViewAutomaticDimension;
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        var footerFrame = tableView.bounds
        footerFrame.size.height = kFooterHeight
        //let footer = UIView(frame: footerFrame)
        //footer.backgroundColor = UIColor.yellow
        //return footer
        return TPRowSeparatorView(frame: footerFrame)
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return kFooterHeight
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // use first tap on a row to dismiss search keyboard if it is up...
        if searchTextField.isFirstResponder {
            dismissKeyboard(self)
            return false
        }
        return true
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
 
        let noteSection = indexPath.section
        let row = indexPath.row
        let comments = filteredNotes[indexPath.section].comments
        let note = filteredNotes[indexPath.section].note
        
        if row > kNoteRow {
            if row == addCommentRow(commentCount: comments.count) {
                // go to comment add/edit controller if we have network connectivity...
                if !APIConnector.connector().alertIfNetworkIsUnreachable() {
                    self.currentCommentEditIndexPath = indexPath
                    performSegue(withIdentifier: "segueToEditComment", sender: self)
                    NSLog("Segue to add comment!")
                }
            } else {
                NSLog("tapped on graph or other comments... close any edit")
            }
            return
        }
        
        guard let noteCell = tableView.cellForRow(at: indexPath) as? NoteListTableViewCell else { return }
        noteCell.setSelected(false, animated: false)
        let openNote = !filteredNotes[noteSection].opened
        filteredNotes[noteSection].opened = openNote
        
        tableView.beginUpdates()
        
        // one time tool tip check on first note! 
        if noteSection == 0  {
            if openNote {
                if noteCell.firstTimeTipShowing() {
                    oneShotCompleted("TapToViewDataHasBeenShown")
                    noteCell.configureFirstTimeTip(nil)
                }
                if oneShotIncompleteCheck("TapToCloseNoteHasBeenShown") {
                    noteCell.configureFirstTimeTip("Tap to close note")
                }
            } else if noteCell.firstTimeTipShowing() {
                oneShotCompleted("TapToCloseNoteHasBeenShown")
                noteCell.configureFirstTimeTip(nil)
            }
        }
        if !noteCell.firstTimeTipShowing() {
            self.configureEdit(indexPath, note: note, editButton: noteCell.editButton, largeHitAreaButton: noteCell.editButtonLargeHitArea, hide: !openNote)
        }
        
        if openNote {
            // always add rows for the graph and for the "add comment" button - not actually at row 2 if there are comments!
            tableView.insertRows(at: [IndexPath(row: kGraphRow, section: noteSection), IndexPath(row: kDefaultAddCommentRow, section: noteSection)], with: .automatic)
            // add rows for each comment...
            if comments.count > 0 {
                var addedRows: [IndexPath] = []
                for i in 0..<comments.count {
                    addedRows.append(IndexPath(row: i+kFirstCommentRow+1, section: noteSection))
                }
                tableView.insertRows(at: addedRows, with: .automatic)
            }
            APIConnector.connector().trackMetric("Opened data viz")
        } else {
            var commentRows: [IndexPath] = []
            // include +2 for graph row and "add comment" row...
            let deleteRowCount = 2 + comments.count
            for i in 0..<deleteRowCount {
                // delete all rows except the first!
                commentRows.append(IndexPath(row: i+1, section: noteSection))
            }
            tableView.deleteRows(at: commentRows, with: .automatic)
            APIConnector.connector().trackMetric("Closed data viz")
        }
        tableView.endUpdates()
        
        if openNote {
            // each time we open a cell, try a fetch
            // TODO: may want to skip fetch if we've just done one! Note that comments, like notes, are cached in this controller in ram and not persisted...
            let note = filteredNotes[noteSection].note
            DDLogVerbose("Fetching comments for note \(note.id)")
            APIConnector.connector().getMessageThreadForNote(self, messageId: note.id)
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        let commentCount = filteredNotes[indexPath.section].comments.count
        let row = indexPath.row
        if row > kNoteRow {
            // only graph row and add comment button row are not delete-able...
            if row == addCommentRow(commentCount: commentCount) || row == kGraphRow {
                return .none
            }
        }
        if let noteToDelete = self.noteForIndexPath(indexPath) {
            if noteToDelete.userid != dataController.currentUserId {
                // only allow delete of notes created by current logged in user...
                return .none
            }
        }
        return .delete
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var noteToDelete = self.noteForIndexPath(indexPath)
        let comments = filteredNotes[indexPath.section].comments
        let row = indexPath.row
        if row > kNoteRow {
            // only graph row and add comment button row are not delete-able...
            if row == addCommentRow(commentCount: comments.count) || row == kGraphRow {
                return nil
            }
            noteToDelete = comments[row-kFirstCommentRow]
        }
        if noteToDelete == nil {
            NSLog("Error: note not found at \(#function)!")
            return nil
        }
        let rowAction = UITableViewRowAction(style: UITableViewRowActionStyle.default, title: "delete") {_,indexPath in
            // use dialog to confirm delete with user!
            var metric = "Swiped left to delete note"
            var title = trashAlertTitle
            var message = trashAlertMessage
            if row >= self.kFirstCommentRow {
                metric = "Swiped left to delete comment"
                title = trashCommentAlertTitle
                message = trashCommentAlertMessage
            }
            APIConnector.connector().trackMetric(metric)
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: trashAlertCancel, style: .cancel, handler: { Void in
                DDLogVerbose("Do not trash note")
            }))
            alert.addAction(UIAlertAction(title: trashAlertOkay, style: .destructive, handler: { Void in
                DDLogVerbose("Trash note")
                // handle delete!
                APIConnector.connector().deleteNote(self, noteToDelete: noteToDelete!)
                // will be called back on successful delete!
            }))
            self.present(alert, animated: true, completion: nil)
        }
        //rowAction.backgroundColor = UIColor.white
        return [rowAction]
    }
}

//
// MARK: - Table view data source
//

extension EventListViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return filteredNotes.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if filteredNotes[section].opened {
            // for opened notes, one row for note, one row for graph, one row per comment, one for add comment
            let commentCount = filteredNotes[section].comments.count
            return commentCount + 3
        } else {
            // only 1 row for closed up notes...
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if (indexPath.section > filteredNotes.count) {
            DDLogError("No note at cellForRowAt row \(indexPath.section)")
            return UITableViewCell()
        }
        
        let note = filteredNotes[indexPath.section].note
        let noteOpened = filteredNotes[indexPath.section].opened
        let comments = filteredNotes[indexPath.section].comments
        let row = indexPath.row
        
        
        if row == kNoteRow {
            let group = dataController.currentViewedUser!
            let cellId = "noteListCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListTableViewCell
            cell.configureCell(note, group: group)

            // one time tool tip check on first note!
            if indexPath.section == 0 {
                if noteOpened {
                    if oneShotIncompleteCheck("TapToCloseNoteHasBeenShown") {
                        cell.configureFirstTimeTip("Tap to close note")
                    }
                } else {
                    if oneShotIncompleteCheck("TapToViewDataHasBeenShown") {
                        cell.configureFirstTimeTip("Tap to view data")
                    }
                }
            }

            if noteOpened && !cell.firstTimeTipShowing() {
                configureEdit(indexPath, note: note, editButton: cell.editButton, largeHitAreaButton: cell.editButtonLargeHitArea)
            }
            return cell
        } else if row == kGraphRow {
            let cellId = "noteListGraphCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListGraphCell
            // graph does not have constraints, and since the cell hasn't been added to the parent table yet, size is storyboard size...
            cell.bounds.size.width = tableView.bounds.width
            cell.configureCell(note)

            cell.configureGraphContainer()
            cell.howToUploadButton.addTarget(self, action: #selector(EventListViewController.howToUploadPressed(_:)), for: .touchUpInside)
            return cell
        } else if row == addCommentRow(commentCount: comments.count) {
            // Last row is add comment...
            let cellId = "addCommentCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListAddCommentCell
            // need to get from text view back to cell!
            cell.configure()
            return cell
        } else {
            // Other rows are comment rows
            if row < kFirstCommentRow + comments.count {
                let comment = comments[row-kFirstCommentRow]
                let cell = tableView.dequeueReusableCell(withIdentifier: "noteListCommentCell", for: indexPath) as! NoteListCommentCell
                cell.configureCell(comment)
                configureEdit(indexPath, note: comment, editButton: cell.editButton, largeHitAreaButton: cell.editButtonLargeHitArea)
                return cell
            } else {
                DDLogError("No comment at cellForRowAt \(indexPath)")
                return UITableViewCell()
            }
        }
    }
}

