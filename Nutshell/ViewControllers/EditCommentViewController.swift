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
import CoreData
import MessageUI
import CocoaLumberjack

class EditCommentViewController: BaseUIViewController, UITextViewDelegate {

    
    @IBOutlet weak var editCommentSceneContainer: UIView!
    @IBOutlet weak var navItem: UINavigationItem!
    
    @IBOutlet weak var tableView: NutshellUITableView!

    // Configured by calling VC
    var note: BlipNote?
    var comments: [BlipNote] = []
    // New comment returned to calling VC
    var newComment: BlipNote?
    
    // Current "add comment" edit info, if edit in progress
    fileprivate var currentCommentEditCell: NoteListEditCommentCell?

    // Misc
    let dataController = NutDataController.sharedInstance

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.title = dataController.currentViewedUser?.fullName ?? ""
        
        // Add a notification for when the database changes
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.textFieldDidChangeNotifyHandler(_:)), name: NSNotification.Name.UITextFieldTextDidChange, object: nil)
        // graph data changes
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.graphDataChanged(_:)), name: NSNotification.Name(rawValue: NewBlockRangeLoadedNotification), object: nil)
        // keyboard up/down
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(EventListViewController.reachabilityChanged(_:)), name: ReachabilityChangedNotification, object: nil)
        configureForReachability()
    }
   
    // delay manual layout until we know actual size of container view (at viewDidLoad it will be the current storyboard size)
    private var subviewsInitialized = false
    override func viewDidLayoutSubviews() {
        if (subviewsInitialized) {
            return
        }
        subviewsInitialized = true
        
        editCommentSceneContainer.setNeedsLayout()
        editCommentSceneContainer.layoutIfNeeded()
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    fileprivate var viewIsForeground: Bool = false
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewIsForeground = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewIsForeground = false
    }

    func reachabilityChanged(_ note: Notification) {
        configureForReachability()
    }

    fileprivate func configureForReachability() {
        let connected = APIConnector.connector().isConnectedToNetwork()
        //missingDataAdvisoryTitle.text = connected ? "There is no data in here!" : "You are currently offline!"
        NSLog("TODO: figure out connectivity story! Connected: \(connected)")
    }

    fileprivate func networkIsUnreachable(alertUser: Bool) -> Bool {
        if APIConnector.connector().serviceAvailable() {
            return false
        }
        let alert = UIAlertController(title: "Not Connected to Network", message: "This application requires a network to access the Tidepool service!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { Void in
            return
        }))
        self.present(alert, animated: true, completion: nil)
        return true
    }
    
    //
    // MARK: - View handling for keyboard
    //
    
    private var viewAdjustAnimationTime: TimeInterval = 0.25
    private var keyboardFrame: CGRect?
    
    // For add comment editing, scroll table so edit view is just above the keyboard when it opens.
    // Also captures keyboard sizing and appropriate scroll animation timing.
    func keyboardWillShow(_ notification: Notification) {
        NSLog("\(#function)")
        viewAdjustAnimationTime = notification.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! TimeInterval
        keyboardFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        self.adjustKeyboardSpacerView() // first time, ensure we have a table footer for last cell special case
        self.adjustEditAboveKeyboard()
    }
 
    // Ensure there is enough table footer to allow add comment editing for last note
    fileprivate func adjustKeyboardSpacerView() {
        if let keyboardFrame = keyboardFrame {
            // add a footer view to the table that is the size of the keyboard, so last table row can be scrolled to the top of the table if necessary
            let height = keyboardFrame.height
            let curTableFooter = self.tableView.tableFooterView
            if curTableFooter != nil && curTableFooter!.bounds.height >= height {
                // table already adjusted...
                return
            }
            
            // add a footer view, possibly replace one that is too short (e.g., search keyboard is somewhat smaller than new comment edit keyboard)
            var footerFrame = self.tableView.bounds
            footerFrame.size.height = height
            let footerView = UIView(frame: footerFrame)
            footerView.backgroundColor = UIColor.white
            self.tableView.tableFooterView = footerView
        }
    }
    
    //
    // MARK: - Notes methods
    //
    
    func commentForIndexPath(_ indexPath: IndexPath) -> BlipNote? {
        let commentIndex = indexPath.row - 1
        if commentIndex < comments.count {
            return comments[commentIndex]
        }
        NSLog("\(#function): index \(indexPath) out of range of comment count \(comments.count)!!!")
        return nil
    }
    
    //
    // MARK: - Navigation
    //
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        super.prepare(for: segue, sender: sender)
    }
    
    /// Works with graphDataChanged to ensure graph is up-to-date after notification of database changes whether this VC is in the foreground or background.
    fileprivate func checkUpdateGraph() {
        NSLog("\(#function)")
        if graphNeedsUpdate {
            graphNeedsUpdate = false
            for cell in tableView.visibleCells {
                guard let graphCell = cell as? NoteListGraphCell else { continue }
                graphCell.updateGraph()
            }
        }
    }

    @IBAction func backButtonHandler(_ sender: Any) {
        performSegue(withIdentifier: "unwindFromEditComment", sender: self)
    }
    
    @IBAction func postButtonHandler(_ sender: Any) {
        if networkIsUnreachable(alertUser: true) {
            return
        }
        
        // post new comment!
        if let currentEditCell = currentCommentEditCell {
            if let note = self.note {
                let commentText = currentEditCell.addCommentTextView.text
                if commentText?.isEmpty == false {
                    let newNote = BlipNote()
                    newNote.user = dataController.currentLoggedInUser!
                    newNote.groupid = note.groupid
                    newNote.messagetext = commentText!
                    newNote.parentmessage = note.id
                    newNote.timestamp = Date()
                    newComment = newNote
                    performSegue(withIdentifier: "unwindFromEditComment", sender: self)
                }
            }
        }
    }
    
    //
    // MARK: - Graph support
    //

    fileprivate var graphNeedsUpdate: Bool  = false
    func graphDataChanged(_ note: Notification) {
        graphNeedsUpdate = true
        if viewIsForeground {
            NSLog("EventListVC: graphDataChanged, reloading")
            checkUpdateGraph()
        } else {
            NSLog("EventListVC: graphDataChanged, in background")
        }
    }
    

    //
    // MARK: - Add Comment UITextField Handling
    //
    
    func textViewDidChangeNotifyHandler(_ note: Notification) {
        if let textView = note.object as? UITextView {
            if textView == self.currentCommentEditCell?.addCommentTextView {
                NSLog("note changed to \(textView.text)")
            }
        }
    }
    
    
    // UITextViewDelegate methods
    func textViewDidChange(_ textView: UITextView) {
        NSLog("current content offset: \(tableView.contentOffset.y)")
        if textView == self.currentCommentEditCell?.addCommentTextView {
            NSLog("note changed to \(textView.text)")
            // adjust table if lines of text have changed...
            tableView.beginUpdates()
            tableView.endUpdates()
            adjustEditAboveKeyboard()
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == self.currentCommentEditCell?.addCommentTextView {
            NSLog("\(#function)")
        }
    }

    func adjustEditAboveKeyboard() {
        if let curEditCell = currentCommentEditCell, let keyboardFrame = keyboardFrame {
            let cellContentOffset = curEditCell.frame.origin.y
            let sizeAboveKeyboard = tableView.bounds.height - keyboardFrame.height
            var targetOffset = tableView.contentOffset
            // minus 10 for 10 of the 12 note boundary separator pixels... 
            targetOffset.y = cellContentOffset - sizeAboveKeyboard  + curEditCell.bounds.height - 10.0
            if tableView.contentOffset.y < targetOffset.y {
                NSLog("setting table offset to \(targetOffset.y)")
                tableView.setContentOffset(targetOffset, animated: true)
            }
        }
    }

    
    //
    // MARK: - Table Misc
    //
    
    fileprivate let kNoteRow: Int = 0
    fileprivate let kGraphRow: Int = 1
    fileprivate let kPreCommentRows: Int = 2
    fileprivate let kDefaultAddCommentRow: Int = 2 // when there are no comments!
    fileprivate let kFirstCommentRow: Int = 2
    
    fileprivate func addCommentRow(commentCount: Int) -> Int {
        return kPreCommentRows + commentCount
    }
    
}

