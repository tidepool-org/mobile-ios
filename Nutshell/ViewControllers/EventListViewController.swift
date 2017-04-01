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

class EventListViewController: BaseUIViewController, ENSideMenuDelegate, GraphContainerViewDelegate, NoteAPIWatcher, UIScrollViewDelegate {

    
    @IBOutlet weak var eventListSceneContainer: UIControl!
    @IBOutlet weak var dataVizView: UIView!
    
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var searchTextField: NutshellUITextField!
    @IBOutlet weak var searchPlaceholderLabel: NutshellUILabel!
    @IBOutlet weak var tableView: NutshellUITableView!
    @IBOutlet weak var coverView: UIControl!
    
    fileprivate var sortedNutEvents = [(String, NutEvent)]()
    fileprivate var filteredNutEvents = [(String, NutEvent)]()
    fileprivate var filterString = ""
    
    // support for displaying graph around current selection
    fileprivate var selectedIndexPath: IndexPath? = nil
    fileprivate var selectedNote: BlipNote?
    @IBOutlet weak var graphLayerContainer: UIView!
    fileprivate var graphContainerView: TidepoolGraphView?
    fileprivate var eventTime = Date()
    
    // refresh control...
    var refreshControl:UIRefreshControl = UIRefreshControl()

    // Program timers
    var graphUpdateTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NutDataController.sharedInstance.currentUserName
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()


        // Add a notification for when the database changes
        let moc = NutDataController.sharedInstance.mocForNutEvents()
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
        //configureSearchUI()
        if let sideMenu = self.sideMenuController()?.sideMenu {
            sideMenu.allowLeftSwipe = true
            sideMenu.allowRightSwipe = true
            sideMenu.allowPanGesture = true
       }
        
        if notes.isEmpty || eventListNeedsUpdate {
            eventListNeedsUpdate = false
            loadNotes()
        }
        
