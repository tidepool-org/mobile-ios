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

class EventListViewController: BaseUIViewController, ENSideMenuDelegate, GraphContainerViewDelegate, NoteIOWatcher {

    
    @IBOutlet weak var eventListSceneContainer: UIControl!
    @IBOutlet weak var dataVizView: UIView!
    
    @IBOutlet weak var editBarButtonItem: UIBarButtonItem!
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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NutDataController.sharedInstance.currentUserName
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()

        editBarButtonItem.isEnabled = false

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
            let revealWidth = min(ceil((280.0/320.0) * self.view.bounds.width), 280.0)
            sideMenu.menuWidth = revealWidth
            sideMenu.bouncingEnabled = false
        }
        
    }
   
    // delay manual layout until we know actual size of container view (at viewDidLoad it will be the current storyboard size)
    private var subviewedInitialized = false
    override func viewDidLayoutSubviews() {
        if (subviewedInitialized) {
            return
        }
        subviewedInitialized = true
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh", attributes: [NSFontAttributeName: smallRegularFont, NSForegroundColorAttributeName: blackishColor])
        self.refreshControl.addTarget(self, action: #selector(EventListViewController.refresh), for: UIControlEvents.valueChanged)
        self.tableView.addSubview(refreshControl)
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
        //NSLog("EventList sideMenuWillOpen")
        configureForMenuOpen(true)
    }
    
    func sideMenuWillClose() {
        //NSLog("EventList sideMenuWillClose")
        configureForMenuOpen(false)
    }
    
    func sideMenuShouldOpenSideMenu() -> Bool {
        //NSLog("EventList sideMenuShouldOpenSideMenu")
        return true
    }
    
    func sideMenuDidClose() {
        //NSLog("EventList sideMenuDidClose")
        configureForMenuOpen(false)
    }
    
    func sideMenuDidOpen() {
        //NSLog("EventList sideMenuDidOpen")
        configureForMenuOpen(true)
        APIConnector.connector().trackMetric("Viewed Hamburger Menu (Hamburger)")
    }

    //
    // MARK: - Notes methods
    //
    
    // All notes
    var notes: [BlipNote] = []
    // Only filtered notes
    var filteredNotes: [BlipNote] = []
    
    // Last date fetched to & beginning -- starts at current date
    //let fetchPeriodInMonths: Int = -3
    let fetchPeriodInMonths: Int = -24
    var lastDateFetchTo: Date = Date()
    var loadingNotes = false
    
    //
    // MARK: - NoteIOWatcher Delegate
    //
    
    func loadingNotes(_ loading: Bool) {
        NSLog("NoteIOWatcher.loadingNotes: \(loading)")
        loadingNotes = loading
    }
    
    func endRefresh() {
        NSLog("NoteIOWatcher.endRefresh")
        refreshControl.endRefreshing()
    }
    
    func addNotes(_ notes: [BlipNote]) {
        NSLog("NoteIOWatcher.addNotes")
        self.notes = self.notes + notes
        // TODO: re-filter and update table...
        self.filteredNotes = self.notes
        self.tableView.reloadData()
    }
    
    func postComplete(_ note: BlipNote) {
        NSLog("NoteIOWatcher.postComplete")
        
        self.notes.insert(note, at: 0)
        // filter the notes, sort the notes, reload notes table
        // TODO: re-filter...
        self.filteredNotes = self.notes
        self.tableView.reloadData()
    }
    
    func deleteComplete(_ deletedNote: BlipNote) {
        NSLog("NoteIOWatcher.deleteComplete")
        if self.selectedNote != nil {
            if selectedNote!.id == deletedNote.id, let selectedIP = selectedIndexPath {
                // deselect cell before deletion...
                self.tableView.deselectRow(at: selectedIP, animated: true)
                self.selectNote(nil)
            }
        }
        var i = 0
        for note in self.notes {
            
            if (note.id == deletedNote.id) {
                self.notes.remove(at: i)
                break
            }
            i += 1
        }
        
        // filter the notes, sort the notes, reload notes table
        // TODO: re-filter and update table...
        self.filteredNotes = self.notes
        self.tableView.reloadData()
    }
    
    func updateComplete(_ originalNote: BlipNote, editedNote: BlipNote) {
        NSLog("NoteIOWatcher.updateComplete")
        
        originalNote.messagetext = editedNote.messagetext
        originalNote.timestamp = editedNote.timestamp
        self.filteredNotes = self.notes
        self.tableView.reloadData()
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
            filteredNotes = []
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
        if (segue.identifier) == EventViewStoryboard.SegueIdentifiers.EventItemEditSegue {
            let eventEditVC = segue.destination as! EventEditViewController
            eventEditVC.note = self.selectedNote
            eventEditVC.groupFullName = "GROUP FULL NAME"
            APIConnector.connector().trackMetric("Clicked edit a note (Home screen)")
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
        NSLog("unwind segue to eventList done!")
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
        } else {
            NSLog("Unknown segue source!")
        }
    }

    // Multiple VC's on the navigation stack return all the way back to this initial VC via this segue, when nut events go away due to deletion, for test purposes, etc.
    @IBAction func home(_ segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventList home!")
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
        searchTextField.resignFirstResponder()
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
    }
    
    //
    // MARK: - Data vizualization view
    //
    
    
    fileprivate func selectNote(_ note: BlipNote?) {
        
        // if we are deselecting, just close up data viz
        if note == nil {
            self.selectedNote = nil
            editBarButtonItem.isEnabled = false
            showHideDataVizView(show: false)
            configureGraphContainer()
            return
        }
        
        // if we have been showing something, close it up
        if let currentNote = self.selectedNote {
            if currentNote.id != note!.id {
                //showHideDataVizView(show: false)
                configureGraphContainer()
            } else {
                // same note, not sure why we'd be called...
                return
            }
        }
    
        // start looking for data for this item...
        self.selectedNote = note
        editBarButtonItem.isEnabled = true
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
        //NSLog("EventListVC: configureGraphContainer")
        if (graphContainerView != nil) {
            graphContainerView?.removeFromSuperview();
            graphContainerView = nil;
        }
        if let note = self.selectedNote {
            // TODO: using a faked up timezone offset for now...
            graphContainerView = TidepoolGraphView.init(frame: graphLayerContainer.frame, delegate: self, mainEventTime: note.timestamp, tzOffsetSecs: 0)
            if let graphContainerView = graphContainerView {
                graphContainerView.configureGraph(edgeOffset)
                graphLayerContainer.addSubview(graphContainerView)
                graphContainerView.loadGraphData()
            }
        }
    }
    
    fileprivate var viewAdjustAnimationTime: Float = 0.25
    fileprivate func showHideDataVizView(show: Bool) {
        
        for c in dataVizView.constraints {
            if c.firstAttribute == NSLayoutAttribute.height {
                c.constant = show ? graphLayerContainer.frame.size.height : 0.0
                break
            }
        }
        // graph view doesn't have a contraint, so we need to update its origin directly (could also manually add a constraint)
        if let graphView = graphContainerView {
            var rect = graphView.frame
            rect.origin.y = 0.0
            graphView.frame = rect
        }
        UIView.animate(withDuration: TimeInterval(viewAdjustAnimationTime), animations: {
            self.graphContainerView?.layoutIfNeeded()
            self.tableView?.layoutIfNeeded()
            self.dataVizView.layoutIfNeeded()
        }, completion: { (Bool) -> (Void) in
            self.tableView.scrollToNearestSelectedRow(at: .top, animated: true)
        })
    }
    
    //
    // MARK: - GraphContainerViewDelegate
    //
    
    func containerCellUpdated() {
        let graphHasData = graphContainerView!.dataFound()
        NSLog("\(#function) - graphHasData: \(graphHasData)")
        if !graphHasData {
            showHideDataVizView(show: false)
        } else {
            showHideDataVizView(show: true)
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
        
        let note = filteredNotes[indexPath.item]
        let cell = tableView.cellForRow(at: indexPath) as! NoteListTableViewCell
        let selectOrEdit = true
        
        if selectOrEdit {
            // Select cell, and, rather than invoking a detail view controller, show/hide the graph for the current selection
            if selectedIndexPath != nil && selectedIndexPath! == indexPath {
                // already selected and shown, toggle off
                self.selectNote(nil)
                self.selectedIndexPath = nil
                cell.setSelected(false, animated: true)
            } else {
                self.selectNote(note)
                cell.setSelected(true, animated: true)
                self.selectedIndexPath = indexPath
            }
        }
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
        
        // Note: two different list cells are used depending upon whether a location will be shown or not. 
        let cellId = EventViewStoryboard.TableViewCellIdentifiers.noteListCell
        var note: BlipNote?
        if (indexPath.item < filteredNotes.count) {
            note = filteredNotes[indexPath.item]
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
