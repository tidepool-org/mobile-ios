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
    
    @IBOutlet weak var tableView: TidepoolMobileUITableView!

    // Configured by calling VC
    var note: BlipNote?             // must be set
    var commentToEdit: BlipNote?    // set if editing an existing comment
    var comments: [BlipNote] = []   // existing set of comments for the note
    // New comment returned to calling VC, if adding...
    var newComment: BlipNote?
    
    // Current "add comment" edit info, if edit in progress
    fileprivate var currentCommentEditCell: NoteListEditCommentCell?

    // Misc
    let dataController = TidepoolMobileDataController.sharedInstance

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = commentToEdit != nil ? "Edit Comment" : "Add Comment"
        
        // Add notification observers...
        let notificationCenter = NotificationCenter.default
        // graph data changes
        notificationCenter.addObserver(self, selector: #selector(EditCommentViewController.graphDataChanged(_:)), name: Notification.Name(rawValue: NewBlockRangeLoadedNotification), object: nil)
        // keyboard up/down
        notificationCenter.addObserver(self, selector: #selector(EditCommentViewController.keyboardWillShow(_:)), name: Notification.Name.UIKeyboardWillShow, object: nil)
        configureTableSize()
    }
   
    // delay manual layout until we know actual size of container view (at viewDidLoad it will be the current storyboard size)
    private var subviewsInitialized = false
    override func viewDidLayoutSubviews() {
        //DDLogInfo("\(#function)")
        if (subviewsInitialized) {
            return
        }
        subviewsInitialized = true
        
        editCommentSceneContainer.setNeedsLayout()
        editCommentSceneContainer.layoutIfNeeded()
        self.tableView.rowHeight = UITableViewAutomaticDimension
        
        // ensure row with edit is visible so keyboard will come up!
        self.tableView.scrollToRow(at: indexPathOfRowWithEdit(), at: .none, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //DDLogInfo("\(#function)")
        self.currentCommentEditCell?.addCommentTextView.becomeFirstResponder()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.currentCommentEditCell?.addCommentTextView.resignFirstResponder()
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

    //
    // MARK: - View handling for keyboard
    //
    
    private var viewAdjustAnimationTime: TimeInterval = 0.25
    static var keyboardFrame: CGRect?
    
    // Capture keyboard sizing and appropriate scroll animation timing. Fine tune table sizing for current keyboard sizing, and place edit row at bottom of table view, just above the keyboard.
    @objc func keyboardWillShow(_ notification: Notification) {
        //DDLogInfo("EditCommentViewController \(#function)")
        viewAdjustAnimationTime = notification.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! TimeInterval
        EditCommentViewController.keyboardFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        self.configureTableSize() // first time, ensure table is correctly sized to leave room for keyboard
        self.adjustEditAboveKeyboard()
    }

    
    @IBOutlet weak var tableToBottomConstraint: NSLayoutConstraint!
    private func configureTableSize() {
        var keyboardHeight: CGFloat = 258.0
        if let keyboardFrame = EditCommentViewController.keyboardFrame {
            keyboardHeight = keyboardFrame.height
        }
        // leave 4 pixels at bottom to show row bottom border
        tableToBottomConstraint.constant = keyboardHeight + 4.0
    }
    
    //
    // MARK: - Notes methods
    //
    
    func commentForIndexPath(_ indexPath: IndexPath) -> BlipNote? {
        let commentIndex = indexPath.row - 1
        if commentIndex < comments.count {
            return comments[commentIndex]
        }
        DDLogInfo("\(#function): index \(indexPath) out of range of comment count \(comments.count)!!!")
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
        //DDLogInfo("\(#function)")
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
    
    @objc func savePressed(_ sender: TidepoolMobileSimpleUIButton!) {
        //DDLogInfo("cell with tag \(sender.tag) was pressed!")
        if APIConnector.connector().alertIfNetworkIsUnreachable() {
            return
        }
        
        // post new comment!
        if let currentEditCell = currentCommentEditCell {
            if let note = self.note {
                if let commentText = currentEditCell.addCommentTextView.text {
                    if commentText.isEmpty {
                        return
                    }
                    if let commentToEdit = self.commentToEdit {
                        // editing an existing comment
                        let newNote = BlipNote()
                        newNote.messagetext = commentText
                        newNote.timestamp = commentToEdit.timestamp
                        self.newComment = newNote
                        performSegue(withIdentifier: "unwindFromEditComment", sender: self)
                    } else {
                        // adding a new comment
                        let newNote = BlipNote()
                        newNote.user = dataController.currentLoggedInUser!
                        newNote.groupid = note.groupid
                        newNote.messagetext = commentText
                        newNote.parentmessage = note.id
                        newNote.userid = note.user!.userid
                        newNote.timestamp = Date()
                        self.newComment = newNote
                        performSegue(withIdentifier: "unwindFromAddComment", sender: self)
                    }
                }
            }
        }
    }

    //
    // MARK: - Graph support
    //

    fileprivate var graphNeedsUpdate: Bool  = false
    @objc func graphDataChanged(_ note: Notification) {
        graphNeedsUpdate = true
        if viewIsForeground {
            DDLogInfo("EditCommentVC: graphDataChanged, reloading")
            checkUpdateGraph()
        } else {
            DDLogInfo("EditCommentVC: graphDataChanged, in background")
        }
    }
    

    //
    // MARK: - Add Comment UITextField Handling
    //
    
    // UITextViewDelegate methods
    func textViewDidChange(_ textView: UITextView) {
        //DDLogInfo("current content offset: \(tableView.contentOffset.y)")
        if let editCell = self.currentCommentEditCell {
            //DDLogInfo("note changed to \(textView.text)")
            var originalText = ""
            if let comment = self.commentToEdit {
                originalText = comment.messagetext
            }
            let enableSave = originalText != textView.text
            editCell.saveButton.isEnabled = enableSave
            editCell.saveButtonLargeHitArea.isEnabled = enableSave
            
            // adjust table if lines of text have changed...
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
            
            // do any adjust needed if size of field has changed...
            adjustEditAboveKeyboard()
        }
    }
    
    
    var firstTimeAnimate = true
    func adjustEditAboveKeyboard() {
        let editRowIndexPath = indexPathOfRowWithEdit()
        tableView.scrollToRow(at: editRowIndexPath, at: .bottom, animated: firstTimeAnimate)
        // once we're adjusted above the keyboard and just making fine adjustments for the edit view to accomodate number of lines changing, don't animate since it can be a little jumpy...
        firstTimeAnimate = false
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

    @objc func howToUploadPressed(_ sender: UIButton!) {
        if let url = URL(string: TPConstants.kHowToUploadURL) {
            UIApplication.shared.open(url)
        }
    }

    fileprivate func indexPathOfRowWithEdit() -> IndexPath {
        var row = addCommentRow(commentCount: comments.count)
        if let commentToEdit = commentToEdit {
            for i in 0..<comments.count {
                if comments[i].id == commentToEdit.id {
                    row = kPreCommentRows + i
                    break
                }
            }
        }
        return IndexPath(row: row, section: 0)
    }
}

//
// MARK: - Table view delegate
//

extension EditCommentViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt estimatedHeightForRowAtIndexPath: IndexPath) -> CGFloat {
        let row = estimatedHeightForRowAtIndexPath.row
        if row == kGraphRow {
            return TPConstants.kGraphViewHeight
        } else {
            return UITableViewAutomaticDimension
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt heightForRowAtIndexPath: IndexPath) -> CGFloat {
        let row = heightForRowAtIndexPath.row
        if row == kGraphRow {
            return TPConstants.kGraphViewHeight
        } else {
            return UITableViewAutomaticDimension
        }
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
        // one row for note, one row for graph, one row per comment, one for add comment (unless we are just editing a comment)...
        let newCommentCount = commentToEdit != nil ? 0 : 1
        return self.comments.count + kPreCommentRows + newCommentCount
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
            cell.howToUploadButton.addTarget(self, action: #selector(EditCommentViewController.howToUploadPressed(_:)), for: .touchUpInside)
            return cell
        } else {
            if row > addCommentRow(commentCount: comments.count) {
                DDLogError("Index past last row at cellForRowAt \(indexPath)")
                return UITableViewCell()
            }
            
            var comment: BlipNote? = nil
            var addOrEdit = false
            if row < kFirstCommentRow + comments.count {
                comment = comments[row-kFirstCommentRow]
                addOrEdit = comment?.id == self.commentToEdit?.id
            } else {
                // add comment row...
                addOrEdit = true
            }
            
            if addOrEdit {
                let cellId = "editCommentCell"
                let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! NoteListEditCommentCell
                cell.configureCell(note: comment, delegate: self)
                self.currentCommentEditCell = cell
                cell.saveButton.cellIndexPath = indexPath
                cell.saveButtonLargeHitArea.cellIndexPath = indexPath
                cell.saveButton.addTarget(self, action: #selector(EditCommentViewController.savePressed(_:)), for: .touchUpInside)
                cell.saveButtonLargeHitArea.addTarget(self, action: #selector(EditCommentViewController.savePressed(_:)), for: .touchUpInside)
                return cell
            } else {
                if let comment = comment {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "noteListCommentCell", for: indexPath) as! NoteListCommentCell
                    cell.configureCell(comment)
                    return cell
                } else {
                    DDLogError("No comment at cellForRowAt \(indexPath)")
                    return UITableViewCell()
                }
            }
        }
    }
}