        checkNotifyUserOfTestMode()
        // periodically check for authentication issues in case we need to force a new login
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.checkConnection()
        APIConnector.connector().trackMetric("Viewed Home Screen (Home Screen)")
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
        graphUpdateTimer?.invalidate()

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //searchTextField.resignFirstResponder()
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
            if sideMenuController.didSelectSwitchProfile {
                sideMenuController.didSelectSwitchProfile = false
                performSegue(withIdentifier: "segueToSwitchProfile", sender: self)
            }
        }
    }
    
    func sideMenuDidOpen() {
        //NSLog("EventList sideMenuDidOpen")
        configureForMenuOpen(true)
        APIConnector.connector().trackMetric("Viewed Hamburger Menu (Hamburger)")
    }

    //
    // MARK: - Notes methods
    //
    
    // All notes, kept sorted chronologically
    var notes: [BlipNote] = []
    
    // Last date fetched to & beginning -- starts at current date
    //let fetchPeriodInMonths: Int = -3
    let fetchPeriodInMonths: Int = -24
    var lastDateFetchTo: Date = Date()
    var loadingNotes = false

    // Sort notes chronologically
    func sortNotesAndReload() {
        notes.sort(by: {$0.timestamp.timeIntervalSinceNow > $1.timestamp.timeIntervalSinceNow})
        tableView.reloadData()
        // TODO: use this global for now until we move notes into database! Used by graph code to show notes.
        NutDataController.sharedInstance.currentNotes = notes
    }

    func selectAndScrollToTopNote() {
        if notes.count > 0 {
            let topIndexPath = IndexPath(row: 0, section: 0)
            selectAndScrollToNoteAtIndexPath(topIndexPath)
        } else {
            selectedIndexPath = nil
            selectNote(nil)
        }
    }
    
    func selectAndScrollToNoteAtIndexPath(_ path: IndexPath) {
        self.selectedIndexPath = path
        selectNote(notes[path.item])
        self.tableView.selectRow(at: path, animated: true, scrollPosition: .top)
        self.tableView.scrollToNearestSelectedRow(at: .top, animated: true)
    }
    
    func selectAndScrollToNote(_ note: BlipNote) {
        if let pathForNote = indexPathForNoteId(note.id) {
            self.selectAndScrollToNoteAtIndexPath(pathForNote)
        }
    }

    func snapSelectedRowToTop() {
        if let note = selectedNote {
            let path = indexPathForNoteId(note.id)
            self.tableView.selectRow(at: path, animated: true, scrollPosition: .top)
        }
    }

    func indexPathForNoteId(_ noteId: String) -> IndexPath? {
        for i in 0...notes.count {
            if notes[i].id == noteId {
                let path = IndexPath(row: i, section: 0)
                return path
            }
        }
        return nil
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
        self.notes = self.notes + notes
        sortNotesAndReload()
        if selectedIndexPath == nil {
            self.selectAndScrollToTopNote()
        }
    }
    
    func postComplete(_ note: BlipNote) {
        NSLog("NoteAPIWatcher.postComplete")
        
        self.notes.insert(note, at: 0)
        // sort the notes, reload notes table
        sortNotesAndReload()
        self.selectAndScrollToNote(note)
    }
    
    func deleteComplete(_ deletedNote: BlipNote) {
        NSLog("NoteAPIWatcher.deleteComplete")
        var nextIndexPath: IndexPath? = nil
        if self.selectedNote != nil {
            if selectedNote!.id == deletedNote.id {
                // deselect cell before deletion...
                self.selectNote(nil)
                if let selectedIP = selectedIndexPath {
                    self.tableView.deselectRow(at: selectedIP, animated: true)
                    if selectedIP.row > 0 {
                        nextIndexPath = IndexPath(row: selectedIP.row-1, section: 0)
                    }
                    self.selectedIndexPath = nil
                }
            }
        }
        
        if let deletedNotePath = self.indexPathForNoteId(deletedNote.id) {
            self.notes.remove(at: deletedNotePath.row)
        }
        
        sortNotesAndReload()
        
        // make sure we have a note selected. If we deleted the selected one, select the previous one.
        if self.selectedIndexPath != nil {
            self.selectAndScrollToNoteAtIndexPath(self.selectedIndexPath!)
        } else if nextIndexPath != nil {
            self.selectAndScrollToNoteAtIndexPath(nextIndexPath!)
        } else {
            self.selectAndScrollToTopNote()
        }
    }
    
    func updateComplete(_ originalNote: BlipNote, editedNote: BlipNote) {
        NSLog("NoteAPIWatcher.updateComplete")
        
    }
    
    
    func loadNotes() {
        DDLogVerbose("trace")
        
        if (!loadingNotes) {
            // Shift back three months for fetching
            var dateShift = DateComponents()
            dateShift.month = fetchPeriodInMonths
            let calendar = Calendar.current
            let startDate = (calendar as NSCalendar).date(byAdding: dateShift, to: lastDateFetchTo, options: [])!
            
            //for group in groups {
            // TODO: change to group.userId, and fetch for all groups...
            APIConnector.connector().getNotesForUserInDateRange(self, userid: NutDataController.sharedInstance.currentUserId!, start: startDate, end: lastDateFetchTo)
            //}
            
            self.lastDateFetchTo = startDate
        }
    }
    
    func refresh() {
        DDLogVerbose("trace)")
        
        if (!loadingNotes) {
            notes = []
            notes = []
            lastDateFetchTo = Date()
            loadNotes()
        }
    }
    
    //
    // MARK: - Navigation
    //
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if NutDataController.sharedInstance.currentBlipUser == nil {
            return false
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        super.prepare(for: segue, sender: sender)
        if (segue.identifier) == EventViewStoryboard.SegueIdentifiers.EventItemDetailSegue {
            let eventDetailVC = segue.destination as! EventDetailViewController
            eventDetailVC.note = self.selectedNote
            APIConnector.connector().trackMetric("Clicked view a note (Home screen)")
        } else if (segue.identifier) == EventViewStoryboard.SegueIdentifiers.EventItemAddSegue {
            let eventAddVC = segue.destination as! EventAddViewController
            // TODO: support for groups! For now, just support current user...
            if let currentUser = NutDataController.sharedInstance.currentBlipUser {
                eventAddVC.user = currentUser
                eventAddVC.group = currentUser
                eventAddVC.groups = [currentUser]
            }
            APIConnector.connector().trackMetric("Clicked add a note (Home screen)")
        } else {
            NSLog("Unprepped segue from eventList \(segue.identifier)")
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
                // will be called back on successful post!
                // TODO: also handle unsuccessful posts?
            }
        }  else if let eventDetailVC = segue.source as? EventDetailViewController {
            if eventDetailVC.noteEdited {
                self.reloadAndReselect(eventDetailVC.note)
            }
        } else {
            NSLog("Unknown segue source!")
        }
    }

    private func reloadAndReselect(_ note: BlipNote) {
        sortNotesAndReload()
        self.selectAndScrollToNote(note)
    }
    
    // Multiple VC's on the navigation stack return all the way back to this initial VC via this segue, when nut events go away due to deletion, for test purposes, etc.
    @IBAction func home(_ segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventList home!")
        if let switchProfileVC = segue.source as? SwitchProfileTableViewController {
            if let newUser = switchProfileVC.newUser {
                NSLog("TODO: switch to user \(newUser.fullName)")
            } else {
                NSLog("No note to delete!")
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
    
    @IBAction func dismissKeyboard(_ sender: AnyObject) {
        //searchTextField.resignFirstResponder()
    }
    
    func textFieldDidChange() {
        updateFilteredAndReload()
    }

    @IBAction func searchEditingDidEnd(_ sender: AnyObject) {
        configureSearchUI()
    }
    
    @IBAction func searchEditingDidBegin(_ sender: AnyObject) {
        configureSearchUI()
        APIConnector.connector().trackMetric("Typed into Search (Home Screen)")
    }
    
    fileprivate func searchMode() -> Bool {
        let searchMode = false
//        if searchTextField.isFirstResponder {
//            searchMode = true
//        } else if let searchText = searchTextField.text {
//            if !searchText.isEmpty {
//                searchMode = true
//            }
//        }
        return searchMode
    }
    
    fileprivate func configureSearchUI() {
        let searchOn = searchMode()
        searchPlaceholderLabel.isHidden = searchOn
        self.title = searchOn && !filterString.isEmpty ? "Events" : "All events"
    }

    fileprivate func updateFilteredAndReload() {
        if !searchMode() {
            filteredNutEvents = sortedNutEvents
            filterString = ""
        } else if let searchText = searchTextField.text {
            if !searchText.isEmpty {
                if searchText.localizedCaseInsensitiveContains(filterString) {
                    // if the search is just getting longer, no need to check already filtered out items
                    filteredNutEvents = filteredNutEvents.filter() {
                        $1.containsSearchString(searchText)
                    }
                } else {
                    filteredNutEvents = sortedNutEvents.filter() {
                        $1.containsSearchString(searchText)
                    }
                }
                filterString = searchText
            } else {
                filteredNutEvents = sortedNutEvents
                filterString = ""
            }
            // Do this last, after filterString is configured
            configureSearchUI()
        }
        tableView.reloadData()
        self.selectAndScrollToTopNote()
    }
    
    //
    // MARK: - Data vizualization view
    //
    
    private let kGraphUpdateDelay: TimeInterval = 1.0
    private func startGraphUpdateTimer() {
        if graphUpdateTimer == nil {
            graphUpdateTimer = Timer.scheduledTimer(timeInterval: kGraphUpdateDelay, target: self, selector: #selector(EventListViewController.graphUpdateTimerFired), userInfo: nil, repeats: false)
        }
    }
    
    private func stopGraphUpdateTimer() {
        NSLog("\(#function)")
        graphUpdateTimer?.invalidate()
        graphUpdateTimer = nil
    }
    
    func graphUpdateTimerFired() {
        NSLog("\(#function)")
        snapSelectedRowToTop()
        configureGraphContainer()
    }

    private func clearGraphAndUpdateDelayed() {
        NSLog("\(#function)")
        stopGraphUpdateTimer()
        if (graphContainerView != nil) {
            NSLog("Removing current graph view...")
            graphContainerView?.removeFromSuperview();
            graphContainerView = nil;
        }
        startGraphUpdateTimer()
    }
    
    fileprivate func selectNote(_ note: BlipNote?) {
        NSLog("\(#function)")

        // if we are deselecting, just close up data viz
        if note == nil {
            NSLog("Deselecting note...")
            self.selectedNote = nil
            //showHideDataVizView(show: false)
            configureGraphContainer()
            return
        }
        
        // if we have been showing something, close it up and update delayed
        if let currentNote = self.selectedNote {
            NSLog("Selecting a different note...")
            if currentNote.id != note!.id {
                //showHideDataVizView(show: false)
                self.selectedNote = note
                clearGraphAndUpdateDelayed()
                return
                //configureGraphContainer()
            } else {
                // same note, update graph if needed...
                configureGraphContainer()
                return
            }
        }
    
        NSLog("Selecting a new note...")
        // no selected note, start looking for data for this item...
        self.selectedNote = note
        configureGraphContainer()
    }
    
    /// Works with graphDataChanged to ensure graph is up-to-date after notification of database changes whether this VC is in the foreground or background.
    fileprivate func checkUpdateGraph() {
        if graphNeedsUpdate {
            graphNeedsUpdate = false
            if let graphContainerView = graphContainerView {
                graphContainerView.loadGraphData()
            }
        }
    }
    
    fileprivate var graphNeedsUpdate: Bool  = false
    func graphDataChanged(_ note: Notification) {
        graphNeedsUpdate = true
        if viewIsForeground {
            //NSLog("EventListVC: graphDataChanged, reloading")
            checkUpdateGraph()
        } else {
            NSLog("EventListVC: graphDataChanged, in background")
        }
    }
    
    
    /// Reloads the graph - this should be called after the header has been laid out and the graph section size has been figured. Pass in edgeOffset to place the nut event other than in the center.
    fileprivate func configureGraphContainer(_ edgeOffset: CGFloat = 0.0) {
        NSLog("EventListVC: configureGraphContainer")
        if (graphContainerView != nil) {
            NSLog("Removing current graph view...")
            graphContainerView?.removeFromSuperview();
            graphContainerView = nil;
        }
        if let note = self.selectedNote {
            NSLog("Configuring graph for note id: \(note.id)")

            // TODO: assume all notes created in current timezone?
            let tzOffset = NSCalendar.current.timeZone.secondsFromGMT()
            graphContainerView = TidepoolGraphView.init(frame: graphLayerContainer.frame, delegate: self, mainEventTime: note.timestamp, tzOffsetSecs: tzOffset)
            if let graphContainerView = graphContainerView {
                graphContainerView.configureGraph(edgeOffset)
                graphLayerContainer.addSubview(graphContainerView)
                graphContainerView.loadGraphData()
            }
        }
    }
    
    //
    // MARK: - GraphContainerViewDelegate
    //
    
    func containerCellUpdated() {
        let graphHasData = graphContainerView!.dataFound()
        NSLog("\(#function) - graphHasData: \(graphHasData)")
        if !graphHasData {
            //showHideDataVizView(show: false)
        } else {
            //showHideDataVizView(show: true)
        }
    }

    func pinchZoomEnded() {
        //adjustZoomButtons()
        APIConnector.connector().trackMetric("Pinched to Zoom (Data Screen)")
    }

    fileprivate var currentCell: Int?
    func willDisplayGraphCell(_ cell: Int) {
        if let currentCell = currentCell {
            if cell > currentCell {
                APIConnector.connector().trackMetric("Swiped to Pan Left (Data Screen)")
            } else if cell < currentCell {
                APIConnector.connector().trackMetric("Swiped to Pan Right (Data Screen)")
            }
        }
        currentCell = cell
    }

    func dataPointTapped(_ dataPoint: GraphDataType, tapLocationInView: CGPoint) {
        var itemId: String?
        if let mealDataPoint = dataPoint as? MealGraphDataType {
            NSLog("tapped on meal!")
            itemId = mealDataPoint.id
        } else if let workoutDataPoint = dataPoint as? WorkoutGraphDataType {
            NSLog("tapped on workout!")
            itemId = workoutDataPoint.id
        }
        if let itemId = itemId {
            //NSLog("EventDetailVC: dataPointTapped")
            let nutEventItem = DatabaseUtils.getNutEventItemWithId(itemId)
            if let nutEventItem = nutEventItem {
                // if the user tapped on some other event, switch to viewing that one instead!
                if nutEventItem.time != eventTime {
                    // TODO: handle by selecting appropriate event in table?
//                    switchedEvents = true
//                    // conjure up a NutWorkout and NutEvent for this new item!
//                    self.eventGroup = NutEvent(firstEvent: nutEventItem)
//                    self.eventItem = self.eventGroup?.itemArray[0]
                    // update view to show the new event, centered...
                    // keep point that was tapped at the same offset in the view in the new graph by setting the graph center point to be at the same x offset in the view...
                    configureGraphContainer(tapLocationInView.x)
                    // then animate to center...
                    if let graphContainerView = graphContainerView {
                        graphContainerView.centerGraphOnEvent(animated: true)
                    }
                }
            } else {
                NSLog("Couldn't find nut event item with id \(itemId)")
            }
        }
    }

    func unhandledTapAtLocation(_ tapLocationInView: CGPoint, graphTimeOffset: TimeInterval) {}

    //
    // Mark: - ScrollViewDelegate
    //
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let x = targetContentOffset.pointee.x
        let y = targetContentOffset.pointee.y
        NSLog("scrollViewWillEndDragging: x is \(x), y is \(y)")
        
        let topRowPoint = CGPoint(x: 0.0, y: y + 35.0)
        if let topIndexPath = tableView.indexPathForRow(at: topRowPoint) {
            NSLog("top indexpath: \(topIndexPath)")
            if let curSel = self.selectedIndexPath {
                // just bow out if we already are there...
                if curSel.row == topIndexPath.row {
                    return
                }
            }
            self.selectedIndexPath = topIndexPath
            selectNote(notes[topIndexPath.item])
            self.tableView.selectRow(at: topIndexPath, animated: true, scrollPosition: .top)
        }
    }
}


//
// MARK: - Table view delegate
//

extension EventListViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt estimatedHeightForRowAtIndexPath: IndexPath) -> CGFloat {
        return 102.0;
    }

    func tableView(_ tableView: UITableView, heightForRowAt heightForRowAtIndexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension;
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let note = notes[indexPath.item]
        if selectedNote != nil && selectedNote!.id != note.id {
            // set so we come back to this one
            self.selectedIndexPath = indexPath
            selectNote(note)
        }

        self.performSegue(withIdentifier: EventViewStoryboard.SegueIdentifiers.EventItemDetailSegue, sender: self)
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
        return notes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Note: two different list cells are used depending upon whether a location will be shown or not. 
        let cellId = EventViewStoryboard.TableViewCellIdentifiers.noteListCell
        var note: BlipNote?
        if (indexPath.item < notes.count) {
            note = notes[indexPath.item]
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListTableViewCell
        if let note = note {
            cell.configureCell(note)
            if let selectedNote = self.selectedNote {
                if selectedNote.id == note.id {
                    cell.setSelected(true, animated: false)
                }
            }
        }
        return cell
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

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

}
