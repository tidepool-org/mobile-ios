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

import Foundation
import UIKit
import CoreData
import CocoaLumberjack

class HashtagsView: UIView {
    
    // Vertical hashtag arrangement, and linear hashtag arrangement
    var verticalHashtagButtons: [[UIButton]] = []
    var hashtagButtons: [UIButton] = []
    
    // Keep track of the total widths
    var totalLinearHashtagsWidth: CGFloat = 0
    var totalVerticalHashtagsHeight: CGFloat = 0
    
    // Called to set up the view
    func configureHashtagsView() {
        self.configureHashtagButtons()
        self.isUserInteractionEnabled = true
    }
    
    // Create and configure the hashtag buttons
    func configureHashtagButtons() {
        
        /* Keep track of:
                - which number hashtag
                - which row
                - which column
        */
        var index = 0
        var row = 0
        var col = 0
        
        // Keep track of the current row that is being worked on
        var buttonRow: [UIButton] = []
        let hashCount = HashTagManager.sharedInstance.sortedHashTags.count

        // Infinite loop!!!
        while (true) {
            if (index >= hashCount) {
                // Break if there are no more hashtags
                break
            }
            
            // Configure the individual hashtag button
            let hashtagButton = configureHashtagButton(index)
            
            var buttonX: CGFloat
            
            // If it's the first one in a row, it's a label inset in
            // All other's in the row are based upon the previous hashtag in the row
            if (col == 0) {
                buttonX = labelInset
            } else {
                buttonX = buttonRow[col - 1].frame.maxX + horizontalHashtagSpacing
            }
            
            // If the hashtag spills over to the next page, start a new row
            if ((buttonX + hashtagButton.frame.width) > (UIScreen.main.bounds.width - labelInset)) {

                totalVerticalHashtagsHeight += hashtagHeight + verticalHashtagSpacing
                
                // Append the current row and reset/increment values
                verticalHashtagButtons.append(buttonRow)
                buttonRow = []
                row += 1
                col = 0
                continue
            } else {
                // The button didn't spill over! Add to the totalLinearHashtagsWidth and append the button to the row
                totalLinearHashtagsWidth += hashtagButton.frame.width + horizontalHashtagSpacing
                buttonRow.append(hashtagButton)
                hashtagButtons.append(hashtagButton)
            }
            
            // Set the x origin (used for determining the position of the next hashtagButton)
            buttonRow[col].frame.origin.x = buttonX
            
            // Increment the index and column
            index += 1
            col += 1
        }
        
        // Take off the extra bit from the end of the totalLinearHashtagsWidth
        totalLinearHashtagsWidth -= horizontalHashtagSpacing
        
        // If the last button row has more hashtags, increase the totalVerticalHashtagsHeight
        if (buttonRow.count > 0) {
            totalVerticalHashtagsHeight += hashtagHeight
            
            // Append the most recent buttonRow to the verticalHashtagButtons
            verticalHashtagButtons.append(buttonRow)
        } else {
            // Else take the extra bit off (spacing between rows)
            totalVerticalHashtagsHeight -= verticalHashtagSpacing
        }
        
        // Arrange in pages arrangement
        verticalHashtagArrangement()
    }
    
    // For when the HashtagsView is expanded
    func verticalHashtagArrangement() {
        
        var row = 0
        for bRow in verticalHashtagButtons {
            
            // y origin is based upon which row the hashtag is in
            let buttonY = labelInset + CGFloat(row) * (hashtagHeight + verticalHashtagSpacing)
            
            // Find the total width of the row
            var totalButtonWidth: CGFloat = CGFloat(0)
            var i = 0
            for button in bRow {
                totalButtonWidth += button.frame.width + horizontalHashtagSpacing
                i += 1
            }
            
            // Determine the width between the outer margins
            let totalWidth = totalButtonWidth - 2 * labelSpacing
            // Take the halfWidth
            let halfWidth = totalWidth / 2

            // x origin of the left most button in the row
            // (page - hashtagsPage) for paging
            var buttonX = UIScreen.main.bounds.width / 2 - halfWidth
            
            var col = 0
            for button in bRow {
             
                button.frame.origin = CGPoint(x: buttonX, y: buttonY)
                self.addSubview(button)
                
                // increase the buttonX for the next button
                buttonX = button.frame.maxX + horizontalHashtagSpacing
                
                col += 1
            }
            row += 1
        }
    }
    
    // For when the HashtagsView is condensed
    func linearHashtagArrangement() {
        var index = 0
        for button in hashtagButtons {
            button.frame.origin.y = labelInset
            
            // If it is the first button, it's x origin is just the labelInset
            // Else, it's x origin is based upon the previous button
            if (index == 0) {
                button.frame.origin.x = labelInset
            } else {
                button.frame.origin.x = hashtagButtons[index - 1].frame.maxX + horizontalHashtagSpacing
            }
            index += 1
        }
    }
    
    // Create the hashtag button with the correct attributes based upon the index
    // Returns the button that was created
    func configureHashtagButton(_ index: Int) -> UIButton {
        let hashtagButton = UIButton(frame: CGRect.zero)
        let hashtagText =  HashTagManager.sharedInstance.sortedHashTags[index].tag
        hashtagButton.setAttributedTitle(NSAttributedString(string: hashtagText,
            attributes:[NSAttributedString.Key.foregroundColor: blackishColor, NSAttributedString.Key.font: mediumRegularFont]), for: UIControl.State())
        hashtagButton.frame.size.height = hashtagHeight
        hashtagButton.sizeToFit()
        hashtagButton.frame.size.width = hashtagButton.frame.width + 4 * labelSpacing
        hashtagButton.backgroundColor = hashtagColor
        hashtagButton.layer.cornerRadius = hashtagButton.frame.height / 2
        hashtagButton.layer.borderWidth = hashtagBorderWidth
        hashtagButton.layer.borderColor = hashtagBorderColor.cgColor
        hashtagButton.addTarget(self, action: #selector(HashtagsView.hashtagHighlight(_:)), for: .touchDown)
        hashtagButton.addTarget(self, action: #selector(HashtagsView.hashtagHighlight(_:)), for: .touchDragInside)
        hashtagButton.addTarget(self, action: #selector(HashtagsView.hashtagNormal(_:)), for: .touchDragOutside)
        hashtagButton.addTarget(self, action: #selector(HashtagsView.hashtagPress(_:)), for: .touchUpInside)
        hashtagButton.addTarget(self, action: #selector(HashtagsView.hashtagNormal(_:)), for: .touchUpInside)
        hashtagButton.addTarget(self, action: #selector(HashtagsView.hashtagNormal(_:)), for: .touchUpOutside)
        
        return hashtagButton
    }
    
    // Hashtag was pressed, send notification to Add/EditNoteVC to add hashtag text to textbox
    @objc func hashtagPress(_ sender: UIButton) {
        let notification = Notification(name: Notification.Name(rawValue: "hashtagPressed"), object: nil, userInfo: ["hashtag":sender.titleLabel!.text!])
        NotificationCenter.default.post(notification)
    }
    
    // Animate the hashtag to the normal color
    @objc func hashtagNormal(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, animations: { () -> Void in
            sender.backgroundColor = hashtagColor
        })
    }
    
    // Animate the hashtag to the highlighted color
    @objc func hashtagHighlight(_ sender: UIButton) {
        UIView.animate(withDuration: 0.15, animations: { () -> Void in
            sender.backgroundColor = hashtagHighlightedColor
        })
    }
}
