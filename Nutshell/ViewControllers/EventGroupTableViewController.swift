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

    var eventGroup: NutEvent?

    @IBOutlet weak var tableHeaderTitle: NutshellUILabel!
    @IBOutlet weak var tableHeaderLocation: NutshellUILabel!
    @IBOutlet weak var headerView: NutshellUIView!
    @IBOutlet weak var headerViewLocIcon: UIImageView!
    @IBOutlet weak var innerHeaderView: UIView!
    @IBOutlet weak var eatAgainButton: UIButton!
    @IBOutlet weak var eatAgainLabel: NutshellUILabel!
    @IBOutlet weak var eatAgainLargeHitArea: UIButton!
    
    fileprivate var isWorkout: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.leftBarButtonItem?.imageInsets = UIEdgeInsetsMake(0.0, -8.0, -1.0, 0.0)
}
    
    override func viewWillAppear(_ animated: Bool) {
        NSLog("Event group viewWillAppear")
        super.viewWillAppear(animated)
        APIConnector.connector().trackMetric("Viewed Similar Meals Screen (Similar Meals Screen)")
        
        if let eventGroup = eventGroup {
            if eventGroup.itemArray.count >= 1 {
                configureGroupView()
                eventGroup.sortEvents()
                tableView.reloadData()
                return
            }
        }
        
        // empty group!
        self.performSegue(withIdentifier: "unwindSegueToHome", sender: self)
    }

    override func viewDidLayoutSubviews() {
        // Workaround: iOS currently doesn't resize table headers dynamically
        if let headerView = headerView {
            let height = ceil(innerHeaderView.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height)
            var frame = headerView.frame
            if frame.size.height != height {
                NSLog("adjusting header height from \(frame.size.height) to \(height)")
                frame.size.height = height
                headerView.frame = frame
                // set it back so table will adjust as well...
                tableView.tableHeaderView = headerView
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    fileprivate func configureGroupView() {
        title = ""
        
        if let eventGroup = eventGroup {
            isWorkout = eventGroup.isWorkout
            eatAgainButton.isHidden = isWorkout
            eatAgainLabel.isHidden = isWorkout
            eatAgainLargeHitArea.isHidden = isWorkout
            
            tableHeaderTitle.text = eventGroup.title
            tableHeaderLocation.text = eventGroup.location
            headerViewLocIcon.isHidden = (tableHeaderLocation.text?.isEmpty)!
        }
    }
    
    //
    // MARK: - Button handling
    //
    
    
    @IBAction func disclosureTouchDownHandler(_ sender: AnyObject) {
    }
    
    @IBAction func backButtonHandler(_ sender: AnyObject) {
        APIConnector.connector().trackMetric("Clicked Back to All Events (Similar Meals Screen)")
        self.performSegue(withIdentifier: "unwindSegueToDone", sender: self)
    }

    //
    // MARK: - Navigation
    // 
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        super.prepare(for: segue, sender: sender)
        if segue.identifier == EventViewStoryboard.SegueIdentifiers.EventItemDetailSegue {
            let eventItemVC = segue.destination as! EventDetailViewController
            eventItemVC.eventGroup = eventGroup
            eventItemVC.title = self.title
            if let cell = sender as? EventGroupTableViewCell {
                eventItemVC.eventItem = cell.eventItem
            } else if let collectCell = sender as? EventGroupRowCollectionCell {
                eventItemVC.eventItem = collectCell.eventItem
            }
            APIConnector.connector().trackMetric("Clicked a Meal Instance (Similar Meals Screen)")
         } else if segue.identifier == EventViewStoryboard.SegueIdentifiers.EventItemAddSegue {
            let eventItemVC = segue.destination as! EventAddOrEditViewController
            // no existing item to pass along...
            eventItemVC.eventGroup = eventGroup
            APIConnector.connector().trackMetric("Clicked Eat Again (Similar Meals Screen)")
        } else {
            NSLog("Unknown segue from eventGroup \(segue.identifier)")
        }
    }

    @IBAction func done(_ segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventGroup done")
        doneCommon(segue)
    }

    @IBAction func doneItemDeleted(_ segue: UIStoryboardSegue) {
        NSLog("unwind segue to eventGroup doneItemDeleted")
        doneCommon(segue)
    }
    
    fileprivate func doneCommon(_ segue: UIStoryboardSegue) {
        // update group in case it has changed!
        if let eventDetailVC = segue.source as? EventDetailViewController {
            self.eventGroup = eventDetailVC.eventGroup
        } else if let eventAddOrEditVC = segue.source as? EventAddOrEditViewController {
            self.eventGroup = eventAddOrEditVC.eventGroup
        }
    }
    
    @IBAction func cancel(_ segue: UIStoryboardSegue) {
        print("unwind segue to eventGroup cancel")
    }
}

//
// MARK: - Table view delegate
//


extension EventGroupTableViewController {

    fileprivate func itemAtIndexPathHasPhoto(_ indexPath: IndexPath) -> Bool {
        if indexPath.item < eventGroup!.itemArray.count {
            let eventItem = eventGroup!.itemArray[indexPath.item]
            if let mealItem = eventItem as? NutMeal {
                let photoUrl = mealItem.firstPictureUrl()
                return !photoUrl.isEmpty
            }
        }
        return false
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return itemAtIndexPathHasPhoto(indexPath) ? 164.0 : 80.0
    }
    
}

//
// MARK: - Table view data source
//

extension EventGroupTableViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return eventGroup!.itemArray.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "eventItemCell", for: indexPath) as! EventGroupTableViewCell
        //NSLog("Event group cellForRowAtIndexPath: \(indexPath)")
       
        // Configure the cell...
        if indexPath.item < eventGroup!.itemArray.count {
            let eventItem = eventGroup!.itemArray[indexPath.item]
            cell.configureCell(eventItem)
            if eventItem.nutCracked {
                APIConnector.connector().trackMetric("Cracked Nut Badge Appears (Similar Meals Screen)")
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
            let rowAction = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: "delete") {_,indexPath in
                // use dialog to confirm delete with user!
                let alert = UIAlertController(title: NSLocalizedString("deleteMealAlertTitle", comment:"Are you sure?"), message: NSLocalizedString("deleteMealAlertMessage", comment:"If you delete this meal, it will be gone forever."), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("deleteAlertCancel", comment:"Cancel"), style: .cancel, handler: { Void in
                    return
                }))
                alert.addAction(UIAlertAction(title: NSLocalizedString("deleteAlertOkay", comment:"Delete"), style: .default, handler: { Void in
                    // Delete the row from the data source
                    let eventItem = self.eventGroup!.itemArray[indexPath.item]
                    if eventItem.deleteItem() {
                        // Delete the row...
                        tableView.deleteRows(at: [indexPath], with: .fade)
                        self.eventGroup!.itemArray.remove(at: indexPath.item)
                        if self.eventGroup!.itemArray.count == 0 {
                            self.performSegue(withIdentifier: "unwindSegueToHome", sender: self)
                        }
                    }
                    return
                }))
                self.present(alert, animated: true, completion: nil)
            }
            rowAction.backgroundColor = Styles.peachDeleteColor
            return [rowAction]
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Remove support for delete at this point...
        return false
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
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

