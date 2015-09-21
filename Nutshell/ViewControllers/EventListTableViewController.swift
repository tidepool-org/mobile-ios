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

    private var sortedNutEvents = [(String, NutEvent)]()
  
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "All events"
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Add a notification for when the database changes
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "databaseChanged:", name: NSManagedObjectContextObjectsDidChangeNotification, object: ad.managedObjectContext)

        getNutEvents()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop observing notifications
        NSNotificationCenter.defaultCenter().removeObserver(self)
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
            eventGroupVC.eventGroup = cell.eventGroup
        }
    }
    
    
    func databaseChanged(note: NSNotification) {
        print("EventList: Database Changed")
        sortedNutEvents = [(String, NutEvent)]()
        getNutEvents()
    }
    
    func getNutEvents() {

        var nutEvents = [String: NutEvent]()

        func addNewEvent(newEvent: Food) {
            if let existingNutEvent = nutEvents[newEvent.name!] {
                existingNutEvent.addEvent(newEvent)
                print("appending new event: \(newEvent.location)")
                existingNutEvent.printNutEvent()
            } else {
                nutEvents[newEvent.name!] = NutEvent(firstEvent: newEvent)
            }
        }

        // Get all Food and Activity events, chronologically. Create a dictionary of NutEvents, with 
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate

        do {
            let foodEvents = try DatabaseUtils.getAllFoodEvents(ad.managedObjectContext)
            for event in foodEvents {
                print("Event type: \(event.type), time: \(event.time), carbs: \(event.carbs), location: \(event.location), name: \(event.name)")
                addNewEvent(event)
            }
        } catch let error as NSError {
            print("Error: \(error)")
        }
        
        sortedNutEvents = nutEvents.sort() { $0.1.mostRecent.compare($1.1.mostRecent) == NSComparisonResult.OrderedDescending }
        
        tableView.reloadData()
    }
    
    func getEvents() {
        // Get the last month's worth of events
//        let ad = UIApplication.sharedApplication().delegate as! AppDelegate
//
//        let cal = NSCalendar.currentCalendar()
//        let fromTime = cal.dateByAddingUnit(.Month, value: -1, toDate: NSDate(), options: NSCalendarOptions(rawValue: 0))!
//        let toTime = NSDate()
//        
//        do {
//            let events = try DatabaseUtils.getBolusEvents(ad.managedObjectContext, fromTime: fromTime, toTime: toTime)
//                for event in events {
//                    if event.type == "SelfMonitoringGlucose" {
//                        print("Event: \(event)")
//                    }
//                    print("Event: \(event)")
//                }
//            print("\(events.count) events")
//
//        } catch let error as NSError {
//            print("Error: \(error)")
//        }

//        do {
//            let cbgEvents = try DatabaseUtils.getAllCbgEvents(ad.managedObjectContext)
//            for event in cbgEvents {
//                print("Event type: \(event.type), time: \(event.time), isig: \(event.isig), value: \(event.value)")
//            }
//        } catch let error as NSError {
//            print("Error: \(error)")
//        }
//        
//        do {
//            let basalEvents = try DatabaseUtils.getAllBasalEvents(ad.managedObjectContext)
//            for event in basalEvents {
//                print("Event type: \(event.type), time: \(event.time), duration: \(event.duration), value: \(event.value)")
//            }
//        } catch let error as NSError {
//            print("Error: \(error)")
//        }
        

//        do {
//            let foodEvents = try DatabaseUtils.getAllFoodEvents(ad.managedObjectContext)
//            for event in foodEvents {
//                print("Event type: \(event.type), time: \(event.time), carbs: \(event.carbs), location: \(event.location), name: \(event.name)")
//            }
//        } catch let error as NSError {
//            print("Error: \(error)")
//        }
//        
//        do {
//            let mixedEvents = try DatabaseUtils.getSmbgAndBolusEvents(ad.managedObjectContext)
//            for event in mixedEvents {
//                print("Event type: \(event.type), time: \(event.time), type: \(event.type)")
//                if (event.type == "bolus") {
//                    if let bolusEvent = event as? Bolus {
//                        print("Value: \(bolusEvent.value)")
//                    }
//                }
//            }
//        } catch let error as NSError {
//            print("Error: \(error)")
//        }

//        do {
//            let smbgEvents = try DatabaseUtils.getAllSmbgEvents(ad.managedObjectContext)
//            for event in smbgEvents {
//                print("Event type: \(event.type), time: \(event.time), subType: \(event.subType), value: \(event.value)")
//            }
//        } catch let error as NSError {
//            print("Error: \(error)")
//        }

//        do {
//            let activityEvents = try DatabaseUtils.getAllActivityEvents(ad.managedObjectContext)
//            for event in activityEvents {
//                print("Event type: \(event.type), time: \(event.time), subType: \(event.subType), duration: \(event.duration), location: \(event.location)")
//            }
//        } catch let error as NSError {
//            print("Error: \(error)")
//        }

    }
}

// MARK: - Table view data source
extension EventListTableViewController {
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedNutEvents.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(EventViewStoryboard.TableViewCellIdentifiers.eventListCell, forIndexPath: indexPath) as! EventListTableViewCell

        if (indexPath.item < sortedNutEvents.count) {
            let tuple = self.sortedNutEvents[indexPath.item]
            let nutEvent = tuple.1
            // Configure the cell...
            cell.textLabel?.text = nutEvent.title
            cell.eventGroup = nutEvent
        }
        
        return cell
    }

    // MARK: - Nav bar button handlers

    @IBAction func addEventButtonHandler(sender: UIBarButtonItem) {
        self.navigationItem.title = ""
        let sb = UIStoryboard(name: "AddEvent", bundle: nil)
        let vc = sb.instantiateViewControllerWithIdentifier("AddEventViewController")
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func menuButtonHandler(sender: AnyObject) {
        self.navigationItem.title = ""
        let sb = UIStoryboard(name: "Menu", bundle: nil)
        if let vc = sb.instantiateInitialViewController() {
            self.navigationController?.pushViewController(vc, animated: true)
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