//
// MARK: - Table view delegate
//

extension EditCommentViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt estimatedHeightForRowAtIndexPath: IndexPath) -> CGFloat {
        return 90.0;
    }

    func tableView(_ tableView: UITableView, heightForRowAt heightForRowAtIndexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension;
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
}


//
// MARK: - Table view data source
//

extension EditCommentViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.note != nil ? 1 : 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // one row for note, one row for graph, one row per comment, one for add comment
        return self.comments.count + 3
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if (indexPath.section != 0) {
            DDLogError("No note at cellForRowAt row \(indexPath.section)")
            return UITableViewCell()
        }
        
        let row = indexPath.row
        
        if row == kNoteRow {
            let group = dataController.currentViewedUser!
            let cellId = "noteListCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListTableViewCell
            cell.configureCell(note!, group: group)
            cell.editButton.isHidden = true
            return cell
        } else if row == kGraphRow {
            let cellId = "noteListGraphCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListGraphCell
            // graph does not have constraints, and since the cell hasn't been added to the parent table yet, size is storyboard size...
            cell.bounds.size.width = tableView.bounds.width
            cell.configureCell(note!)
            cell.configureGraphContainer()
            return cell
        } else if row == addCommentRow(commentCount: comments.count) {
            // Last row is add comment...
            let cellId = "editCommentCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListEditCommentCell
            // need to get from text view back to cell!
            cell.addCommentTextView.tag = indexPath.section
            cell.configureCell(startText: "", delegate: self)
            self.currentCommentEditCell = cell
            cell.addCommentTextView.perform(
                #selector(becomeFirstResponder),
                with: nil,
                afterDelay: 0.25)
            return cell
        } else {
            // Other rows are comment rows
            if row < kFirstCommentRow + comments.count {
                let comment = comments[row-kFirstCommentRow]
                let cell = tableView.dequeueReusableCell(withIdentifier: "noteListCommentCell", for: indexPath) as! NoteListCommentCell
                cell.configureCell(comment)
                cell.editButton.isHidden = false
                return cell
            } else {
                DDLogError("No comment at cellForRowAt \(indexPath)")
                return UITableViewCell()
            }
        }
    }
}

