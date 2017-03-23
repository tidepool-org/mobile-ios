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

    @IBOutlet weak var noteLabel: NutshellUILabel!
    @IBOutlet weak var dateLabel: NutshellUILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        let highLitOrSelected = self.isHighlighted ? true : selected
        NSLog("setSelected \(selected) for \(note?.messagetext)!")
        NSLog("highLitOrSelected: \(highLitOrSelected)")

        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
        noteLabel.isHighlighted = highLitOrSelected
        dateLabel.isHighlighted = highLitOrSelected
        super.setCellHighlight(highLitOrSelected)
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let highLitOrSelected = self.isSelected ? true : highlighted
        NSLog("setHighlighted \(highlighted) for \(note?.messagetext)!")
        NSLog("highLitOrSelected: \(highLitOrSelected)")

        super.setHighlighted(highlighted, animated:animated)
        
        // Configure the view for the highlighted state
        noteLabel.isHighlighted = highLitOrSelected
        dateLabel.isHighlighted = highLitOrSelected
        super.setCellHighlight(highLitOrSelected)
    }
    
    func configureCell(_ note: BlipNote) {
        noteLabel.text = note.messagetext
        dateLabel.text = NutUtils.standardUIDateString(note.timestamp)
        self.note = note
        noteLabel.isHighlighted = false
        dateLabel.isHighlighted = false
        super.setCellHighlight(false)
    }
}
