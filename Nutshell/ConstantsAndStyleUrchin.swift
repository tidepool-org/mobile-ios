//
//  ConstantsAndStyle.swift
//  urchin
//
//  Created by Ethan Look on 7/27/15.
//  Copyright (c) 2015 Tidepool. All rights reserved.
//

import Foundation
import UIKit


// ------------ USED EVERYWHERE ------------


/*
    Used TONS of places
    Heavy testing if changed
*/
let labelSpacing: CGFloat = 6

/*
    Used TONS of places
    Heavy testing if changed
*/
let labelInset: CGFloat = 16

// -----

/*
    Separators in Add/EditNoteVCs
    RememberMeLabel textColor in LoginVC
    Sign Up Label textColor in LoginVC
*/
let darkestGreyColor: UIColor = UIColor(red: 152/255, green: 152/255, blue: 151/255, alpha: 1)

/*
    Background color for even numbered noteCells (NotesVC)
*/
let darkestGreyLowAlpha: UIColor = UIColor(red: 152/255, green: 152/255, blue: 151/255, alpha: 0.125)

/*
    Email and password field text color (LoginVC)
*/
let darkGreyColor: UIColor = UIColor(red: 188/255, green: 190/255, blue: 192/255, alpha: 1)

/*
    Border color for email and password fields (LoginVC)
*/
let greyColor: UIColor = UIColor(red: 234/255, green: 234/255, blue: 234/255, alpha: 1)

/*
    Background color for all VCs
    Background color for notesTable (NotesVC), messageBox (NotesVC)
    Background color for odd numbered noteCells (NotesVC)
*/
let lightGreyColor: UIColor = UIColor(red: 247/255, green: 247/255, blue: 248/255, alpha: 1)

/*
    User inputed text color in message box (Add/EditNoteVC)
    Hashtag button text color (HashtagsView)
    LoginVC: versionNumber backgroundColor, titleLabel backgroundColor, emailField textColor, passwordField textColor
*/
let blackishColor: UIColor = UIColor(red: 61/255, green: 61/255, blue: 61/255, alpha: 1)

/*
    Opaque overlays (AddNoteVC, NotesVC)
*/
let blackishLowAlpha: UIColor = UIColor(red: 61/255, green: 61/255, blue: 61/255, alpha: 0.75)

/*
    DropDownMenu background color (AddNoteVC, NotesVC)
    Navigation bar tint color (AppDelegate)
*/
let darkGreenColor: UIColor = UIColor(red: 0/255, green: 54/255, blue: 62/255, alpha: 1)

/*
    Email and password fields background color (LoginVC)
*/
let textFieldBackgroundColor: UIColor = whiteColor

/*
    LoginVC:
        textField highlighted border color
        logInButton
    Add/EditNoteVC:
        changeDateLabel
        postButton
    NoteCell:
        editButton
    NotesVC:
        newNoteButton
*/
let tealColor: UIColor = UIColor(red: 0/255, green: 150/255, blue: 171/255, alpha: 1)

/*
    addNoteLabel on addNoteButton (NotesVC)
*/
let whiteColor: UIColor = UIColor.whiteColor()

/*
    font color for loginButton
*/
let loginButtonTextColor: UIColor = whiteColor

/*
    font color for addNoteButton
*/
let addNoteTextColor: UIColor = whiteColor

/*
    Navigation bar tint (AppDelegate)
*/
let navBarTint: UIColor = whiteColor

/*
    Navigation bar title color (Add/EditNoteVC, NotesVC, AppDelegate)
*/
let navBarTitleColor: UIColor = whiteColor

/*
    postButton text color (Add/EditNoteVC)
*/
let postButtonTextColor: UIColor = whiteColor

/*
    usernameLabel text color (NoteCell)
    date text color (UIDateFormatterExtension)
*/
let noteTextColor: UIColor = UIColor.blackColor()

/*
    Separator color (UserDropDownCell)
*/
let whiteQuarterAlpha: UIColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.2)

// -----

/*
    Add/EditNoteVC:
        changeDateLabel
    LoginVC:
        versionNumber
    NoteCell:
        editButton
    UIDateFormatterExtension:
        attributedStringFromDate (for NoteCell)
*/
let smallRegularFont: UIFont = UIFont(name: "OpenSans", size: 12.5)!
/*
    AddNoteVC:
        Drop down menu nameLabel
        messageBox
        Post button
        Navigation bar title
    EditNoteVC:
        Navigation bar title
        messageBox
        Post button
    HashtagBolder:
        Non-hashtagged words
    HashtagsView:
        Hashtag button titles
    LoadingView:
        Description label
    LoginVC:
        rememberMe label
        log in button
    NotesVC:
        name label
        Navigation bar title
    UserDropDownCell:
        nameLabel
*/
let mediumRegularFont: UIFont = UIFont(name: "OpenSans", size: 17.5)!

