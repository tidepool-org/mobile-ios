/*
 * Copyright (c) 2017, Tidepool Project
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
import Alamofire
import SwiftyJSON
import CocoaLumberjack

class SwitchProfileTableViewController: BaseUITableViewController, UsersFetchAPIWatcher {

    var newViewedUser: BlipUser?
    private var tableUsers: [BlipUser] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // For now, fetch profile users each time
        if let mainUser = TidepoolMobileDataController.sharedInstance.currentLoggedInUser {
            tableUsers = [mainUser]
        }
        
        self.tableView.reloadData()
        APIConnector.connector().getAllViewableUsers(self)
        // will be called back below at viewableUsers
    }

    //
    // MARK: - UsersFetchAPIWatcher delegate
    //
    
    func viewableUsers(_ userIds: [String]) {
        var profileUsers: [BlipUser] = []
        for userId in userIds {
            APIConnector.connector().fetchProfile(userId) { (result:Alamofire.Result<JSON>) -> (Void) in
                DDLogInfo("viewableUsers profile fetch result: \(result)")
                if (result.isSuccess) {
                    if let json = result.value {
                        let user = BlipUser(userid: userId)
                        user.processProfileJSON(json)
                        profileUsers.append(user)
                        // add any other users...
                        if user.userid != TidepoolMobileDataController.sharedInstance.currentUserId! {
                            self.tableUsers.append(user)
                        }
                        if profileUsers.count == userIds.count {
                            self.tableView.reloadData()
                        }
                    }
                }
            }
            
        }
    }

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableUsers.count
    }

    // basicProfileCell
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = indexPath.row == 0 ?
            tableView.dequeueReusableCell(withIdentifier: "profileTableCellLoggedInUser", for: indexPath) as! ProfileListLoggedInUserTableViewCell :
            tableView.dequeueReusableCell(withIdentifier: "profileTableCell", for: indexPath) as! ProfileListTableViewCell
        
        if indexPath.row < tableUsers.count {
            let user = tableUsers[indexPath.row]
            if indexPath.row == 0 {
                // Configure the cell...
                cell.nameLabel?.text = "(You) " + (user.fullName ?? "")
            } else {
                cell.nameLabel?.text = user.fullName ?? ""
            }
            if user.userid == TidepoolMobileDataController.sharedInstance.currentViewedUser!.userid {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        self.newViewedUser = tableUsers[indexPath.row] 
        self.performSegue(withIdentifier: "segueBackFromSwitchProfile", sender: self)
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
