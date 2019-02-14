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
import CocoaLumberjack

class NoteListEditCommentCell: BaseUITableViewCell {

    @IBOutlet weak var addCommentTextView: UITextView!
    @IBOutlet weak var editTopSeparator: TidepoolMobileUIView!
    @IBOutlet weak var textWidthMeasureView: UIView!
    
    @IBOutlet weak var saveButton: TidepoolMobileSimpleUIButton!
    @IBOutlet weak var saveButtonLargeHitArea: TPUIButton!
    
    // set if editing existing comment...
    var note: BlipNote?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
         //super.setHighlighted(highlighted, animated:animated)
    }
    
    override func prepareForReuse() {
        maxTextHeight = nil
    }
    
    var maxTextHeight: CGFloat?
    func heightForTextGrew() -> Bool {
        let previousMaxHeight = maxTextHeight
        let fixedWidth = textWidthMeasureView.frame.size.width
        let sizeThatFitsHeight = addCommentTextView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude)).height
        if maxTextHeight == nil {
            maxTextHeight = sizeThatFitsHeight
            return true
        }
        if sizeThatFitsHeight > maxTextHeight! {
            maxTextHeight = sizeThatFitsHeight
        }
        //DDLogVerbose("addCommentTextView.bounds.size: \(addCommentTextView.bounds.size)")
        //DDLogVerbose("addCommentTextView sizeThatFitsHeight: \(sizeThatFitsHeight)")
        // first time nil counts as no change since initial layout should be correct...
        if let previous = previousMaxHeight, let new = maxTextHeight {
            if previous < new {
                DDLogVerbose("comment edit cell height grew from \(previous) to \(new)!")
                return true
            }
        }
        return false
    }
    
    func configureCell(note: BlipNote?, delegate: UITextViewDelegate? = nil) {
        addCommentTextView.text = note != nil ? note!.messagetext : ""
        addCommentTextView.delegate = delegate
        addCommentTextView.keyboardAppearance = UIKeyboardAppearance.dark
        saveButton.isEnabled = false
        saveButton.setTitle(note != nil ? "Save" : "Post", for: .normal)
        saveButtonLargeHitArea.isEnabled = false
    }

}
