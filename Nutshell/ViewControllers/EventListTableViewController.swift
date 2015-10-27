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

class EventListTableViewController: BaseUITableViewController {

    @IBOutlet weak var searchTextField: NutshellUITextField!
    @IBOutlet weak var searchPlaceholderLabel: NutshellUILabel!
    
    private var sortedNutEvents = [(String, NutEvent)]()
    private var filteredNutEvents = [(String, NutEvent)]()
    private var filterString = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "All events"
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()

        // Add a notification for when the database changes
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "databaseChanged:", name: NSManagedObjectContextObjectsDidChangeNotification, object: ad.managedObjectContext)
        notificationCenter.addObserver(self, selector: "textFieldDidChange", name: UITextFieldTextDidChangeNotification, object: nil)
   }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private var viewIsForeground: Bool = false
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        viewIsForeground = true

        if sortedNutEvents.isEmpty || eventListNeedsUpdate {
            eventListNeedsUpdate = false
            getNutEvents()
        }
        
        if AppDelegate.testMode {
            // select random cell and push after delay?
        }
     }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        viewIsForeground = false
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        super.prepareForSegue(segue, sender: sender)
        if(segue.identifier) == EventViewStoryboard.SegueIdentifiers.EventGroupSegue {
            let cell = sender as! EventListTableViewCell
            let eventGroupVC = segue.destinationViewController as! EventGroupTableViewController
            cell.eventGroup?.sortEvents()
            eventGroupVC.eventGroup = cell.eventGroup!
        }
    }
    
    @IBAction func nutEventChanged(segue: UIStoryboardSegue) {
        print("unwind segue to eventList addedSomeNewEvent")
    }

    @IBAction func done(segue: UIStoryboardSegue) {
        print("unwind segue to eventList done!")
    }

    @IBAction func cancel(segue: UIStoryboardSegue) {
        print("unwind segue to eventList cancel")
    }

    private var eventListNeedsUpdate: Bool  = false
    func databaseChanged(note: NSNotification) {
        print("EventList: Database Change Notification")
        if viewIsForeground {
            getNutEvents()
        } else {
            eventListNeedsUpdate = true
        }
    }
    
    func getNutEvents() {

        var nutEvents = [String: NutEvent]()

        func addNewEvent(newEvent: EventItem) {
            let newEventId = newEvent.nutEventIdString()
            if let existingNutEvent = nutEvents[newEventId] {
                existingNutEvent.addEvent(newEvent)
                print("appending new event: \(newEvent.notes)")
                existingNutEvent.printNutEvent()
            } else {
                nutEvents[newEventId] = NutEvent(firstEvent: newEvent)
            }
        }

        sortedNutEvents = [(String, NutEvent)]()
        filteredNutEvents = [(String, NutEvent)]()
        filterString = ""
        
        // Get all Food and Activity events, chronologically; this will result in an unsorted dictionary of NutEvents.
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate

        do {
            let nutEvents = try DatabaseUtils.getAllNutEvents(ad.managedObjectContext)
            for event in nutEvents {
                print("Event type: \(event.type), time: \(event.time), title: \(event.title), notes: \(event.notes)")
                addNewEvent(event)
            }
        } catch let error as NSError {
            print("Error: \(error)")
        }
        
        sortedNutEvents = nutEvents.sort() { $0.1.mostRecent.compare($1.1.mostRecent) == NSComparisonResult.OrderedDescending }
        updateFilteredAndReload()
    }
    
    @IBAction func menuButtonHandler(sender: AnyObject) {
        self.navigationItem.title = ""
        let sb = UIStoryboard(name: "Menu", bundle: nil)
        if let vc = sb.instantiateInitialViewController() {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    // MARK: - Search
    
    func textFieldDidChange() {
        updateFilteredAndReload()
    }

    @IBAction func searchEditingDidEnd(sender: AnyObject) {
        configureSearchUI()
    }
    
    @IBAction func searchEditingDidBegin(sender: AnyObject) {
        configureSearchUI()
    }
    
    private func searchMode() -> Bool {
        var searchMode = false
        if searchTextField.isFirstResponder() {
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
        searchPlaceholderLabel.hidden = searchOn
        self.title = searchOn ? "Matching events" : "All events"
    }

    private func updateFilteredAndReload() {
        if !searchMode() {
            filteredNutEvents = sortedNutEvents
            filterString = ""
        }
        if let searchText = searchTextField.text {
            if !searchText.isEmpty {
                if searchText.localizedCaseInsensitiveContainsString(filterString) {
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
        }
        tableView.reloadData()
    }
}

// MARK: - Table view data source

extension EventListTableViewController {
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredNutEvents.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(EventViewStoryboard.TableViewCellIdentifiers.eventListCell, forIndexPath: indexPath) as! EventListTableViewCell
        
        if (indexPath.item < filteredNutEvents.count) {
            let tuple = self.filteredNutEvents[indexPath.item]
            let nutEvent = tuple.1
            cell.configureCell(nutEvent)
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
