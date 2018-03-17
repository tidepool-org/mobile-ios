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

// TODO: move relevant items to TPConstants.swift

// ------------ USED EVERYWHERE ------------


let labelSpacing: CGFloat = 6
let labelInset: CGFloat = 16

// -----

/*
 Separators in Add/EditNoteVCs
 RememberMeLabel textColor in LoginVC
 Sign Up Label textColor in LoginVC
 */
let darkestGreyColor: UIColor = UIColor(red: 152/255, green: 152/255, blue: 151/255, alpha: 1)

/*
 Background color for all VCs
 Background color for notesTable (NotesVC), messageBox (NotesVC)
 Background color for odd numbered noteCells (NotesVC)
 */
let lightGreyColor: UIColor = UIColor(red: 247/255, green: 247/255, blue: 248/255, alpha: 1)

/*
 User input text color in message box (Add/EditNoteVC)
 Hashtag button text color (HashtagsView)
 LoginVC: versionNumber backgroundColor, titleLabel backgroundColor, emailField textColor, passwordField textColor
 */
let blackishColor: UIColor = UIColor(red: 61/255, green: 61/255, blue: 61/255, alpha: 1)

/*
 usernameLabel text color (NoteCell)
 date text color (UIDateFormatterExtension)
 */
let noteTextColor: UIColor = UIColor.black

/*
 Add/EditNoteVC:
 changeDateLabel
 */
let smallRegularFont: UIFont = UIFont(name: "OpenSans", size: 12.5)!
/*
 AddNoteVC:
 EditNoteVC:
 messageBox
 HashtagBolder:
 Non-hashtagged words
 HashtagsView:
 Hashtag button titles
 */
let mediumRegularFont: UIFont = UIFont(name: "OpenSans", size: 17.5)!

/*
 done label for small device screen (Add/EditNoteVC)
 Attributed date format, for bold time (NoteCell/UIDateFormatterExtension)
 */
let smallBoldFont: UIFont = UIFont(name: "OpenSans-Bold", size: 12.5)!

// ------------ AddNoteVC and EditNoteVC ------------

/*
 Text color used for messageBox
 */
let messageTextColor: UIColor = UIColor(red: 167/255, green: 167/255, blue: 167/255, alpha: 1)

/*
 Number of rows to display in a vertical hashtags view
 Note: If there are more than this many rows of hashtags, they will still be displayed, but the user will have to scroll to them
 */
let numberHashtagRows: CGFloat = 3

/*
 Size for hashtags view, dependant on other values:
 Expanded -> x rows of hashtags
 Condensed -> Single, linear row
 */
let expandedHashtagsViewH: CGFloat = 2 * labelInset + numberHashtagRows * hashtagHeight + (numberHashtagRows - 1) * (verticalHashtagSpacing)
let condensedHashtagsViewH: CGFloat = 2 * labelInset + hashtagHeight

/*
 Default placeholder message
 */
let defaultMessage: String = "What's going on?"

/*
 Change date button text
 */
let changeDateText: String = "edit"
let doneDateText: String = "done"

/*
 AddNoteVC alert text on attempt to close VC
 */
let addAlertTitle: String = "Discard Note?"
let addAlertMessage: String = "If you close this note, your note will be lost."
let addAlertCancel: String = "Cancel"
let addAlertOkay: String = "OK"

/*
 EditNoteVC alert text on attempt to close VC
 */
let editAlertTitle: String = "Save Changes?"
let editAlertMessage: String = "You have made changes to this note. Would you like to save these changes?"
let editAlertDiscard: String = "Discard"
let editAlertSave: String = "Save"

/*
 EditNoteVC alert text on attempt to trash note
 */
let trashAlertTitle: String = "Delete Note?"
let trashAlertMessage: String = "Once you delete this note, it cannot be recovered."
let trashCommentAlertTitle: String = "Delete Comment?"
let trashCommentAlertMessage: String = "Once you delete this comment, it cannot be recovered."
let trashAlertCancel: String = "Cancel"
let trashAlertOkay: String = "OK"

/*
 SyncHealthDataViewController alert text on attempt to stop upload
 */
let stopSyncingTitle: String = "Stop Syncing?"
let stopSyncingCancel: String = "Cancel"
let stopSyncingOkay: String = "OK"

/*
 Animation times
 fade time should be shorter than animation time
 */
let datePickerFadeTime: TimeInterval = 0.2
let animationTime: TimeInterval = 0.3

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// ------------ API Connector ------------

let unknownError: String = "Unknown Error Occurred"
let unknownErrorMessage: String = "An unknown error occurred. We are working hard to resolve this issue."


// ------------ Hashtags View ------------

/*
 Background and border colors for hashtag buttons
 */
let hashtagColor: UIColor = UIColor.white
let hashtagHighlightedColor: UIColor = UIColor(red: 188/255, green: 227/255, blue: 232/255, alpha: 1)
let hashtagBorderColor: UIColor = UIColor(red: 167/255, green: 167/255, blue: 167/255, alpha: 1)

/*
 Border thickness for hashtag buttons
 */
let hashtagBorderWidth: CGFloat = 1

/*
 Height of hashtags --> size to fit used, so be careful changing this value
 */
let hashtagHeight: CGFloat = 36

/*
 The spacing between rows of hashtags when the hashtags view is expanded and scrolls vertically
 */
let verticalHashtagSpacing: CGFloat = 1.5 * labelSpacing

/*
 The horizontal spacing between hashtags when the hashtags view is either vertical or horizontal
 */
let horizontalHashtagSpacing: CGFloat = 2 * labelSpacing

