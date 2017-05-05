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

class NoteListEditCommentCell: BaseUITableViewCell {

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
    }
    
    func configureCell(startText: String, delegate: UITextViewDelegate? = nil) {
        addCommentTextView.text = startText
        addCommentTextView.delegate = delegate
        addCommentTextView.keyboardAppearance = UIKeyboardAppearance.dark
        NSLog("comment view becomeFirstResponder delayed until after it becomes part of view hierarchy!")
    }

}
