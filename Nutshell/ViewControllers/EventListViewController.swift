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
import FLAnimatedImage

class EventListViewController: BaseUIViewController, ENSideMenuDelegate, NoteAPIWatcher {

    
    @IBOutlet weak var eventListSceneContainer: UIControl!
//    @IBOutlet weak var dataVizView: UIView!
    
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var searchTextField: NutshellUITextField!
    @IBOutlet weak var searchPlaceholderLabel: NutshellUILabel!
    @IBOutlet weak var tableView: NutshellUITableView!
    @IBOutlet weak var coverView: UIControl!
    
    // data viz layout
//    @IBOutlet weak var graphLayerContainer: UIView!
//    @IBOutlet weak var loadingAnimationView: UIView!
//    @IBOutlet weak var animatedLoadingImage: FLAnimatedImageView!
//    @IBOutlet weak var noDataViewContainer: UIView!
    
    // support for displaying graph around current selection
    fileprivate var selectedIndexPath: IndexPath? = nil
    fileprivate var selectedNote: BlipNote?
//    fileprivate var graphContainerView: TidepoolGraphView?
    fileprivate var eventTime = Date()
    
    // refresh control...
    var refreshControl:UIRefreshControl = UIRefreshControl()

    // Program timers
//    var graphUpdateTimer: Timer?
    
    // misc
    let dataController = NutDataController.sharedInstance
    fileprivate var sortedNutEvents = [(String, NutEvent)]()
    fileprivate var filteredNutEvents = [(String, NutEvent)]()
    fileprivate var filterString = ""
        
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

//        if let path = Bundle.main.path(forResource: "jump-jump-jump-jump", ofType: "gif") {
//            do {
//                let animatedImage = try FLAnimatedImage(animatedGIFData: Data(contentsOf: URL(fileURLWithPath: path)))
//                animatedLoadingImage.animatedImage = animatedImage
//            } catch {
//                DDLogError("Unable to load animated gifs!")
//            }
//        }

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
//        graphUpdateTimer?.invalidate()
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
    
    // All notes, kept sorted chronologically
    var notes: [BlipNote] = []
    
    // Fetch all notes for now...
    var loadingNotes = false

    func switchProfile(_ newUser: BlipUser) {
        // change the world!
        dataController.currentViewedUser = newUser
        self.title = newUser.fullName ?? ""
        selectedNote = nil
        selectedIndexPath = nil
        notes = []
        tableView.reloadData()
        configureGraphContainer()
        refresh()
    }
    
