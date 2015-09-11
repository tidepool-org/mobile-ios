//
//  EventListTableViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/4/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class EventListTableViewController: BaseTableTableViewController {

    var eventList: NSArray
  
    required init?(coder aDecoder: NSCoder) {
        eventList = []
        super.init(coder: aDecoder)
    }

    deinit {
        let nc = NSNotificationCenter.defaultCenter()
        nc.removeObserver(self, name: "EventListChanged", object: nil)
    }

    func updateEventList(notification: NSNotification) {
        self.eventList = EventListDB.testNutEventList();
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let nc = NSNotificationCenter.defaultCenter()
        // Note colon since processBigEvent takes a parameter
        nc.addObserver(self, selector:"updateEventList:", name: "EventListChanged", object: nil)

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        self.eventList = EventListDB.testNutEventList();
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
        return self.eventList.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("eventlistcell", forIndexPath: indexPath) as! EventListTableViewCell

        if (indexPath.item < self.eventList.count) {
            let event = self.eventList[indexPath.item] as! NutEvent
            // Configure the cell...
            cell.textLabel?.text = event.title
            cell.eventGroup = event
        }
        
        return cell
    }

    @IBAction func menuButtonHandler(sender: AnyObject) {
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

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if(segue.identifier) == "eventGroupSegue" {
            let cell = sender as! EventListTableViewCell
            let eventGroupVC = segue.destinationViewController as! EventGroupTableViewController
            eventGroupVC.eventGroup = cell.eventGroup
        }
    }

}
