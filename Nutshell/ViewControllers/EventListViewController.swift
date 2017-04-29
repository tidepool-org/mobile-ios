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
    @IBOutlet weak var searchTextField: NutshellUITextField!
    @IBOutlet weak var searchPlaceholderLabel: NutshellUILabel!
    @IBOutlet weak var searchView: NutshellUIView!
    
    @IBOutlet weak var tableView: NutshellUITableView!
    @IBOutlet weak var coverView: UIControl!

    // current "add comment" edit info, if edit in progress
    fileprivate var currentCommentEditCell: NoteListAddCommentCell?
    fileprivate var currentCommentEditIndexPath: IndexPath?
    
    // refresh control...
    var refreshControl:UIRefreshControl = UIRefreshControl()

    // first time screens
    @IBOutlet weak var firstTimeHealthTip: NutshellUIView!
    @IBOutlet weak var firstTimeAddNoteTip: NutshellUIView!
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
    let dataController = NutDataController.sharedInstance

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = dataController.currentViewedUser?.fullName ?? ""
        
        // Add a notification for when the database changes
        let moc = dataController.mocForNutEvents()
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.databaseChanged(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: moc)
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.textFieldDidChangeNotifyHandler(_:)), name: NSNotification.Name.UITextFieldTextDidChange, object: nil)
        // graph data changes
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.graphDataChanged(_:)), name: NSNotification.Name(rawValue: NewBlockRangeLoadedNotification), object: nil)
        // keyboard up/down
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.reachabilityChanged(_:)), name: ReachabilityChangedNotification, object: nil)
        configureForReachability()

        if let sideMenu = self.sideMenuController()?.sideMenu {
            sideMenu.delegate = self
            menuButton.target = self
            menuButton.action = #selector(EventListViewController.toggleSideMenu(_:))
            let revealWidth = min(ceil((255.0/320.0) * self.view.bounds.width), 280.0)
            sideMenu.menuWidth = revealWidth
            sideMenu.bouncingEnabled = false
        }
        
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
        self.refreshControl.addTarget(self, action: #selector(EventListViewController.refresh), for: UIControlEvents.valueChanged)
        self.refreshControl.setNeedsLayout()
        self.tableView.addSubview(refreshControl)
        self.tableView.rowHeight = UITableViewAutomaticDimension
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    fileprivate var viewIsForeground: Bool = false
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
        
        configureRightNavButton()

        // periodically check for authentication issues in case we need to force a new login
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.checkConnection()
        APIConnector.connector().trackMetric("Viewed Home Screen (Home Screen)")
        
        // one-time check to show first time healthKit connect tip...
        firstTimeHealthKitConnectCheck()
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

    func reachabilityChanged(_ note: Notification) {
        configureForReachability()
    }

    fileprivate func configureForReachability() {
        let connected = APIConnector.connector().isConnectedToNetwork()
        //missingDataAdvisoryTitle.text = connected ? "There is no data in here!" : "You are currently offline!"
        NSLog("TODO: figure out connectivity story! Connected: \(connected)")
    }

    fileprivate func networkIsUnreachable(alertUser: Bool) -> Bool {
        if APIConnector.connector().serviceAvailable() {
            return false
        }
        let alert = UIAlertController(title: "Not Connected to Network", message: "This application requires a network to access the Tidepool service!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { Void in
            return
        }))
        self.present(alert, animated: true, completion: nil)
        return true
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
            if sideMenuController.userSelectedSwitchProfile {
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
    // MARK: - View handling for keyboard
    //
    
    private var viewAdjustAnimationTime: TimeInterval = 0.25
    private var keyboardFrame: CGRect?
    
    // For add comment editing, scroll table so edit view is just above the keyboard when it opens.
    // Also captures keyboard sizing and appropriate scroll animation timing.
    func keyboardWillShow(_ notification: Notification) {
        NSLog("\(#function)")
        viewAdjustAnimationTime = notification.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! TimeInterval
        keyboardFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        // not necessary for search field editing!
        if searchTextField.isFirstResponder {
            return
        }

        self.adjustKeyboardSpacerView() // first time, ensure we have a table footer for last cell special case
        self.adjustEditAboveKeyboard()
    }
 
    // Ensure there is enough table footer to allow add comment editing for last note
    fileprivate func adjustKeyboardSpacerView() {
        if let keyboardFrame = keyboardFrame {
            // add a footer view to the table that is the size of the keyboard, so last table row can be scrolled to the top of the table if necessary
            let height = keyboardFrame.height
            let curTableFooter = self.tableView.tableFooterView
            if curTableFooter != nil && curTableFooter!.bounds.height >= height {
                // table already adjusted...
                return
            }
            
            // add a footer view, possibly replace one that is too short (e.g., search keyboard is somewhat smaller than new comment edit keyboard)
            var footerFrame = self.tableView.bounds
            footerFrame.size.height = height
            let footerView = UIView(frame: footerFrame)
            footerView.backgroundColor = UIColor.white
            self.tableView.tableFooterView = footerView
        }
    }
    
    //
    // MARK: - Nav Bar right button handling
    //
    
    @IBAction func navBarRightButtonHandler(_ sender: Any) {
        if networkIsUnreachable(alertUser: true) {
            return
        }

        if rightNavConfiguredForAdd {
            performSegue(withIdentifier: "segueToEventAdd", sender: self)
            if !firstTimeAddNoteTip.isHidden {
                firstTimeAddNoteTip.isHidden = true
            }
        } else {
            // post new comment!
            if let currentEditCell = currentCommentEditCell, let currentEditIndex = currentCommentEditIndexPath {
                if let note = noteForIndexPath(currentEditIndex) {
                    let commentText = currentEditCell.addCommentTextView.text
                    if commentText?.isEmpty == false {
                        let newNote = BlipNote()
                        newNote.user = dataController.currentLoggedInUser!
                        newNote.groupid = note.groupid
                        newNote.messagetext = commentText!
                        newNote.parentmessage = note.id
                        newNote.timestamp = Date()
                        
                        APIConnector.connector().doPostWithNote(self, note: newNote)
                        // will be called back at addComments
                        clearCurrentComment()
                        tableView.reloadRows(at: [currentEditIndex], with: .none)
                    }
                }
            }
        }
    }
    
    fileprivate var rightNavConfiguredForAdd: Bool = true
    fileprivate func configureRightNavButton() {
        let forAdd: Bool = currentCommentEditCell == nil
        if forAdd == rightNavConfiguredForAdd {
            return
        }
        rightNavConfiguredForAdd = forAdd
        var newBarItem: UIBarButtonItem
        if forAdd {
            newBarItem = UIBarButtonItem(image: UIImage(named:"add-button"), style: .plain, target: self, action: #selector(EventListViewController.navBarRightButtonHandler(_:)))
        } else {
            newBarItem = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(EventListViewController.navBarRightButtonHandler(_:)))
        }
        newBarItem.tintColor = Styles.brightBlueColor
        navItem.rightBarButtonItem = newBarItem
    }
    
    //
    // MARK: - Notes methods
    //
    
    func switchProfile(_ newUser: BlipUser) {
        // change the world!
        dataController.currentViewedUser = newUser
        self.title = newUser.fullName ?? ""
        sortedNotes = []
        filteredNotes = []
        filterString = ""
        clearCurrentComment()
        tableView.reloadData()
        refresh()
    }
    
    // Sort notes chronologically
    func sortNotesAndReload() {
        sortedNotes.sort(by: {$0.note.timestamp.timeIntervalSinceNow > $1.note.timestamp.timeIntervalSinceNow})
        updateFilteredAndReload()
        clearCurrentComment()
        tableView.reloadData()
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
            let commentIndex = indexPath.row - 1
            if commentIndex < comments.count {
                return comments[commentIndex]
            }
            NSLog("\(#function): index \(noteIndex) out of range of comment count \(comments.count)!!!")
        } else {
            NSLog("\(#function): index \(noteIndex) out of range of note count \(self.filteredNotes.count)!!!")
        }
        return nil
    }

    func editPressed(_ sender: NutshellSimpleUIButton!) {
        NSLog("cell with tag \(sender.tag) was pressed!")
        
        if networkIsUnreachable(alertUser: true) {
            return
        }
        
        if let indexPath = sender.cellIndexPath {
            if indexPath.row == 0 {
                if let note = self.noteForIndexPath(indexPath) {
                    self.noteToEdit = note
                    self.performSegue(withIdentifier: "segueToEditView", sender: self)
                }
            } else if let comment = commentForIndexPath(indexPath) {
                self.noteToEdit = comment
                self.performSegue(withIdentifier: "segueToEditView", sender: self)
            }
        }
    }
    private var noteToEdit: BlipNote?
    
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
                        // need to also delete row 1 (add comment) since it will move to last row...
                        for i in 1...startCommentCount+1 {
                            deletedRows.append(IndexPath(row: i, section: notePath.section))
                        }
                        tableView.deleteRows(at: deletedRows, with: .automatic)
                        
                        // next add any we got with this fetch, plus one for the "add comment" row.
                        var addedRows: [IndexPath] = []
                        for i in 1...comments.count+1 {
                            addedRows.append(IndexPath(row: i, section: notePath.section))
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
            // adding a comment, no need to resort and reload, but refetch comments...
            APIConnector.connector().getMessageThreadForNote(self, messageId: note.parentmessage!)
            return
        }
        self.sortedNotes.insert(NoteInEventListTable(note: note, opened: false, comments: []), at: 0)
        // sort the notes, reload notes table
        sortNotesAndReload()
    }
    
    func deleteComplete(_ deletedNote: BlipNote) {
        NSLog("NoteAPIWatcher.deleteComplete")
        if deletedNote.parentmessage == nil {
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
                        tableView.reloadRows(at: [IndexPath(row: i+1, section: noteIndex)], with: .automatic)
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
    
    func refresh() {
        DDLogVerbose("trace)")
        
        if (!loadingNotes) {
            sortedNotes = []
            filteredNotes = []
            filterString = ""
            loadNotes()
        }
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        super.prepare(for: segue, sender: sender)
        if (segue.identifier) == "segueToEditView" {
            let eventEditVC = segue.destination as! EventEditViewController
            eventEditVC.note = self.noteToEdit
            self.noteToEdit = nil
            APIConnector.connector().trackMetric("Clicked edit a note (Home screen)")
        } else if segue.identifier == "segueToEventAdd" {
            let eventAddVC = segue.destination as! EventAddViewController
            // Pass along group (logged in user) and selected profile user...
            eventAddVC.user = dataController.currentLoggedInUser!
            eventAddVC.group = dataController.currentViewedUser!
            APIConnector.connector().trackMetric("Clicked add a note (Home screen)")
        } else if segue.identifier == "segueToSwitchProfile" {
            let _ = segue.destination as! SwitchProfileTableViewController
            APIConnector.connector().trackMetric("Clicked switch profile (Home screen)")
        } else {
            NSLog("Unprepped segue from eventList \(String(describing: segue.identifier))")
        }
    }
    
    // Back button from group or detail viewer.
    @IBAction func done(_ segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventListVC done!")
        if let eventEditVC = segue.source as? EventEditViewController {
            if let originalNote = eventEditVC.note, let editedNote = eventEditVC.editedNote {
                APIConnector.connector().updateNote(self, editedNote: editedNote, originalNote: originalNote)
                // will be called back on successful update!
                // TODO: also handle unsuccessful updates?
            } else {
                NSLog("No note to delete!")
            }
        } else if let eventAddVC = segue.source as? EventAddViewController {
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

    // Multiple VC's on the navigation stack return all the way back to this initial VC via this segue, when nut events go away due to deletion, for test purposes, etc.
    @IBAction func home(_ segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventList home!")
        if let switchProfileVC = segue.source as? SwitchProfileTableViewController {
            if let newViewedUser = switchProfileVC.newViewedUser {
                NSLog("TODO: switch to user \(String(describing: newViewedUser.fullName))")
                if newViewedUser.userid != dataController.currentViewedUser?.userid {
                    switchProfile(newViewedUser)
                }
            } else {
                NSLog("User did not change!")
            }
        } else {
            NSLog("Unknown segue source!")
        }
    }

    // The add/edit VC will return here when a meal event is deleted, and detail vc was transitioned to directly from this vc (i.e., the Nut event contained a single meal event which was deleted).
    @IBAction func doneItemDeleted(_ segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventList doneItemDeleted")
        if let eventEditVC = segue.source as? EventEditViewController {
            if let noteToDelete = eventEditVC.note {
                APIConnector.connector().deleteNote(self, noteToDelete: noteToDelete)
                // will be called back on successful delete!
                // TODO: also handle unsuccessful deletes?
            } else {
                NSLog("No note to delete!")
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
        if viewIsForeground {
            // TODO: this crashed on logout, we're still foreground, and moc is being saved...
            // TODO: will be needed if notes go into a database but unused right now...
            //loadNotes()
        } else {
            eventListNeedsUpdate = true
        }
    }
    
    // Note: to test celebrate, change the following to true, and it will come up once on each app launch...
    static var oneShotTestCelebrate = false
    private func firstTimeHealthKitConnectCheck() {
        // Show connect to health celebration
        if (EventListViewController.oneShotTestCelebrate || (AppDelegate.shouldShowHealthKitUI() && oneShotIncompleteCheck("ConnectToHealthCelebrationHasBeenShown"))) {
            EventListViewController.oneShotTestCelebrate = false
            // One-shot finished!
            oneShotCompleted("ConnectToHealthCelebrationHasBeenShown")
            firstTimeHealthTip.isHidden = false
        }
    }
    
    private func checkDisplayFirstTimeScreens() {
        if loadingNotes {
            // wait until note loading is completed (for firstTimeHealthKitConnectCheck path)
            NSLog("\(#function) loading notes...")
            return
        }
        if self.sortedNotes.count == 0 {
            if firstTimeHealthTip.isHidden {
                firstTimeAddNoteTip.isHidden = false
            }
        } else if self.sortedNotes.count == 1 {
            if oneShotIncompleteCheck("NeedUploaderTipHasBeenShown") {
                firstTimeNeedUploaderTip.isHidden = false
                oneShotCompleted("NeedUploaderTipHasBeenShown")
            }
        }
    }
    
    private func oneShotIncompleteCheck(_ oneShotId: String) -> Bool {
        return !UserDefaults.standard.bool(forKey: oneShotId)
    }

    private func oneShotCompleted(_ oneShotId: String) {
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
        
        let emailVC = MFMailComposeViewController()
        emailVC.mailComposeDelegate = self
        
        // Configure the fields of the interface.
        emailVC.setSubject("How to set up the Tidepool Uploader")
        let messageText = "Please go to the following link on your computer to learn about setting up the Tidepool Uploader: http://support.tidepool.org/article/6-how-to-install-or-update-the-tidepool-uploader-gen"
        emailVC.setMessageBody(messageText, isHTML: false)
        // Present the view controller modally.
        self.present(emailVC, animated: true, completion: nil)
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
        // TODO: metric?
        firstTimeNeedUploaderTip.isHidden = true
    }
    
    @IBAction func howToUploadButtonHandler(_ sender: Any) {
        // TODO: add metric?
        let url = URL(string: "http://support.tidepool.org/article/11-how-to-use-the-tidepool-uploader")
        if let url = url {
            UIApplication.shared.openURL(url)
        }
    }

    //
    // MARK: - Search 
    //
    
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
        if let textField = note.object as? UITextField {
            if textField == searchTextField {
                if viewIsForeground {
                    updateFilteredAndReload()
                }
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
        clearCurrentComment()
        tableView.reloadData()
    }
    
    /// Works with graphDataChanged to ensure graph is up-to-date after notification of database changes whether this VC is in the foreground or background.
    fileprivate func checkUpdateGraph() {
        NSLog("\(#function)")
        if graphNeedsUpdate {
            graphNeedsUpdate = false
            for cell in tableView.visibleCells {
                guard let expandoCell = cell as? NoteListTableViewCell else { continue }
                expandoCell.updateGraph()
            }
        }
    }

    //
    // MARK: - Graph support
    //

    fileprivate var graphNeedsUpdate: Bool  = false
    func graphDataChanged(_ note: Notification) {
        graphNeedsUpdate = true
        if viewIsForeground {
            NSLog("EventListVC: graphDataChanged, reloading")
            checkUpdateGraph()
        } else {
            NSLog("EventListVC: graphDataChanged, in background")
        }
    }
    

    //
    // MARK: - Add Comment UITextField Handling
    //
    
    // clear any comment add in progress
    fileprivate func clearCurrentComment() {
        self.currentCommentEditCell = nil
        self.currentCommentEditIndexPath = nil
        configureRightNavButton()
    }
    
    func textViewDidChangeNotifyHandler(_ note: Notification) {
        if let textView = note.object as? UITextView {
            if textView == self.currentCommentEditCell?.addCommentTextView {
                NSLog("note changed to \(textView.text)")
            }
        }
    }
    
    
    // UITextViewDelegate methods
    func textViewDidChange(_ textView: UITextView) {
        NSLog("current content offset: \(tableView.contentOffset.y)")
        if textView == self.currentCommentEditCell?.addCommentTextView {
            NSLog("note changed to \(textView.text)")
            // adjust table if lines of text have changed...
            tableView.beginUpdates()
            tableView.endUpdates()
            adjustEditAboveKeyboard()
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == self.currentCommentEditCell?.addCommentTextView {
            NSLog("\(#function)")
        }
    }

    func adjustEditAboveKeyboard() {
        if let curEditCell = currentCommentEditCell, let keyboardFrame = keyboardFrame {
            let cellContentOffset = curEditCell.frame.origin.y
            let sizeAboveKeyboard = tableView.bounds.height - keyboardFrame.height
            var targetOffset = tableView.contentOffset
            // minus 10 for 10 of the 12 note boundary separator pixels... 
            targetOffset.y = cellContentOffset - sizeAboveKeyboard  + curEditCell.bounds.height - 10.0
            NSLog("setting table offset to \(targetOffset.y)")
            tableView.setContentOffset(targetOffset, animated: true)
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
    
}


//
// MARK: - Table view delegate
//

extension EventListViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt estimatedHeightForRowAtIndexPath: IndexPath) -> CGFloat {
        return 90.0;
    }

    func tableView(_ tableView: UITableView, heightForRowAt heightForRowAtIndexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension;
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
        let noteRow = indexPath.row
        let comments = filteredNotes[indexPath.section].comments
        
        if noteRow > 0 {
            let lastRow = 1 + comments.count
            if noteRow == lastRow {
                guard let addCommentCell = tableView.cellForRow(at: indexPath) as? NoteListAddCommentCell else { return }
                // configure the cell's uitextview for editing, bring up keyboard, etc.
                if !networkIsUnreachable(alertUser: true) {
                    self.currentCommentEditCell = addCommentCell
                    self.currentCommentEditIndexPath = indexPath
                    configureRightNavButton()
                    tableView.beginUpdates()
                    tableView.reloadRows(at: [indexPath], with: .none)
                    tableView.endUpdates()
                    NSLog("Opening add comment for edit!")
                }
            } else {
                NSLog("tapped on other comments... close any edit")
                // clicking on another comment closes up any current comment edit in this section...
                if let currentEdit = currentCommentEditIndexPath {
                    if currentEdit.section == indexPath.section {
                        clearCurrentComment()
                        tableView.beginUpdates()
                        tableView.reloadRows(at: [currentEdit], with: .none)
                        tableView.endUpdates()
                    }
                }
            }
            return
        }
        
        // when open/closing a note, reset any existing comment editing...
        if currentCommentEditIndexPath != nil {
            if let commentCell = currentCommentEditCell {
                commentCell.addCommentTextView.resignFirstResponder()
            }
            clearCurrentComment()
        }
        
        guard let expandoCell = tableView.cellForRow(at: indexPath) as? NoteListTableViewCell else { return }
        let openGraph = !expandoCell.expanded
        if !openGraph {
            expandoCell.removeGraphView()
            expandoCell.setSelected(false, animated: false)
        }
        
        expandoCell.openGraphView(!expandoCell.expanded)
        NSLog("setting section \(noteSection) expanded to: \(expandoCell.expanded)")
        
        let existingCommentRowCount = filteredNotes[indexPath.section].comments.count
        filteredNotes[noteSection].opened = openGraph ? true : false
        
        tableView.beginUpdates()
        if openGraph {
            expandoCell.separatorView.isHidden = true
            // always add a row for the "add comment" button - not actually at row 1 if there are comments!
            tableView.insertRows(at: [IndexPath(row: 1, section: noteSection)], with: .automatic)
            // add rows for each comment...
            if existingCommentRowCount > 0 {
                var addedRows: [IndexPath] = []
                for i in 1...existingCommentRowCount {
                    addedRows.append(IndexPath(row: i+1, section: noteSection))
                }
                tableView.insertRows(at: addedRows, with: .automatic)
            }
        } else {
            expandoCell.separatorView.isHidden = false
            var commentRows: [IndexPath] = []
            // include +1 for "add comment" row...
            for i in 1...existingCommentRowCount+1 {
                commentRows.append(IndexPath(row: i, section: noteSection))
            }
            tableView.deleteRows(at: commentRows, with: .automatic)
        }
        tableView.endUpdates()
        
        if openGraph {
            expandoCell.configureGraphContainer()
            // each time we open a cell, try a fetch
            // TODO: may want to skip fetch if we've just done one! Note that comments, like notes, are cached in this controller in ram and not persisted...
            let note = filteredNotes[noteSection].note
            DDLogVerbose("Fetching comments for note \(note.id)")
            APIConnector.connector().getMessageThreadForNote(self, messageId: note.id)
        }
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
            // for opened notes, one row per comment, one for add comment, one for note...
            let commentCount = filteredNotes[section].comments.count
            return commentCount + 2
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
        
        func configureEdit(note: BlipNote, editButton: NutshellSimpleUIButton, largeHitAreaButton: TPUIButton) {
            if note.userid == dataController.currentUserId {
                // editButton stores indexPath so can be used in editPressed notification handling
                editButton.isHidden = false
                editButton.cellIndexPath = indexPath
                largeHitAreaButton.cellIndexPath = indexPath
                editButton.addTarget(self, action: #selector(EventListViewController.editPressed(_:)), for: .touchUpInside)
                largeHitAreaButton.addTarget(self, action: #selector(EventListViewController.editPressed(_:)), for: .touchUpInside)
                
            } else {
                editButton.isHidden = true
            }
        }
 
        // hide separator if note is "open", and show graph...
        func checkAndOpenGraph(_ cell: NoteListTableViewCell) {
            if noteOpened {
                cell.separatorView.isHidden = true
                cell.openGraphView(true)
                cell.configureGraphContainer()
            } else {
                cell.separatorView.isHidden = false
            }
        }

        if indexPath.row == 0 {
            let group = dataController.currentViewedUser!
            let cellId = "noteListCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListTableViewCell
            cell.configureCell(note, group: group)
            configureEdit(note: note, editButton: cell.editButton, largeHitAreaButton: cell.editButtonLargeHitArea)
            checkAndOpenGraph(cell)
            return cell
        } else {
            let lastRow = 1 + comments.count
            if indexPath.row == lastRow {
                // Last row is add comment...
                let cellId = "addCommentCell"
                let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListAddCommentCell
                // need to get from text view back to cell!
                cell.addCommentTextView.tag = indexPath.section
                var configureForEdit = false
                if let currentEditPath = self.currentCommentEditIndexPath {
                    if currentEditPath == indexPath {
                        self.currentCommentEditCell = cell
                        configureForEdit = true
                    }
                }
                cell.configureCellForEdit(configureForEdit, delegate: self)
                return cell
            } else {
                // Other rows are comment rows
                if indexPath.row <= comments.count {
                    let comment = comments[indexPath.row-1]
                    let cell = tableView.dequeueReusableCell(withIdentifier: "noteListCommentCell", for: indexPath) as! NoteListCommentCell
                    cell.configureCell(comment)
                    configureEdit(note: comment, editButton: cell.editButton, largeHitAreaButton: cell.editButtonLargeHitArea)
                    return cell
                } else {
                    DDLogError("No comment at cellForRowAt \(indexPath)")
                    return UITableViewCell()
                }
            }
         }
    }
    
    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

}