/*
    Email and password field font and placeholder font (LoginVC)
*/
let largeRegularFont: UIFont = UIFont(name: "OpenSans", size: 25)!

/*
    done label for small device screen (Add/EditNoteVC)
    Attributed date format, for bold time (NoteCell/UIDateFormatterExtension)
*/
let smallBoldFont: UIFont = UIFont(name: "OpenSans-Bold", size: 12.5)!

/*
    Drop Down Menu selected user (AddNoteVC)
    Bolded hashtags (Hashtag bolder)
    NoteCell -> heightForRowAtIndexPath (NotesVC)
    Drop down menu "All" and "Logout" (NotesVC)
    Add note label on add note button (NotesVC)
*/
let mediumBoldFont: UIFont = UIFont(name: "OpenSans-Bold", size: 17.5)!

/*
    title label (LoginVC)
*/
let largeBoldFont: UIFont = UIFont(name: "OpenSans-Bold", size: 25)!

/*
    Username label (NoteCell)
*/
let mediumSemiboldFont: UIFont = UIFont(name: "OpenSans-Semibold", size: 17.5)!

/*
    title label (LoginVC)
    When drop down menu is exposed, Navigation bar title (NotesVC)
*/
let appTitle: String = "Blip Notes"

/*
    Navigation bar title when all teams are shown (NotesVC)
    Drop down menu title for selecting all teams (NotesVC)
*/
let allTeamsTitle: String = "All"

/*
    Drop down menu title for logging out (NotesVC)
*/
let logoutTitle: String = "Logout"

/*
    Preferred maximum number of groups/teams shown in drop down menu
        If max is lower, drop down menu will still show all groups/teams, but with scroll enabled
*/
let maxGroupsShownInDropdown: Int = 3

/*
    Time for drop down menu to come into view or leave (NotesVC, AddNoteVC)
*/
let dropDownAnimationTime: NSTimeInterval = 0.5

/*
    Height used for the edit button in a NoteCell
        Need to adjust font size appropriately if this is changed
*/
let editButtonHeight: CGFloat = 12.5

/*
    Width used for the edit button in a NoteCell
        Need to adjust font size appropriately if this is changed
*/
let editButtonWidth: CGFloat = 70.0

/*
    Preferred height of the group/team label in any dropDownMenu (NotesVC, AddNoteVC)
*/
let dropDownGroupLabelHeight: CGFloat = 20.0

/*
    Used for dropDownMenu shadow height (NotesVC, AddNoteVC)
*/
let shadowHeight: CGFloat = 2.5

/*
    Size of extra space for hitboxes
*/
let hitBoxAmount: CGFloat = 20.0

// -----

/*
    Image for bar button item, drop down menu (NotesVC, AddNoteVC)
*/
let downArrow: UIImage = UIImage(named: "down")!

/*
    Image for Drop Down Menu cells (NotesVC)
*/
let rightArrow: UIImage = UIImage(named: "right")!

/*
    Image for bar button item, closing a view controller (Add/EditNoteVC)
*/
let closeX: UIImage = UIImage(named: "closex")!

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// ------------ LoginVC ------------

/*
    Main app logo
*/
let notesIcon: UIImage = UIImage(named: "notesicon") as UIImage!

/*
    Tidepool's logo along with corresponding preferred width and height (based on image ratio)
*/
let tidepoolLogo: UIImage = UIImage(named: "tidepoollogo") as UIImage!
let tidepoolLogoWidth: CGFloat = CGFloat(156)
let tidepoolLogoHeight: CGFloat = tidepoolLogoWidth * CGFloat(43.0/394.0)

/*
    Unchecked and checked checkbox images for remember me
*/
let uncheckedImage: UIImage = UIImage(named: "unchecked") as UIImage!
let checkedImage: UIImage = UIImage(named: "checked") as UIImage!

/*
    Sign up image for sign up process
*/
let signUpButtonImage: UIImage = uncheckedImage

/*
    Placeholder text for text fields
*/
let emailFieldPlaceholder: String = "email"
let passFieldPlaceholder: String = "password"

/*
    Remember me checkbox label text
*/
let rememberMeText: String = "Remember me"

/* 
    Sign up label text
*/
let signUpText: String = "Sign up"

/*
    URL for signing up for blip
*/
let signUpURL: NSURL = NSURL(string: "https://blip-ucsf-pilot.tidepool.io/#/signup")!

/*
    Log in button title
*/
let loginButtonText: String = "Log in"

/*
    Username and password text field attributes/sizes
*/
let textFieldHeight: CGFloat = 71
let textFieldHeightSmall: CGFloat = 48
let textFieldBorderWidth: CGFloat = 2
let textFieldInset: CGFloat = 12

/*
    Inset on either side of the login view
*/
let loginInset: CGFloat = 25

