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

class NoteListAddCommentCell: BaseUITableViewCell {

    @IBOutlet weak var addCommentIcon: UIImageView!
    @IBOutlet weak var addCommentLabel: NutshellUILabel!
    @IBOutlet weak var addCommentTextView: UITextView!
    @IBOutlet weak var editTopSeparator: NutshellUIView!
    
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
        configureCellForEdit(false)
    }
    
    func configureCellForEdit(_ editMode: Bool, delegate: UITextViewDelegate? = nil) {
        addCommentIcon.isHidden = editMode
        addCommentLabel.isHidden = editMode
        editTopSeparator.isHidden = !editMode
        addCommentTextView.isHidden = !editMode
        addCommentTextView.text = ""
        addCommentTextView.delegate = delegate
        if editMode {
            addCommentTextView.perform(
                #selector(becomeFirstResponder),
                with: nil,
                afterDelay: 0.1
            )
            //addCommentTextView.becomeFirstResponder()
            NSLog("comment view becomeFirstResponder delayed until after it becomes part of view hierarchy!")
        } else if addCommentTextView.isFirstResponder {
            addCommentTextView.resignFirstResponder()
            NSLog("comment view resignFirstResponder")
        }
    }

}
