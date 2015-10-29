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

class EventGroupTableViewController: BaseUITableViewController {

    var eventGroup = NutEvent()
    @IBOutlet weak var titleTextField: NutshellUITextField!

    @IBOutlet weak var tableHeaderTitle: NutshellUILabel!
    @IBOutlet weak var tableHeaderLocation: NutshellUILabel!
    @IBOutlet weak var tableHeaderCount: NutshellUILabel!
    @IBOutlet weak var headerView: NutshellUIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = ""

        tableHeaderTitle.text = eventGroup.title
        tableHeaderLocation.text = eventGroup.location
        tableHeaderCount.text = "x " + String("\(eventGroup.itemArray.count)")
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if eventGroup.itemArray.count == 0 {
            self.performSegueWithIdentifier("unwindSequeToEventList", sender: self)
            return
        }
        eventGroup.sortEvents()
        tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //
    // MARK: - Button handling
    //
    
    
    @IBAction func disclosureTouchDownHandler(sender: AnyObject) {
    }
    
    //
    // MARK: - Navigation
    // 
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        super.prepareForSegue(segue, sender: sender)
        if segue.identifier == EventViewStoryboard.SegueIdentifiers.EventItemDetailSegue {
            let cell = sender as! EventGroupTableViewCell
            let eventItemVC = segue.destinationViewController as! EventDetailViewController
            eventItemVC.eventItem = cell.eventItem
            eventItemVC.eventGroup = eventGroup
            eventItemVC.title = self.title
        } else if segue.identifier == EventViewStoryboard.SegueIdentifiers.EventItemAddSegue {
            let eventItemVC = segue.destinationViewController as! EventAddOrEditViewController
            // no existing item to pass along...
            eventItemVC.eventGroup = eventGroup
        } else {
            NSLog("Unknown segue from eventGroup \(segue.identifier)")
        }
    }

    @IBAction func nutGroupChanged(segue: UIStoryboardSegue) {
        print("unwind segue to eventGroup")
    }

    @IBAction func done(segue: UIStoryboardSegue) {
        print("unwind segue to eventGroup done")
    }
    
    @IBAction func cancel(segue: UIStoryboardSegue) {
        print("unwind segue to eventGroup cancel")
    }
    
}

// MARK: - Table view delegate

//extension EventGroupTableViewController {
//    
//    override func tableView(tableView: UITableView,
//        viewForHeaderInSection section: Int) -> UIView? {
//            
//            return headerView
//    }
//
//    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//            return 95.0
//    }
//    
//}

//
// MARK: - Table view data source
//

extension EventGroupTableViewController {

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
    
    override func tableView(tableView: UITableView,
        editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
            let rowAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: "delete") {_,indexPath in

                // Delete the row from the data source
                let eventItem = self.eventGroup.itemArray.removeAtIndex(indexPath.item)
                let ad = UIApplication.sharedApplication().delegate as! AppDelegate
                let moc = ad.managedObjectContext
                if let mealItem = eventItem as? NutMeal {
                    moc.deleteObject(mealItem.meal)
                } else if let workoutItem = eventItem as? NutWorkout {
                    moc.deleteObject(workoutItem.workout)
                }
                DatabaseUtils.databaseSave(moc)
                // Now delete the row...
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
                if self.eventGroup.itemArray.count == 0 {
                    self.performSegueWithIdentifier("unwindSequeToEventList", sender: self)
                }
                return
            }
            rowAction.backgroundColor = Styles.peachDeleteColor
            return [rowAction]
    }

    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        print("commitEditingStyle forRowAtIndexPath")
    }

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

