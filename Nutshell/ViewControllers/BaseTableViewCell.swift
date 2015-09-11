//
//  BaseTableViewCell.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/8/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class BaseTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
        self.backgroundColor = NutshellStyles.tableLightBkgndColor
        
        self.textLabel?.font = listItemFont
    }

}
