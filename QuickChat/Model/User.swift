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
import Firebase

class User: NSObject {
    
    //MARK: Properties
    let name: String
    let email: String
    let id: String
    var FCMToken: String
    var profilePic: UIImage
    
    //MARK: Methods
    class func registerUser(withName: String, email: String, password: String, profilePic: UIImage, completion: @escaping (Bool) -> Swift.Void) {
        Auth.auth().createUser(withEmail: email, password: password, completion: { (user, error) in
            if error == nil {
                user?.user.sendEmailVerification(completion: nil)
                let storageRef = Storage.storage().reference().child("usersProfilePics").child(user!.user.uid)
                let imageData = UIImageJPEGRepresentation(profilePic, 0.1)
                storageRef.putData(imageData!, metadata: nil, completion: { (metadata, err) in
                    if err == nil {
                        storageRef.downloadURL(completion: { url, error in
                            if error == nil {
                                if let path = url?.absoluteString {
                                    let values = ["name": withName, "email": email, "profilePicLink": path, "deviceToken": AppDelegate.DEVICEID]
                                    Database.database().reference().child("users").child((user?.user.uid)!).child("credentials").updateChildValues(values, withCompletionBlock: { (errr, _) in
                                        if errr == nil {
                                            let userInfo = ["email" : email, "password" : password]
                                            UserDefaults.standard.set(userInfo, forKey: "userInformation")
                                            completion(true)
                                        }
                                    })
                                }
                            }
                        })
                    }
                })
            }
            else {
                completion(false)
            }
        })
    }
    
   class func loginUser(withEmail: String, password: String, completion: @escaping (Bool) -> Swift.Void) {
        Auth.auth().signIn(withEmail: withEmail, password: password, completion: { (user, error) in
            if error == nil {
                updateFCMToken(completion: { })
                let userInfo = ["email": withEmail, "password": password]
                UserDefaults.standard.set(userInfo, forKey: "userInformation")
                completion(true)
            } else {
                completion(false)
            }
        })
    }
    
    class func logOutUser(completion: @escaping (Bool) -> Swift.Void) {
        do {
            try Auth.auth().signOut()
            UserDefaults.standard.removeObject(forKey: "userInformation")
            defaults.set(false, forKey: "secondTime")
            completion(true)
        } catch _ {
            completion(false)
        }
    }
    
   class func info(forUserID: String, completion: @escaping (User) -> Swift.Void) {
        Database.database().reference().child("users").child(forUserID).child("credentials").observeSingleEvent(of: .value, with: { (snapshot) in
            if let data = snapshot.value as? [String: String] {
                let name = data["name"]!
                let email = data["email"]!
                let FCMToken = data["deviceToken"] ?? "test"
                let link = URL.init(string: data["profilePicLink"]!)
                URLSession.shared.dataTask(with: link!, completionHandler: { (data, response, error) in
                    if error == nil {
                        let profilePic = UIImage.init(data: data!)
                        let user = User.init(name: name, email: email, id: forUserID, FCMToken: FCMToken, profilePic: profilePic!)
                        completion(user)
                    }
                }).resume()
            }
        })
    }
    
    class func downloadAllUsers(exceptID: String, completion: @escaping (User) -> Swift.Void) {
        Database.database().reference().child("users").observe(.childAdded, with: { (snapshot) in
            let id = snapshot.key
            let data = snapshot.value as! [String: Any]
            let credentials = data["credentials"] as! [String: String]
            if id != exceptID {
                let name = credentials["name"]!
                let email = credentials["email"]!
                let FCMToken = credentials["deviceToken"] ?? "test"
                let link = URL.init(string: credentials["profilePicLink"]!)
                URLSession.shared.dataTask(with: link!, completionHandler: { (data, response, error) in
                    if error == nil {
                        let profilePic = UIImage.init(data: data!)
                        let user = User.init(name: name, email: email, id: id, FCMToken: FCMToken, profilePic: profilePic!)
                        completion(user)
                    }
                }).resume()
            }
        })
    }
    
    class func checkUserVerification(completion: @escaping (Bool) -> Swift.Void) {
        Auth.auth().currentUser?.reload(completion: { (_) in
            let status = (Auth.auth().currentUser?.isEmailVerified)!
            completion(status)
        })
    }
    
    class func blockUser(blockedUser: User, completion: @escaping () -> Void) {
        if let currentUserID = Auth.auth().currentUser?.uid {
            // remove blockedUser convo
            Database.database().reference().child("users").child(currentUserID).child("conversations").child(blockedUser.id).observeSingleEvent(of: .value, with: { (snapshot) in
                let data = snapshot.value as! [String: String]
                let location = data["location"]!
                
                Database.database().reference().child("conversations").child(location).removeValue(completionBlock: { (error, _) in
                    // remove convo location data from current user
                    Database.database().reference().child("users").child(currentUserID).child("conversations").child(blockedUser.id).removeValue()
                    
                    // remove convo location data from blocked user
                    Database.database().reference().child("users").child(blockedUser.id).child("conversations").child(currentUserID).removeValue()
                    
                    // add reciprocal user to blocklist for current and blocked user
                    let blockUserID = [blockedUser.id: true]
                    Database.database().reference().child("users").child(currentUserID).child("blockList").updateChildValues(blockUserID, withCompletionBlock: { (error, _) in
                        
                        Database.database().reference().child("users").child(blockedUser.id).child("blockList").updateChildValues([currentUserID: true], withCompletionBlock: { (error, _) in
                            completion()
                        })
                    })
                    
                    
                })
            })
        }
    }
    
    class func updateFCMToken(completion: @escaping () -> Void) {
        if let currentUserID = Auth.auth().currentUser?.uid {
            let value = ["deviceToken": AppDelegate.DEVICEID]
            Database.database().reference().child("users").child(currentUserID).child("credentials").updateChildValues(value, withCompletionBlock: { (errr, _) in
                if errr == nil {
                    completion()
                }
            })
        }
    }

    
    //MARK: Inits
    init(name: String, email: String, id: String, FCMToken: String, profilePic: UIImage) {
        self.name = name
        self.email = email
        self.id = id
        self.profilePic = profilePic
        self.FCMToken = FCMToken
    }
}

