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
import CoreData
import Photos

class NutUtils {

    class func onIPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    class func dispatchBoolToVoidAfterSecs(_ secs: Float, result: Bool, boolToVoid: @escaping (Bool) -> (Void)) {
        let time = DispatchTime.now() + Double(Int64(secs * Float(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: time){
            boolToVoid(result)
        }
    }
    
    class func delay(_ delay:Double, closure:@escaping ()->()) {
        DispatchQueue.main.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
    }
    
    class func compressImage(_ image: UIImage) -> UIImage {
        var actualHeight : CGFloat = image.size.height
        var actualWidth : CGFloat = image.size.width
        let maxHeight : CGFloat = 600.0
        let maxWidth : CGFloat = 800.0
        var imgRatio : CGFloat = actualWidth/actualHeight
        let maxRatio : CGFloat = maxWidth/maxHeight
        let compressionQuality : CGFloat = 0.5 //50 percent compression
        
        if ((actualHeight > maxHeight) || (actualWidth > maxWidth)){
            if(imgRatio < maxRatio){
                //adjust height according to maxWidth
                imgRatio = maxWidth / actualWidth;
                actualHeight = imgRatio * actualHeight;
                actualWidth = maxWidth;
            }
            else{
                actualHeight = maxHeight;
                actualWidth = maxWidth;
            }
        }
        
        let rect = CGRect(x: 0.0, y: 0.0, width: actualWidth, height: actualHeight)
        UIGraphicsBeginImageContext(rect.size)
        image.draw(in: rect)
        let img : UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        let imageData = UIImageJPEGRepresentation(img, compressionQuality)
        UIGraphicsEndImageContext()
        NSLog("Compressed length: \(imageData!.count)")
        return UIImage(data: imageData!)!
    }
    
    class func photosDirectoryPath() -> String? {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        var photoDirPath: String? = path + "/photos/" + NutDataController.sharedInstance.currentUserId! + "/"
        
        let fm = FileManager.default
        var dirExists = false
        do {
            _ = try fm.contentsOfDirectory(atPath: photoDirPath!)
            //NSLog("Photos dir: \(dirContents)")
            dirExists = true
        } catch let error as NSError {
            NSLog("Need to create dir at \(photoDirPath), error: \(error)")
        }
        
        if !dirExists {
            do {
                try fm.createDirectory(atPath: photoDirPath!, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                NSLog("Failed to create dir at \(photoDirPath), error: \(error)")
                photoDirPath = nil
            }
        }
        return photoDirPath
    }
    
    class func urlForNewPhoto() -> String {
        let baseFilename = "file_" + UUID().uuidString + ".jpg"
        return baseFilename
    }

    class func filePathForPhoto(_ photoUrl: String) -> String? {
        if let dirPath = NutUtils.photosDirectoryPath() {
            return dirPath + photoUrl
        }
        return nil
    }
    
    class func deleteLocalPhoto(_ url: String) {
        if url.hasPrefix("file_") {
            if let filePath = filePathForPhoto(url) {
                let fm = FileManager.default
                do {
                    try fm.removeItem(atPath: filePath)
                    NSLog("Deleted photo: \(url)")
                } catch let error as NSError {
                    NSLog("Failed to delete photo at \(filePath), error: \(error)")
                }
            }
        }
    }

    class func photoInfo(_ url: String) -> String {
        var result = "url: " + url
        if url.hasPrefix("file_") {
            if let filePath = filePathForPhoto(url) {
                let fm = FileManager.default
                do {
                    let fileAttributes = try fm.attributesOfItem(atPath: filePath)
                    result += "size: " + String(describing: fileAttributes[FileAttributeKey.size])
                    result += "created: " + String(describing: fileAttributes[FileAttributeKey.creationDate])
                } catch let error as NSError {
                    NSLog("Failed to get attributes for file \(filePath), error: \(error)")
                }
            }
        }
        return result
    }
    
    class func loadImage(_ url: String, imageView: UIImageView) {
        if let image = UIImage(named: url) {
            imageView.image = image
            imageView.isHidden = false
        } else if url.hasPrefix("file_") {
            if let filePath = filePathForPhoto(url) {
                let image = UIImage(contentsOfFile: filePath)
                if let image = image {
                    imageView.isHidden = false
                    imageView.image = image
                } else {
                    NSLog("Failed to load photo from local file: \(url)!")
                }
            }
        } else {
            if let nsurl = URL(string:url) {
                let fetchResult = PHAsset.fetchAssets(withALAssetURLs: [nsurl], options: nil)
                if let asset = fetchResult.firstObject {
                    // TODO: move this to file system! Would need current event to update it as well!
                    var targetSize = imageView.frame.size
                    // bump up resolution...
                    targetSize.height *= 2.0
                    targetSize.width *= 2.0
                    let options = PHImageRequestOptions()
                    PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: PHImageContentMode.aspectFit, options: options) {
                        (result, info) in
                        if let result = result {
                            imageView.isHidden = false
                            imageView.image = result
                        }
                    }
                }
            }
        }
    }

    class func dateFromJSON(_ json: String?) -> Date? {
        if let json = json {
            var result = jsonDateFormatter.date(from: json)
            if result == nil {
                result = jsonAltDateFormatter.date(from: json)
            }
            return result
        }
        return nil
    }
    
    class func dateToJSON(_ date: Date) -> String {
        return jsonDateFormatter.string(from: date)
    }

    class func decimalFromJSON(_ json: String?) -> NSDecimalNumber? {
        if let json = json {
            return NSDecimalNumber(string: json)
        }
        return nil
    }

    /** Date formatter for JSON date strings */
    class var jsonDateFormatter : DateFormatter {
        struct Static {
            static let instance: DateFormatter = {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                dateFormatter.timeZone = TimeZone(identifier: "GMT")
                return dateFormatter
                }()
        }
        return Static.instance
    }
    
    class var jsonAltDateFormatter : DateFormatter {
        struct Static {
            static let instance: DateFormatter = {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                dateFormatter.timeZone = TimeZone(identifier: "GMT")
                return dateFormatter
            }()
        }
        return Static.instance
    }

    
    /** Date formatter for date strings in the UI */
    fileprivate class var dateFormatter : DateFormatter {
        struct Static {
            static let instance: DateFormatter = {
                let df = DateFormatter()
                df.dateFormat = Styles.uniformDateFormat
                return df
            }()
        }
        return Static.instance
    }

    // NOTE: these date routines are not localized, and do not take into account user preferences for date display.

    /// Call setFormatterTimezone to set time zone before calling standardUIDayString or standardUIDateString
    class func setFormatterTimezone(_ timezoneOffsetSecs: Int) {
        let df = NutUtils.dateFormatter
        df.timeZone = TimeZone(secondsFromGMT:timezoneOffsetSecs)
    }
    
    /// Returns delta time different due to a different daylight savings time setting for a date different from the current time, assuming the location-based time zone is the same as the current default.
    class func dayLightSavingsAdjust(_ dateInPast: Date) -> Int {
        let thisTimeZone = TimeZone.autoupdatingCurrent
        let dstOffsetForThisDate = thisTimeZone.daylightSavingTimeOffset(for: Date())
        let dstOffsetForPickerDate = thisTimeZone.daylightSavingTimeOffset(for: dateInPast)
        let dstAdjust = dstOffsetForPickerDate - dstOffsetForThisDate
        return Int(dstAdjust)
    }
    
    /// Returns strings like "Mar 17, 2016", "Today", "Yesterday"
    /// Note: call setFormatterTimezone before this!
    class func standardUIDayString(_ date: Date) -> String {
        let df = NutUtils.dateFormatter
        df.dateFormat = "MMM d, yyyy"
        var dayString = df.string(from: date)
        // If this year, remove year.
        df.dateFormat = ", yyyy"
        let thisYearString = df.string(from: Date())
        dayString = dayString.replacingOccurrences(of: thisYearString, with: "")
        // Replace with today, yesterday if appropriate: only check if it's in the last 48 hours
        // TODO: look at using NSCalendar.startOfDayForDate and then time intervals to determine today, yesterday, Saturday, etc., back a week.
        if (date.timeIntervalSinceNow > -48 * 60 * 60) {
            if Calendar.current.isDateInToday(date) {
                dayString = "Today"
            } else if Calendar.current.isDateInYesterday(date) {
                dayString = "Yesterday"
            }
        }
        return dayString
    }
    
    /// Returns strings like "Yesterday at 9:17 am"
    /// Note: call setFormatterTimezone before this!
    class func standardUIDateString(_ date: Date) -> String {
        let df = NutUtils.dateFormatter
        let dayString = NutUtils.standardUIDayString(date)
        // Figure the hour/minute part...
        df.dateFormat = "h:mm a"
        var hourString = df.string(from: date)
        // Replace uppercase PM and AM with lowercase versions
        hourString = hourString.replacingOccurrences(of: "PM", with: "pm", options: NSString.CompareOptions.literal, range: nil)
        hourString = hourString.replacingOccurrences(of: "AM", with: "am", options: NSString.CompareOptions.literal, range: nil)
        return dayString + " at " + hourString
    }

}
