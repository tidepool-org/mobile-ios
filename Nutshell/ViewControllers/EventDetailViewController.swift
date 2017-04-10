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

class EventDetailViewController: BaseUIViewController, GraphContainerViewDelegate, NoteAPIWatcher {

    
    @IBOutlet weak var sceneContainerView: UIControl!
    @IBOutlet weak var dataVizView: UIView!
    
    @IBOutlet weak var editBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var tableView: NutshellUITableView!

    // support for displaying graph around current note
    @IBOutlet weak var graphLayerContainer: UIView!
    @IBOutlet weak var loadingAnimationView: UIView!
    @IBOutlet weak var animatedLoadingImage: FLAnimatedImageView!
    @IBOutlet weak var noDataViewContainer: UIView!
    fileprivate var graphContainerView: TidepoolGraphView?

    // Data
    // Note must be set by launching controller in prepareForSegue!
    var note: BlipNote!
    var noteEdited: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // only notes by current logged in user are editable (perhaps just hide edit button?)
        editBarButtonItem.isEnabled = note.userid == note.groupid

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(EventDetailViewController.graphDataChanged(_:)), name: NSNotification.Name(rawValue: NewBlockRangeLoadedNotification), object: nil)
        notificationCenter.addObserver(self, selector: #selector(EventDetailViewController.reachabilityChanged(_:)), name: ReachabilityChangedNotification, object: nil)
        configureForReachability()
    }

     deinit {
        NotificationCenter.default.removeObserver(self)
     }

    fileprivate var viewIsForeground: Bool = false
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewIsForeground = true
        
        APIConnector.connector().getMessageThreadForNote(self, messageId: note.id)

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        viewIsForeground = false
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
        sceneContainerView.setNeedsLayout()
        sceneContainerView.layoutIfNeeded()
        sceneContainerView.checkAdjustSubviewSizing()
        
        if let path = Bundle.main.path(forResource: "jump-jump-jump-jump", ofType: "gif") {
            do {
                let animatedImage = try FLAnimatedImage(animatedGIFData: Data(contentsOf: URL(fileURLWithPath: path)))
                animatedLoadingImage.animatedImage = animatedImage
            } catch {
                DDLogError("Unable to load animated gifs!")
            }
        }

        selectNote()
    }
    
    func reachabilityChanged(_ note: Notification) {
        configureForReachability()
    }
    
    fileprivate func configureForReachability() {
        let connected = APIConnector.connector().isConnectedToNetwork()
        //missingDataAdvisoryTitle.text = connected ? "There is no data in here!" : "You are currently offline!"
        NSLog("TODO: figure out connectivity story! Connected: \(connected)")
    }

    //
    // MARK: - Comments methods
    //
    
    // All comments
    var comments: [BlipNote] = []

    
    //
    // MARK: - NoteAPIWatcher Delegate
    //
    
    func loadingNotes(_ loading: Bool) {
        NSLog("EventDetailVC! NoteAPIWatcher.loadingNotes: \(loading)")
    }
    
    func endRefresh() {
        NSLog("EventDetailVC! NoteAPIWatcher.endRefresh")
    }
    
    func addNotes(_ notes: [BlipNote]) {
        for comment in notes {
            if comment.id != self.note.id {
                self.comments.append(comment)
            }
        }
        NSLog("EventDetailVC! NoteAPIWatcher.addNotes")
        if self.comments.count > 0 {
            NSLog("added \(self.comments.count) comments!")
            self.comments.sort(by: {$0.timestamp.timeIntervalSinceNow < $1.timestamp.timeIntervalSinceNow})
            self.tableView.reloadData()
        }
    }
    
    func postComplete(_ note: BlipNote) {
        NSLog("EventDetailVC! NoteAPIWatcher.postComplete")
    }
    
    func deleteComplete(_ deletedNote: BlipNote) {
        NSLog("EventDetailVC NoteAPIWatcher.deleteComplete")
        // If deleted, segue back to list view will  happen from eventEditVC segue
    }
    
    func updateComplete(_ originalNote: BlipNote, editedNote: BlipNote) {
        NSLog("EventDetailVC NoteAPIWatcher.updateComplete")
        originalNote.messagetext = editedNote.messagetext
        let timeChanged = originalNote.timestamp != editedNote.timestamp
        originalNote.timestamp = editedNote.timestamp
        self.noteEdited = true
        self.tableView.reloadData()
        if timeChanged {
            self.configureGraphContainer()
        }
    }

    //
    // MARK: - Navigation
    //
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if NutDataController.sharedInstance.currentLoggedInUser == nil {
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
            eventEditVC.note = self.note
            APIConnector.connector().trackMetric("Clicked edit a note (Detail screen)")
        } else {
            NSLog("Unprepped segue from eventView \(String(describing: segue.identifier))")
        }
    }
    
    // Back button from group or detail viewer.
    @IBAction func done(_ segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventDetailVC done!")
        if let eventEditVC = segue.source as? EventEditViewController {
            if let originalNote = self.note, let editedNote = eventEditVC.editedNote {
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
    
    @IBAction func cancel(_ segue: UIStoryboardSegue) {
        // Cancel edit...
        NSLog("unwind segue to eventDetail cancel")
    }
    
    // close the VC on button press from leftBarButtonItem
    @IBAction func backButtonPressed(_ sender: Any) {
        APIConnector.connector().trackMetric("Clicked Back View Note")
        self.performSegue(withIdentifier: "unwindSegueToDone", sender: self)
        
    }
    
    @IBAction func editButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: EventViewStoryboard.SegueIdentifiers.EventItemEditSegue, sender: self)
        
    }

    //
    // MARK: - Data vizualization view
    //
    
    // TODO: share this code with EventListViewController!
    enum DataVizDisplayState: Int {
        case initial
        case loadingNoSelect
        case loadingSelected
        case dataGraph
        case noDataDisplay
    }
    private var dataVizState: DataVizDisplayState = .initial
    
    private func updateDataVizForState(_ newState: DataVizDisplayState) {
        if newState == dataVizState {
            NSLog("\(#function) already in state \(newState)")
            return
        }
        NSLog("\(#function) setting new state: \(newState)")
        dataVizState = newState
        var hideLoadingGif = true
        var hideNoDataView = true
        if newState == .initial {
            if (graphContainerView != nil) {
                NSLog("Removing current graph view...")
                graphContainerView?.removeFromSuperview();
                graphContainerView = nil;
            }
        } else if newState == .loadingNoSelect {
            // no item selected, show loading gif, hiding any current data and graph gridlines
            graphContainerView?.displayGraphData(false)
            graphContainerView?.displayGridLines(false)
            hideLoadingGif = false
        } else if newState == .loadingSelected {
            // item selected, show loading gif, hide gridlines, but allow data to load.
            graphContainerView?.displayGraphData(true)
            graphContainerView?.displayGridLines(false)
            hideLoadingGif = false
        } else if newState == .dataGraph {
            // item selected and data found, ensure gridlines are on and data displayed (should already be)
            graphContainerView?.displayGridLines(true)
        } else if newState == .noDataDisplay {
            // item selected, but no data found; hide gridlines and show the no data found overlay
            graphContainerView?.displayGridLines(false)
            hideNoDataView = false
        }
        if loadingAnimationView.isHidden != hideLoadingGif {
            loadingAnimationView.isHidden = hideLoadingGif
            if hideLoadingGif {
                NSLog("\(#function) hide loading gif!")
                animatedLoadingImage.stopAnimating()
            } else {
                NSLog("\(#function) start showing loading gif!")
                animatedLoadingImage.startAnimating()
            }
        }
        if noDataViewContainer.isHidden != hideNoDataView {
            noDataViewContainer.isHidden = hideNoDataView
            NSLog("\(#function) noDataViewContainer.isHidden = \(hideNoDataView)")
        }
    }
    
    fileprivate func selectNote() {
        
        if self.note != nil {
            configureGraphContainer()
        }
    }
    
    fileprivate func recenterGraph() {
        if let graphContainerView = graphContainerView {
            graphContainerView.centerGraphOnEvent(animated: true)
         }
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
        if let note = self.note {
            // TODO: assume all notes created in current timezone?
            let tzOffset = NSCalendar.current.timeZone.secondsFromGMT()
            graphContainerView = TidepoolGraphView.init(frame: graphLayerContainer.frame, delegate: self, mainEventTime: note.timestamp, tzOffsetSecs: tzOffset)
            if let graphContainerView = graphContainerView {
                updateDataVizForState(.loadingSelected)
                graphContainerView.configureGraph(edgeOffset)
                graphContainerView.configureNotesToDisplay([note])
                graphLayerContainer.insertSubview(graphContainerView, at: 0)
                graphContainerView.loadGraphData()
            }
        }
    }
    
    //
    // MARK: - GraphContainerViewDelegate
    //
    
    func containerCellUpdated() {
        if let graphContainerView = graphContainerView {
            let graphHasData = graphContainerView.dataFound()
            NSLog("\(#function) - graphHasData: \(graphHasData)")
            if graphHasData {
                updateDataVizForState(.dataGraph)
            } else {
                // Show the no-data view if not still loading...
                if !DatabaseUtils.sharedInstance.isLoadingTidepoolEvents() {
                    updateDataVizForState(.noDataDisplay)
                } else {
                    NSLog("\(#function): Keep displaying loading screen as load is still in progress")
                }
            }
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
            let nutEventItem = DatabaseUtils.sharedInstance.getNutEventItemWithId(itemId)
            if let nutEventItem = nutEventItem {
                // if the user tapped on some other event, switch to viewing that one instead!
                if nutEventItem.time != note.timestamp {
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
    
    func unhandledTapAtLocation(_ tapLocationInView: CGPoint, graphTimeOffset: TimeInterval) {
        recenterGraph()
    }
    
    @IBAction func howToUploadButtonHandler(_ sender: Any) {
        NSLog("TODO!")
    }
    
    @IBAction func addCommentButtonHandler(_ sender: Any) {
        NSLog("TODO!")
    }
    
}


//
// MARK: - Table view delegate
//

extension EventDetailViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt estimatedHeightForRowAtIndexPath: IndexPath) -> CGFloat {
        return 102.0;
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt heightForRowAtIndexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension;
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        recenterGraph()
    }
    
}

//
// MARK: - Table view data source
//

extension EventDetailViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1 + self.comments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Note: two different list cells are used depending upon whether a location will be shown or not.
        let cellId = EventViewStoryboard.TableViewCellIdentifiers.noteDetailCell
        var note: BlipNote?
        if (indexPath.row == 0) {
            note = self.note
        } else {
            note = self.comments[indexPath.row-1]
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteDetailTableViewCell
        if let note = note {
            cell.configureCell(note)
            let lastRow = tableView.numberOfRows(inSection: 0) - 1
            let isLastRow = indexPath.row == lastRow
            cell.separatorImageView.isHidden = isLastRow
        }
        return cell
    }
    
    
}


