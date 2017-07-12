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

import Foundation


class HashTagManager {
    
    /// Supports a singleton controller for the application.
    static let sharedInstance = HashTagManager()
    
    // MARK: - Constants
    // For now, the defaults are predefined here
    // Eventually, fetch from the Tidepool platform
    //let defaultTags: [(String, Int)] = [("#exercise", 1), ("#meal", 1), ("#sitechange", 1), ("#sensorchange", 1), ("#juicebox", 1), ("#devicesetting", 1)]
    let defaultTags = ["#exercise", "#meal", "#sitechange", "#sensorchange", "#juicebox", "#devicesetting"]

    /// hashtags sorted by usage count...
    var sortedHashTags: [(tag: String, value: Int)] = []
    
    // unsorted hashtags, dictionary for fast lookup by tag
    private var hashTagDict = [String: Int]()
    
    init() {
       resetTags()
    }

    /// Reset to default tags...
    func resetTags() {
        hashTagDict = [String: Int]()
        for tag in defaultTags {
            sortedHashTags.append((tag, 1))
        }
    }

    /// Load tags from current set of notes, adding in defaults as well
    func reloadTagsFromNotes(_ notes: [BlipNote]) {
        NSLog("\(#function) start")
        hashTagDict = [String: Int]()
        for note in notes {
            updateTagsForText(note.messagetext)
        }
        // also add default tags into the dictionary of (tag: count) entries.
        addDefaultTags()
        updateSortedHashTags()
        NSLog("\(#function) end")
    }
    
    private func updateSortedHashTags() {
        sortedHashTags = []
        hashTagDict.forEach() {
            (tag: String, value: Int) -> Void in
            sortedHashTags.append((tag, value))
        }
        sortedHashTags.sort(by: {$0.value > $1.value})
    }
    
    private func addDefaultTags() {
        for tag in defaultTags {
            var count = 1
            if let curCount = hashTagDict[tag] {
                count = curCount + 1
            }
            hashTagDict[tag] = count
        }
    }
    
    private func updateTagsForText(_ text: String, delete: Bool = false) {
        // Identify hashtags
        let separators = CharacterSet(charactersIn: " \n\t")
        let words = text.components(separatedBy: separators)
        
        // Note: could use TwitterText.hashtags function, though we'd only get one count per hashtag even if it occurred twice...
        for word in words {
            if (word.hasPrefix("#")) {
                // hashtag found!
                // algorithm to determine length of hashtag without symbols or punctuation (common practice)
                var charsInHashtag: Int = 0
                let symbols = CharacterSet.symbols
                let punctuation = CharacterSet.punctuationCharacters
                for char in word.unicodeScalars {
                    if (char == "#" && charsInHashtag == 0) {
                        charsInHashtag += 1
                        continue
                    }
                    if (!punctuation.contains(UnicodeScalar(char.value)!) && !symbols.contains(UnicodeScalar(char.value)!)) {
                        charsInHashtag += 1
                    } else {
                        break
                    }
                }
                
                let newword = (word as NSString).substring(to: charsInHashtag)
                if delete {
                    if let curCount = hashTagDict[newword] {
                        let count = curCount - 1
                        if count > 0 {
                            hashTagDict[newword] = count
                        } else {
                            hashTagDict[newword] = nil
                        }
                    }
                } else {
                    // increment count for this hashtag, creating a new entry if there wasn't one before
                    var count = 1
                    if let curCount = hashTagDict[newword] {
                        count = curCount + 1
                    }
                    hashTagDict[newword] = count
                }
            }
        }
    }
    
    func updateTagsForNote(oldNote: BlipNote?, newNote: BlipNote?) {
        if let note = newNote {
            updateTagsForText(note.messagetext)
        }
        if let note = oldNote {
            updateTagsForText(note.messagetext, delete: true)
        }
        updateSortedHashTags()
    }
}
