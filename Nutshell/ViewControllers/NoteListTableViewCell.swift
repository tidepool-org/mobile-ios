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

class NoteListTableViewCell: BaseUITableViewCell {

    var note: BlipNote?

    @IBOutlet weak var noteLabel: UILabel!
    @IBOutlet weak var dateLabel: NutshellUILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        NSLog("setSelected \(selected) for \(String(describing: note?.messagetext))!")
        
        super.setSelected(selected, animated: animated)
        self.updateNoteFontStyling()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        NSLog("setHighlighted \(highlighted) for \(String(describing: note?.messagetext))!")
        super.setHighlighted(highlighted, animated:animated)
        
        // Configure the view for the highlighted state
        updateNoteFontStyling()
        dateLabel.isHighlighted = highlighted
    }
    
    func configureCell(_ note: BlipNote) {
        self.note = note
        self.updateNoteFontStyling()
        dateLabel.text = NutUtils.standardUIDateString(note.timestamp)
        noteLabel.isHighlighted = false
        dateLabel.isHighlighted = false
    }
    
    private func updateNoteFontStyling() {
        if let note = note {
            let hashtagBolder = HashtagBolder()
            let attributedText = hashtagBolder.boldHashtags(note.messagetext as NSString, highlighted: self.isHighlighted)
            noteLabel.attributedText = attributedText
        }
    }
}
