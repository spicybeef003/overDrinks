//  MIT License

//  Copyright (c) 2017 Haik Aslanyan

//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:

//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.

//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.


import Foundation
import UIKit
import CloudKit
import Reachability

let defaults = UserDefaults.standard
let database = CKContainer(identifier: "iCloud.com.TianProductions.overDrinks").publicCloudDatabase
let reachability = Reachability()!

//Global variables
struct GlobalVariables {
    static let blue = UIColor.rbg(r: 129, g: 144, b: 255)
    static let purple = UIColor.rbg(r: 161, g: 114, b: 255)
}

//Extensions
extension UIViewController {
    func setupNav() {
        let navigationTitleFont = UIFont(name: "AvenirNext-Regular", size: 18)!
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.font: navigationTitleFont, NSAttributedStringKey.foregroundColor: UIColor.white]
    }
    
    func compareImage(image: UIImage, image2: UIImage) -> Bool {
        var image = image
        if image.size != image2.size {
            image = image.resizeImage(targetSize: image2.size)
        }
        print(image.size)
        print(image2.size)
        let imageData = UIImagePNGRepresentation(image)
        let imageData2 = UIImagePNGRepresentation(image2)
        if imageData == imageData2 {
            return true
        }
        return false
    }
    
    func convertImageToCKAsset(image: UIImage) -> CKAsset {
        
        let docDirPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] as NSString
        let filePath = docDirPath.appendingPathComponent(UUID().uuidString + ".jpeg")
        if let data = UIImageJPEGRepresentation(image, 1.0) {
            try? data.write(to: URL(fileURLWithPath: filePath), options: [.atomic])
        }
        
        let asset = CKAsset(fileURL: URL(fileURLWithPath: filePath))
        
        return asset
    }
    
    func saveRecord(record: CKRecord) {
        let saveOperation = CKModifyRecordsOperation()
        saveOperation.recordsToSave = [record]
        saveOperation.savePolicy = .changedKeys
        saveOperation.qualityOfService = .userInitiated
        
        saveOperation.perRecordProgressBlock = {(_, progress) -> Void in
            print("\(Float(progress))")
        }
        
        saveOperation.perRecordCompletionBlock = {(record, error) -> Void in
            print("completed...")
            print(error)
            DispatchQueue.main.async{
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }
        
        database.add(saveOperation)
    }
    
    func alert(message: String?, title: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func convertToInt(_ boolArray: [Bool]) -> [Int64] {
        var intArray: [Int64] = []
        for boolean in boolArray {
            intArray.append(Int64(truncating: NSNumber(value: boolean)))
        }
        return intArray
    }
}


extension UIImage {
    func resizeImage(targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let newSize = widthRatio > heightRatio ?  CGSize(width: size.width * heightRatio, height: size.height * heightRatio) : CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        var newImage: UIImage
        
        if #available(iOS 10.0, *) {
            let renderFormat = UIGraphicsImageRendererFormat.default()
            renderFormat.opaque = false
            let renderer = UIGraphicsImageRenderer(size: newSize, format: renderFormat)
            newImage = renderer.image { (context) in
                self.draw(in: rect)
            }
        }
        else {
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            self.draw(in: rect)
            newImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
        }
        return newImage
    }
    
    func fixOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        var transform: CGAffineTransform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: CGFloat.pi)
            break
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: CGFloat.pi / 2.0)
            break
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: CGFloat.pi / -2.0)
            break
        case .up, .upMirrored:
            break
        }
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform.translatedBy(x: size.width, y: 0)
            transform.scaledBy(x: -1, y: 1)
            break
        case .leftMirrored, .rightMirrored:
            transform.translatedBy(x: size.height, y: 0)
            transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        }
        
        let ctx: CGContext = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: self.cgImage!.bitsPerComponent, bytesPerRow: 0, space: self.cgImage!.colorSpace!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        
        ctx.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            ctx.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            break
        }
        
        return UIImage(cgImage: ctx.makeImage()!)
    }
}

/**
 Return whether two `CLLocationCoordinate2D` structs are equivalent.
 - parameter lhs: The lefthand side of the `==` operator.
 - parameter rhs: The righthand side of the `==` operator.
 - returns: `true` if the `lhs` and `rhs` values are equal, false otherwise.
 */
public func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
}

extension CLLocationCoordinate2D {
    
    /// Returns whether or not the coordinate is valid.
    var isInvalid: Bool {
        return self == kCLLocationCoordinate2DInvalid
    }
    
}

extension Date {
    /// Returns the amount of hours from another date
    func hours(from date: Date) -> Int {
        return Calendar.current.dateComponents([.hour], from: date, to: self).hour ?? 0
    }
    /// Returns the amount of minutes from another date
    func minutes(from date: Date) -> Int {
        return Calendar.current.dateComponents([.minute], from: date, to: self).minute ?? 0
    }
    /// Returns the amount of seconds from another date
    func seconds(from date: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0
    }
    /// Returns the a custom time interval description from another date
    func offset(from date: Date) -> String {
        if hours(from: date)  == 1 { return "\(hours(from: date)) hour"   }
        if hours(from: date)   > 0 { return "\(hours(from: date)) hours"   }
        if minutes(from: date) == 1 { return "\(minutes(from: date)) minute" }
        if minutes(from: date) > 0 { return "\(minutes(from: date)) minutes" }
        if seconds(from: date) <= 1 { return "\(seconds(from: date)) second" }
        if seconds(from: date) > 0 { return "\(seconds(from: date)) seconds" }
        return ""
    }
}

public extension CKAsset {
    public func image() -> UIImage? {
        if let data = try? Data(contentsOf: self.fileURL) {
            return UIImage(data: data)
        }
        return nil
    }
    
    public func url() -> URL? {
        var videoURL = self.fileURL
        
        let videoData = try? Data(contentsOf: videoURL)
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let destinationPath = URL(fileURLWithPath: documentsPath).appendingPathComponent(UUID().uuidString + ".mp4")
        
        FileManager.default.createFile(atPath: destinationPath.path, contents:videoData, attributes: nil)
        
        return destinationPath
    }
    
    
}

extension UIColor{
    class func rbg(r: CGFloat, g: CGFloat, b: CGFloat) -> UIColor {
        let color = UIColor.init(red: r/255, green: g/255, blue: b/255, alpha: 1)
        return color
    }
}

class RoundedImageView: UIImageView {
    override func layoutSubviews() {
        super.layoutSubviews()
        let radius: CGFloat = self.bounds.size.width / 2.0
        self.layer.cornerRadius = radius
        self.clipsToBounds = true
    }
}

class RoundedButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        let radius: CGFloat = self.bounds.size.height / 2.0
        self.layer.cornerRadius = radius
        self.clipsToBounds = true
    }
}


//Enums
enum ViewControllerType {
    case welcome
    case conversations
}

enum PhotoSource {
    case library
    case camera
}

enum ShowExtraView {
    case contacts
    case profile
    case preview
    case map
}

enum MessageType {
    case photo
    case text
    case location
}

enum MessageOwner {
    case sender
    case receiver
}

/*
 let start = CFAbsoluteTimeGetCurrent()
 let end = CFAbsoluteTimeGetCurrent() - start
 print("Took \(end) seconds")
 */
