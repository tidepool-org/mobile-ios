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

class EventListViewController: BaseUIViewController, ENSideMenuDelegate, NoteAPIWatcher, UIScrollViewDelegate {

    
    @IBOutlet weak var eventListSceneContainer: UIControl!
    
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var searchTextField: NutshellUITextField!
    @IBOutlet weak var searchPlaceholderLabel: NutshellUILabel!
    @IBOutlet weak var searchView: NutshellUIView!
    
    @IBOutlet weak var tableView: NutshellUITableView!
    @IBOutlet weak var coverView: UIControl!
    
    // refresh control...
    var refreshControl:UIRefreshControl = UIRefreshControl()

    // All notes, kept sorted chronologically
    var sortedNotes: [BlipNote] = []
    var filteredNotes: [BlipNote] = []
    fileprivate var filterString = ""
    // Fetch all notes for now...
    var loadingNotes = false
    
    // misc
    let dataController = NutDataController.sharedInstance

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = dataController.currentViewedUser?.fullName ?? ""
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()


        // Add a notification for when the database changes
        let moc = dataController.mocForNutEvents()
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.databaseChanged(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: moc)
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.textFieldDidChange), name: NSNotification.Name.UITextFieldTextDidChange, object: nil)
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.graphDataChanged(_:)), name: NSNotification.Name(rawValue: NewBlockRangeLoadedNotification), object: nil)
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
        
        // add a footer view to the table that is the size of the table minus the smallest row height, so last table row can be scrolled to the top of the table
        var footerFrame = self.tableView.frame
        footerFrame.size.height -= 70.0
        footerFrame.origin.y = 0.0
        let footerView = UIView(frame: footerFrame)
        footerView.backgroundColor = UIColor.white
        self.tableView.tableFooterView = footerView
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
        
        checkNotifyUserOfTestMode()
        // periodically check for authentication issues in case we need to force a new login
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.checkConnection()
        APIConnector.connector().trackMetric("Viewed Home Screen (Home Screen)")
        
        // one-time check to show celebrate UI
        celebrateCheck()
    }
    
    // each first time launch of app, let user know we are still in test mode!
    fileprivate func checkNotifyUserOfTestMode() {
        if AppDelegate.testMode && !AppDelegate.testModeNotification {
            AppDelegate.testModeNotification = true
            let alert = UIAlertController(title: "Test Mode", message: "Nutshell has Test Mode enabled!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { Void in
                return
            }))
            alert.addAction(UIAlertAction(title: "Turn Off", style: .default, handler: { Void in
                AppDelegate.testMode = false
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
    // MARK: - Notes methods
    //
    
    func switchProfile(_ newUser: BlipUser) {
        // change the world!
        dataController.currentViewedUser = newUser
        self.title = newUser.fullName ?? ""
        sortedNotes = []
        filteredNotes = []
        filterString = ""
        tableView.reloadData()
        refresh()
    }
    
    // Sort notes chronologically
    func sortNotesAndReload() {
        sortedNotes.sort(by: {$0.timestamp.timeIntervalSinceNow > $1.timestamp.timeIntervalSinceNow})
        updateFilteredAndReload()
        tableView.reloadData()
    }

    func indexPathForNoteId(_ noteId: String) -> IndexPath? {
        for i in 0...filteredNotes.count {
            if filteredNotes[i].id == noteId {
                let path = IndexPath(row: i, section: 0)
                return path
            }
        }
        return nil
    }

    func noteForIndexPath(_ indexPath: IndexPath) -> BlipNote? {
        let noteIndex = indexPath.item
        if noteIndex < self.filteredNotes.count {
            return filteredNotes[noteIndex]
        } else {
            NSLog("\(#function): index \(noteIndex) out of range of note count \(self.filteredNotes.count)!!!")
            return nil
        }
    }
    //
    // MARK: - NoteAPIWatcher Delegate
    //
    
    func loadingNotes(_ loading: Bool) {
        NSLog("NoteAPIWatcher.loadingNotes: \(loading)")
        loadingNotes = loading
    }
    
    func endRefresh() {
        NSLog("NoteAPIWatcher.endRefresh")
        refreshControl.endRefreshing()
    }
    
    func addNotes(_ notes: [BlipNote]) {
        NSLog("NoteAPIWatcher.addNotes")
        self.sortedNotes = notes
        sortNotesAndReload()
    }
    
    func postComplete(_ note: BlipNote) {
        NSLog("NoteAPIWatcher.postComplete")
        
        self.sortedNotes.insert(note, at: 0)
        // sort the notes, reload notes table
        sortNotesAndReload()
    }
    
    func deleteComplete(_ deletedNote: BlipNote) {
        NSLog("NoteAPIWatcher.deleteComplete")
        if let deletedNotePath = self.indexPathForNoteId(deletedNote.id) {
            self.sortedNotes.remove(at: deletedNotePath.row)
            sortNotesAndReload()
        }
        noteToEdit = nil
        indexPathOfNoteToEdit = nil
    }
    
    func updateComplete(_ originalNote: BlipNote, editedNote: BlipNote) {
        NSLog("NoteAPIWatcher.updateComplete")
        NSLog("Updating note \(originalNote.id) with text \(editedNote.messagetext)")
        originalNote.messagetext = editedNote.messagetext
        let timeChanged = originalNote.timestamp != editedNote.timestamp
        originalNote.timestamp = editedNote.timestamp
        if indexPathOfNoteToEdit != nil {
            if timeChanged {
                // sort order may have changed...
                sortNotesAndReload()
            } else {
                self.tableView.reloadRows(at: [indexPathOfNoteToEdit!], with: .middle)
                indexPathOfNoteToEdit = nil
            }
        }
        noteToEdit = nil
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
        }  else if segue.identifier == "segueToCelebrationView" {
            let _ = segue.destination as! ConnectToHealthCelebrationViewController
            APIConnector.connector().trackMetric("Showing connect to health celebration (Home screen)")
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
                // indexPathOfNoteToEdit
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
    private func celebrateCheck() {
        // Show connect to health celebration
        if (EventListViewController.oneShotTestCelebrate || (AppDelegate.shouldShowHealthKitUI() && !UserDefaults.standard.bool(forKey: "ConnectToHealthCelebrationHasBeenShown"))) {
            EventListViewController.oneShotTestCelebrate = false
            self.performSegue(withIdentifier: "segueToCelebrationView", sender: self)
        }
    }
    
    @IBAction func unwindFromCelebrate(_ sender: UIStoryboardSegue) {
        NSLog("EventList: \(#function)")
        // Celebration finished!
        UserDefaults.standard.set(true, forKey: "ConnectToHealthCelebrationHasBeenShown")
        UserDefaults.standard.synchronize()
    }
    

    @IBAction func howToUploadButtonHandler(_ sender: Any) {
        NSLog("TODO!")
    }

    //
    // MARK: - Search 
    //
    
    let kSearchHeight: CGFloat = 50.0
    private var searchOpen: Bool = true
    private var viewAdjustAnimationTime: Float = 0.25
    private func openSearchView(_ open: Bool) {
        if searchOpen == open {
            return
        }
        searchOpen = open
        for c in self.searchView.constraints {
            if c.firstAttribute == NSLayoutAttribute.height {
                c.constant = open ? kSearchHeight : 0.0
                NSLog("setting search view height to \(c.constant)")
                break
            }
        }
        UIView.animate(withDuration: TimeInterval(viewAdjustAnimationTime), animations: {
            self.eventListSceneContainer.layoutIfNeeded()
        })
    }
    
    @IBAction func dismissKeyboard(_ sender: AnyObject) {
        searchTextField.resignFirstResponder()
    }
    
    func textFieldDidChange() {
        if viewIsForeground {
            updateFilteredAndReload()
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
        //self.title = searchOn && !filterString.isEmpty ? "Events" : "All events"
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
                        $0.containsSearchString(searchText)
                    }
                } else {
                    filteredNotes = sortedNotes.filter() {
                        $0.containsSearchString(searchText)
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
    
    fileprivate func recenterGraph() {
//        graphContainerView?.centerGraphOnEvent(animated: true)
    }
    
    
    //
    // MARK: - GraphContainerViewDelegate
    //
    
//    func pinchZoomEnded() {
//        //adjustZoomButtons()
//        APIConnector.connector().trackMetric("Pinched to Zoom (Data Screen)")
//    }
//
//    fileprivate var currentCell: Int?
//    func willDisplayGraphCell(_ cell: Int) {
//        if let currentCell = currentCell {
//            if cell > currentCell {
//                APIConnector.connector().trackMetric("Swiped to Pan Left (Data Screen)")
//            } else if cell < currentCell {
//                APIConnector.connector().trackMetric("Swiped to Pan Right (Data Screen)")
//            }
//        }
//        currentCell = cell
//    }
//
//    func dataPointTapped(_ dataPoint: GraphDataType, tapLocationInView: CGPoint) {
//        var itemId: String?
//        if let mealDataPoint = dataPoint as? MealGraphDataType {
//            NSLog("tapped on meal!")
//            itemId = mealDataPoint.id
//        } else if let workoutDataPoint = dataPoint as? WorkoutGraphDataType {
//            NSLog("tapped on workout!")
//            itemId = workoutDataPoint.id
//        }
//        if let itemId = itemId {
//            //NSLog("EventDetailVC: dataPointTapped")
//            let nutEventItem = DatabaseUtils.sharedInstance.getNutEventItemWithId(itemId)
//            if let nutEventItem = nutEventItem {
//                // if the user tapped on some other event, switch to viewing that one instead!
//                if nutEventItem.time != eventTime {
//                    // TODO: handle by selecting appropriate event in table?
////                    switchedEvents = true
////                    // conjure up a NutWorkout and NutEvent for this new item!
////                    self.eventGroup = NutEvent(firstEvent: nutEventItem)
////                    self.eventItem = self.eventGroup?.itemArray[0]
//                    // update view to show the new event, centered...
//                    // keep point that was tapped at the same offset in the view in the new graph by setting the graph center point to be at the same x offset in the view...
//                    configureGraphContainer(tapLocationInView.x)
//                    // then animate to center...
//                    if let graphContainerView = graphContainerView {
//                        graphContainerView.centerGraphOnEvent(animated: true)
//                    }
//                }
//            } else {
//                NSLog("Couldn't find nut event item with id \(itemId)")
//            }
//        }
//    }
//
//    func unhandledTapAtLocation(_ tapLocationInView: CGPoint, graphTimeOffset: TimeInterval) {
//        recenterGraph()
//    }

    private var noteToEdit: BlipNote?
    private var indexPathOfNoteToEdit: IndexPath?
    func editPressed(_ sender: UIButton!) {
        NSLog("cell with tag \(sender.tag) was pressed!")
        let index = sender.tag
        if (index < filteredNotes.count) {
            indexPathOfNoteToEdit = IndexPath(row: index, section: 0)
            noteToEdit = filteredNotes[index]
            self.performSegue(withIdentifier: "segueToEditView", sender: self)
        }
    }
    
    //
    // MARK: - Table UIScrollViewDelegate
    //
    
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
 
        guard let expandoCell = tableView.cellForRow(at: indexPath) as? NoteListTableViewCell else { return }
        
        let openGraph = !expandoCell.expanded
        if !openGraph {
            expandoCell.removeGraphView()
            expandoCell.setSelected(false, animated: false)
        }
        
        expandoCell.openGraphView(!expandoCell.expanded)
        NSLog("setting row \(indexPath.row) expanded to: \(expandoCell.expanded)")
        
        tableView.beginUpdates()
        tableView.endUpdates()
        
        if openGraph {
            expandoCell.configureGraphContainer()
        }
        
        //tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
    }
    
}


//
// MARK: - Table view data source
//

extension EventListViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredNotes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Note: two different list cells are used depending upon whether a user from: to title is needed...
        var note: BlipNote?
        let group = dataController.currentViewedUser!
        
        if (indexPath.item < filteredNotes.count) {
            note = filteredNotes[indexPath.item]
        }
        
        func configureEdit(_ cell: NoteListTableViewCell, note: BlipNote) {
            if note.userid == dataController.currentUserId {
                // editButton tag to be indexPath.row so can be used in editPressed notification handling
                cell.editButton.isHidden = false
                cell.editButton.tag = indexPath.row
                cell.editButton.addTarget(self, action: #selector(EventListViewController.editPressed(_:)), for: .touchUpInside)
                cell.editButtonLargeHitArea.addTarget(self, action: #selector(EventListViewController.editPressed(_:)), for: .touchUpInside)
                
            } else {
                cell.editButton.isHidden = true
            }
        }
        
        if let note = note {
            // If note was created by current viewed user, don't configure a title, but note is editable
            if note.userid == note.groupid {
                let cellId = "noteListCell"
                let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListTableViewCell
                cell.configureCell(note)
                configureEdit(cell, note: note)
                return cell
            } else {
                // If note was created by someone else, put in "xxx to yyy" title and hide edit button
                let cellId = "noteListCellWithUser"
                let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListTableViewCellWithUser
                cell.configureCell(note, group: group)
                configureEdit(cell, note: note)
                return cell
            }
        } else {
            DDLogError("No note at cellForRowAt row \(indexPath.row)")
            return UITableViewCell()
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
