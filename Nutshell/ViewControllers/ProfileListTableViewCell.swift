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

class ProfileListTableViewCell: UITableViewCell {

    var note: BlipNote?

    @IBOutlet weak var nameLabel: NutshellUILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        NSLog("setSelected \(selected) for \(note?.messagetext)!")

        super.setSelected(selected, animated: animated)
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        NSLog("setHighlighted \(highlighted) for \(note?.messagetext)!")
        super.setHighlighted(highlighted, animated:animated)
        
        // Configure the view for the highlighted state
        nameLabel.isHighlighted = highlighted
    }
    
    func configureCell(_ user: BlipUser) {
        nameLabel.text = user.fullName
        nameLabel.isHighlighted = false
    }
}