    // Sort notes chronologically
    func sortNotesAndReload() {
        notes.sort(by: {$0.timestamp.timeIntervalSinceNow > $1.timestamp.timeIntervalSinceNow})
        tableView.reloadData()
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
        if let note = noteForIndexPath(path) {
            selectNote(note)
            self.tableView.selectRow(at: path, animated: true, scrollPosition: .top)
            self.tableView.scrollToNearestSelectedRow(at: .top, animated: true)
        }
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

    func noteForIndexPath(_ indexPath: IndexPath) -> BlipNote? {
        let noteIndex = indexPath.item
        if noteIndex < self.notes.count {
            return notes[noteIndex]
        } else {
            NSLog("\(#function): index \(noteIndex) out of range of note count \(self.notes.count)!!!")
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
        self.notes = notes
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
            notes = []
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
        if segue.identifier == "segueToEventDetail" {
            let eventDetailVC = segue.destination as! EventDetailViewController
            eventDetailVC.note = self.selectedNote
            eventDetailVC.group = dataController.currentViewedUser!
            APIConnector.connector().trackMetric("Clicked view a note (Home screen)")
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
//                syncDataVizView()
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
    
    @IBAction func dismissKeyboard(_ sender: AnyObject) {
        //searchTextField.resignFirstResponder()
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
    
//    enum DataVizDisplayState: Int {
//        case initial
//        case loadingNoSelect
//        case loadingSelected
//        case dataGraph
//        case noDataDisplay
//    }
//    private var dataVizState: DataVizDisplayState = .initial
//
//    private func updateDataVizForState(_ newState: DataVizDisplayState) {
//        if newState == dataVizState {
//            NSLog("\(#function) already in state \(newState)")
//            return
//        }
//        NSLog("\(#function) setting new state: \(newState)")
//        dataVizState = newState
//        var hideLoadingGif = true
//        var hideNoDataView = true
//        if newState == .initial {
//            if (graphContainerView != nil) {
//                NSLog("Removing current graph view...")
//                graphContainerView?.removeFromSuperview();
//                graphContainerView = nil;
//            }
//        } else if newState == .loadingNoSelect {
//            // no item selected, show loading gif, hiding any current data and graph gridlines
//            graphContainerView?.displayGraphData(false)
//            graphContainerView?.displayGridLines(false)
//            hideLoadingGif = false
//        } else if newState == .loadingSelected {
//            // item selected, show loading gif, hide gridlines, but allow data to load.
//            graphContainerView?.displayGraphData(true)
//            graphContainerView?.displayGridLines(false)
//            hideLoadingGif = false
//        } else if newState == .dataGraph {
//            // item selected and data found, ensure gridlines are on and data displayed (should already be)
//            graphContainerView?.displayGridLines(true)
//        } else if newState == .noDataDisplay {
//            // item selected, but no data found; hide gridlines and show the no data found overlay
//            graphContainerView?.displayGridLines(false)
//            hideNoDataView = false
//        }
//        if loadingAnimationView.isHidden != hideLoadingGif {
//            loadingAnimationView.isHidden = hideLoadingGif
//            if hideLoadingGif {
//                NSLog("\(#function) hide loading gif!")
//                animatedLoadingImage.stopAnimating()
//            } else {
//                NSLog("\(#function) start showing loading gif!")
//                animatedLoadingImage.startAnimating()
//            }
//        }
//        if noDataViewContainer.isHidden != hideNoDataView {
//            noDataViewContainer.isHidden = hideNoDataView
//            NSLog("\(#function) noDataViewContainer.isHidden = \(hideNoDataView)")
//        }
//    }
//    
//    func syncDataVizView() {
//        if let graphContainerView = graphContainerView {
//            let graphHasData = graphContainerView.dataFound()
//            NSLog("\(#function) - graphHasData: \(graphHasData)")
//            if dataVizState == .loadingNoSelect {
//                NSLog("\(#function) ignoring call in state .loadingNoSelect")
//                return
//            }
//            if graphHasData {
//                updateDataVizForState(.dataGraph)
//            } else {
//                // Show the no-data view if not still loading...
//                if !DatabaseUtils.sharedInstance.isLoadingTidepoolEvents() {
//                    updateDataVizForState(.noDataDisplay)
//                } else {
//                    NSLog("\(#function): Keep displaying loading screen as load is still in progress")
//                }
//            }
//        }
//    }
//
//    private let kGraphUpdateDelay: TimeInterval = 0.5
//    private func startGraphUpdateTimer() {
//        if graphUpdateTimer == nil {
//            graphUpdateTimer = Timer.scheduledTimer(timeInterval: kGraphUpdateDelay, target: self, selector: #selector(EventListViewController.graphUpdateTimerFired), userInfo: nil, repeats: false)
//        }
//    }
//    
//    private func stopGraphUpdateTimer() {
//        NSLog("\(#function)")
//        graphUpdateTimer?.invalidate()
//        graphUpdateTimer = nil
//    }
//    
//    func graphUpdateTimerFired() {
//        NSLog("\(#function)")
//        snapSelectedRowToTop()
//        configureGraphContainer()
//    }
//
//    private func clearGraphAndUpdateDelayed() {
//        NSLog("\(#function)")
//        stopGraphUpdateTimer()
//
//        // while loading, and in between selections, put up loading view...
//        updateDataVizForState(.loadingNoSelect)
//        startGraphUpdateTimer()
//    }
    
    fileprivate func selectNote(_ note: BlipNote?) {
        NSLog("\(#function)")

        // if we are deselecting, change data viz to loading, no selection...
        if note == nil {
            NSLog("Deselecting note...")
            self.selectedNote = nil
//            updateDataVizForState(.initial)
            configureGraphContainer()
            return
        }
        
        // if we have been showing something, close it up and update delayed
        if let currentNote = self.selectedNote {
            NSLog("Selecting a different note...")
            if currentNote.id != note!.id {
                self.selectedNote = note
//                clearGraphAndUpdateDelayed()
                return
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
        NSLog("\(#function)")
        if graphNeedsUpdate {
            graphNeedsUpdate = false
            for cell in tableView.visibleCells {
                guard let expandoCell = cell as? NoteListTableViewCell else { continue }
                expandoCell.updateGraph()
            }
        }
    }
    
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
    
    /// Reloads the graph - this should be called after the header has been laid out and the graph section size has been figured. Pass in edgeOffset to place the nut event other than in the center.
    fileprivate func configureGraphContainer(_ edgeOffset: CGFloat = 0.0) {
        NSLog("EventListVC: configureGraphContainer")
//        if (graphContainerView != nil) {
//            NSLog("Removing current graph view...")
//            graphContainerView?.removeFromSuperview();
//            graphContainerView = nil;
//        }
//        
//        if let note = self.selectedNote {
//            NSLog("Configuring graph for note id: \(note.id)")
//
//            // TODO: assume all notes created in current timezone?
//            let tzOffset = NSCalendar.current.timeZone.secondsFromGMT()
//            graphContainerView = TidepoolGraphView.init(frame: graphLayerContainer.frame, delegate: self, mainEventTime: note.timestamp, tzOffsetSecs: tzOffset)
//            if let graphContainerView = graphContainerView {
//                // while loading, and in between selections, put up loading view...
//                updateDataVizForState(.loadingSelected)
//                graphContainerView.configureGraph(edgeOffset)
//                // delay to display notes until we get notified of data available...
//                graphContainerView.configureNotesToDisplay([note])
//                graphLayerContainer.insertSubview(graphContainerView, at: 0)
//                graphContainerView.loadGraphData()
//            }
//        }
    }
    
    //
    // MARK: - GraphContainerViewDelegate
    //
    
//    func containerCellUpdated() {
//        syncDataVizView()
//    }
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

}


//
// MARK: - Table view delegate
//

extension EventListViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt estimatedHeightForRowAtIndexPath: IndexPath) -> CGFloat {
        return 70.0;
    }

    func tableView(_ tableView: UITableView, heightForRowAt heightForRowAtIndexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension;
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
        
        tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
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
        
        // Note: two different list cells are used depending upon whether a user from: to title is needed...
        var note: BlipNote?
        let group = dataController.currentViewedUser!
        
        if (indexPath.item < notes.count) {
            note = notes[indexPath.item]
        }
        
        if let note = note {
            // If note was created by current viewed user, don't configure a title
            if note.userid == note.groupid {
                // If note was created by someone else, put in "xxx to yyy" title
                let cellId = "noteListCell"
                let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListTableViewCell
                cell.configureCell(note)
                
                if let selectedNote = self.selectedNote {
                    if selectedNote.id == note.id {
                        cell.setSelected(true, animated: false)
                    }
                }
                return cell
            } else {
                let cellId = "noteDetailCell"
                let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteDetailTableViewCell
                cell.configureCell(note, group: group)
                
                if let selectedNote = self.selectedNote {
                    if selectedNote.id == note.id {
                        cell.setSelected(true, animated: false)
                    }
                }
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
