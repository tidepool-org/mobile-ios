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

class EventGroupTableViewController: BaseUITableViewController {

    var eventGroup = NutEvent()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        self.title = eventGroup.title
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return eventGroup.itemArray.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("eventItemCell", forIndexPath: indexPath) as! EventGroupTableViewCell
        
        // Configure the cell...
        if indexPath.item < eventGroup.itemArray.count {
            let eventItem = eventGroup.itemArray[indexPath.item]
            cell.configureCell(eventItem)
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

    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        super.prepareForSegue(segue, sender: sender)
        if segue.identifier == "EventItemDetailSegue" {
            let cell = sender as! EventGroupTableViewCell
            let eventItemVC = segue.destinationViewController as! EventDetailViewController
            eventItemVC.eventItem = cell.eventItem
            eventItemVC.eventGroup = eventGroup
            eventItemVC.title = self.title
        } else if segue.identifier == "EventItemAddSegue" {
            let addEventVC = segue.destinationViewController as! AddEventViewController
            // adding events from group table, pass along title so it can be reused and new event added...
            addEventVC.eventTitleString = eventGroup.title
        }
    }


    @IBAction func groupTableDoneHandler(segue: UIStoryboardSegue) {
        print("done")
        // at this point I need to grab the new event, maybe check for the same title...
        if segue.identifier == "unwindDoneFromAdd" {
            if let addEventVC = segue.sourceViewController as? AddEventViewController {
                if let newEvent = addEventVC.newMealEvent {
                    if newEvent.title == eventGroup.title {
                        eventGroup.addEvent(newEvent)
                        eventGroup.sortEvents()
                        tableView.reloadData()
                    } else {
                        print("new event added with a different title!")
//                        self.performSegueWithIdentifier("unwindSequeToEventList", sender: self)
                    }
                }
            }
        }
    }
    
    @IBAction func groupTableCancelHandler(segue: UIStoryboardSegue) {
        print("cancel")
    }

    @IBAction func addedNewEvent(segue: UIStoryboardSegue) {
        print("addedNewEvent")
    }
    
}


