//
//  SwitchProfileTableViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 3/30/17.
//  Copyright © 2017 Tidepool. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import CocoaLumberjack

class SwitchProfileTableViewController: BaseUITableViewController, UsersFetchAPIWatcher {

    var currentUser: BlipUser!
    var newUser: BlipUser?
    private var tableUsers: [BlipUser] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // For now, fetch profile users each time
        if let mainUser = NutDataController.sharedInstance.currentBlipUser {
            tableUsers = [mainUser]
        }
        
        self.tableView.reloadData()
        APIConnector.connector().getAllViewableUsers(self)
        // will be called back below at viewableUsers
    }

    //
    // MARK: - UsersFetchAPIWatcher delegate
    //
    
    private var profileUsers: [BlipUser] = []
    private var groupUserIds: [String] = []
    func viewableUsers(_ userIds: [String]) {
        self.groupUserIds = userIds
        for userId in userIds {
            APIConnector.connector().fetchProfile(userId) { (result:Alamofire.Result<JSON>) -> (Void) in
                NSLog("Profile fetch result: \(result)")
                if (result.isSuccess) {
                    if let json = result.value {
                        let user = BlipUser(userid: userId)
                        user.processProfileJSON(json)
                        self.profileUsers.append(user)
                        // add any other users...
                        if user.userid != NutDataController.sharedInstance.currentUserId! {
                            self.tableUsers.append(user)
                        }
                        if self.profileUsers.count == self.groupUserIds.count {
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "profileTableCell", for: indexPath) as! ProfileListTableViewCell
        // TODO: support for other users in profile...
        if indexPath.row < tableUsers.count {
            let user = tableUsers[indexPath.row]
            if indexPath.row == 0 {
                // Configure the cell...
                cell.nameLabel?.text = "(You) " + (user.fullName ?? "")
            } else {
                cell.nameLabel?.text = user.fullName ?? ""
            }
            if user.userid == currentUser.userid {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        self.newUser = tableUsers[indexPath.row] 
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