/*
    Spacing between the remember me checkbox and remember me label
*/
let rememberMeSpacing: CGFloat = 8

/*
    Spacing between the sign up image and label
*/
let signUpSpacing: CGFloat = 8

/*
    Size of the log in button
*/
let loginButtonWidth: CGFloat = 100
let loginButtonHeight: CGFloat = 50

/*
    Spacing between various login elements
*/
let topToTitle: CGFloat = 32.5
let titleToLogo: CGFloat = 14.5
let logoToEmail: CGFloat = 26.5
let emailToPass: CGFloat = 10.21
let passToLogin: CGFloat = 12.5
let minNotesIconSize: CGFloat = 50

/*
    Time for login UI elements to move up and down
*/
let loginAnimationTime: NSTimeInterval = 0.3

// ------------ NotesVC ------------

/*
    Image of a note used for the add note button
*/
let noteImage: UIImage = UIImage(named: "note")!

/*
    Height of the add note button at the bottom
*/
let addNoteButtonHeight: CGFloat = 105

/*
    Commonly used text for labels
*/
let allNotesTitle: String = "All Notes"
let addNoteText: String = "Add note"
let noteForTitle: String = "Note for..."

/*
    Time period for number of months to be fetched
*/
let fetchPeriodInMonths: Int = -3

// ------------ AddNoteVC and EditNoteVC ------------

/*
    Text color used for messageBox
*/
let messageTextColor: UIColor = UIColor(red: 167/255, green: 167/255, blue: 167/255, alpha: 1)

/*
    Images for camera and location
        Currently being used, but buttons are not added to view
*/
let cameraImage: UIImage = UIImage(named: "camera")!
let locationImage: UIImage = UIImage(named: "location")!

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
let changeDateText: String = "change"
let doneDateText: String = "done"

/*
    AddNoteVC alert text on attempt to close VC
*/
let addAlertTitle: String = "Discard Note?"
let addAlertMessage: String = "If you close this note, your note will be lost."
let addAlertCancel: String = "Cancel"
let addAlertOkay: String = "Okay"

/*
    Post/Save button text
*/
let postButtonText: String = "Post"
let postButtonSave: String = "Save"

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
let trashAlertCancel: String = "Cancel"
let trashAlertOkay: String = "Okay"

/*
    Post button sizing
*/
let postButtonW: CGFloat = 112
let postButtonH: CGFloat = 41

/*
    Animation times
        fade time should be shorter than animation time
*/
let datePickerFadeTime: NSTimeInterval = 0.2
let animationTime: NSTimeInterval = 0.3

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// ------------ API Connector ------------

/*
    Error message alerts shown to user
*/
let invalidLogin: String = "Invalid Login"
let invalidLoginMessage: String = "Wrong username or password."

let unknownError: String = "Unknown Error Occurred"
let unknownErrorMessage: String = "An unknown error occurred. We are working hard to resolve this issue."

/*
    Secret, secret! I got a secret!
    (Change the server)
*/
var baseURL: String = servers["Production"]!
let servers: [String: String] = [
    "Production": "https://api.tidepool.io",
    "Development": "https://devel-api.tidepool.io",
    "Staging": "https://staging-api.tidepool.io"
]

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// ------------ UserDropDownCell -----------

/*
    Sizes of drop down menu cells and separators
        also inset amount
*/
let userCellHeight: CGFloat = 56.0
let userCellInset: CGFloat = labelInset
let userCellThickSeparator: CGFloat = 1
let userCellThinSeparator: CGFloat = 1

// ------------ NoteCell ------------

/*
    Note cell inset amount and title for edit button
*/
let noteCellInset: CGFloat = labelInset

let editButtonTitle: String = "edit"

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// ------------ Hashtags View ------------

/*
    Background and border colors for hashtag buttons
*/
let hashtagColor: UIColor = UIColor.whiteColor()
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

// ------------ Loading View ------------

/*
    Coloring for loading view
        background
        indicator
        text
*/
let loadingViewBackground: UIColor = blackishColor
let loadingIndicatorColor: UIColor = tealColor
let loadingTextColor: UIColor = tealColor

/*
    Roundedness of the loading view corners
*/
let loadingCornerRadius: CGFloat = 10

/*
    Commonly used loading descriptions
*/
let loadingLogIn: String = "Logging in..."
let loadingTeams: String = "Loading teams..."
let loadingNotes: String = "Loading notes..."

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// ------------ Date Formatter ------------

/*
    Commonly used date formats
        Careful with changing iso8601 date formats
        Uniform date format will change NoteCell and Add/EditNoteVCs
        Regular date format for birthdays, diagnosis date, etc.
*/
let uniformDateFormat: String = "EEEE M/d/yy h:mma"
let iso8601dateOne: String = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
let iso8601dateTwo: String = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
let regularDateFormat: String = "yyyy-MM-dd"