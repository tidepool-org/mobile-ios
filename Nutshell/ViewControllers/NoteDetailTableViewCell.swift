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

class NoteDetailTableViewCell: BaseUITableViewCell {

    var note: BlipNote?

    @IBOutlet weak var noteLabel: NutshellUILabel!
    @IBOutlet weak var dateLabel: NutshellUILabel!
    @IBOutlet weak var userLabel: NutshellUILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated:animated)
    }
    
    func configureCell(_ note: BlipNote) {
//        let hashtagBolder = HashtagBolder()
//        let attributedText = hashtagBolder.boldHashtags(note.messagetext as NSString)
//        noteLabel.attributedText = attributedText

        noteLabel.text = note.messagetext
        
        dateLabel.text = NutUtils.standardUIDateString(note.timestamp)
        
        self.userLabel.text = note.user?.fullName ?? ""
        self.note = note
    }
}
