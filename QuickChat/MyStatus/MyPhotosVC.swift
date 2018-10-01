//
//  MyPhotosVC.swift
//  QuickChat
//
//  Created by Tony Jiang on 9/8/18.
//  Copyright © 2018 Mexonis. All rights reserved.
//

import UIKit
import MobileCoreServices
import Disk
import Photos
import CloudKit
import Firebase

protocol MyPhotosVCDelegate: class {
    func changedPhotos(newPhotos: [UIImage], newChangedPhoto: [Bool])
}

class MyPhotosVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UIGestureRecognizerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var doneOutlet: UIBarButtonItem!
    
    var myPhotos: [UIImage]!
    var changedPhoto: [Bool]! // track the photos that change b/c can't upload duplicates onto cloudkit
    var selectedIndexPath: IndexPath!
    
    var delegate: MyPhotosVCDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.setHidesBackButton(true, animated: true)
        
        let navigationTitleFont = UIFont(name: "AvenirNext-Bold", size: 18)!
        doneOutlet.setTitleTextAttributes([NSAttributedStringKey.font: navigationTitleFont, NSAttributedStringKey.foregroundColor: UIColor.white], for: .normal)
        
        setupCollectionView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        checkPermission()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        updateFirebaseProfilePic()
    }
    
    func updateFirebaseProfilePic() {
        let userID = Auth.auth().currentUser!.uid
        
        for (index, boolValue) in changedPhoto.enumerated() {
            if boolValue {
                let image = self.myPhotos[index]
                
                let imageData = UIImageJPEGRepresentation(image, 0.2)
                
                let storageRef = Storage.storage().reference().child("usersProfilePics").child(userID)
                storageRef.putData(imageData!, metadata: nil, completion: { (metadata, err) in
                    if err == nil {
                        storageRef.downloadURL(completion: { url, error in
                            if let path = url?.absoluteString {
                                let value = ["profilePicLink": path]
                                Database.database().reference().child("users").child(userID).child("credentials").updateChildValues(value, withCompletionBlock: { (errr, _) in
                                    if errr == nil {
                                        print("updated profile pic")
                                    }
                                })
                            }
                        })
                        
                    }
                })
                break
            }
        }
    }
    
    func saveToCloud() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        let predicate = NSPredicate(format: "firebaseID == %@", Auth.auth().currentUser!.uid)
        let query = CKQuery(recordType: "CloudProfilePictures", predicate: predicate)
        
        database.perform(query, inZoneWith: nil) { (records, error) in
            guard let records = records else { return }
            
            var picAssets: [CKAsset] = []
            if let _ = self.changedPhoto {
                for (index,thisBool) in self.changedPhoto.enumerated() {
                    if thisBool {
                        picAssets.append(self.convertImageToCKAsset(image: self.myPhotos[index]))
                    }
                }
                
                if records.count > 0 {
                    let cloudProfilePics = records[0]
                    cloudProfilePics.setValue(picAssets, forKey: "pictureAssets")
                    //cloudProfilePics.setValue(self.convertToInt(self.changedPhoto), forKey: "changedPhoto")
                    self.saveRecord(record: records[0])
                }
                else {
                    let cloudProfilePics = CKRecord(recordType: "CloudProfilePictures")
                    cloudProfilePics.setValue(defaults.string(forKey: "name"), forKey: "name")
                    cloudProfilePics.setValue(defaults.string(forKey: "age"), forKey: "age")
                    cloudProfilePics.setValue(Auth.auth().currentUser?.uid, forKey: "firebaseID")
                    cloudProfilePics.setValue(picAssets, forKey: "pictureAssets")
                    //cloudProfilePics.setValue(self.convertToInt(self.changedPhoto), forKey: "changedPhoto")
                    self.saveRecord(record: cloudProfilePics)
                }
            }
        }
    }
    
  
    func checkPermission() {
        let photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
        switch photoAuthorizationStatus {
        case .authorized: print("Access is granted by user")
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (newStatus) in
                print("status is \(newStatus)")
                if newStatus == PHAuthorizationStatus.authorized {
                    print("success") }
            })
            case .restricted: print("User do not have access to photo album.")
            case .denied: print("User has denied the permission.")
            }
        }
    
    func setupCollectionView() {
        let cellWidth = view.frame.width * 0.4
        let cellSize = CGSize(width: cellWidth , height: cellWidth) // make square
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = cellSize
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 10, right: 20)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        collectionView.setCollectionViewLayout(layout, animated: true)
        collectionView.delegate = self
        collectionView.dataSource = self
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressGesture))
        longPress.delegate = self
        longPress.minimumPressDuration = 0.4
        collectionView.addGestureRecognizer(longPress)
        
        collectionView.perform(#selector(collectionView.reloadData), with: nil, afterDelay: 0.2)
    }
    
    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        let _ = self.navigationController?.popViewController(animated: true)
    }
    
    @objc func longPressGesture(gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            guard let selectedIndexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView)) else { break }
            collectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
        case .changed:
            collectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
        case .ended:
            collectionView.endInteractiveMovement()
        default:
            collectionView.cancelInteractiveMovement()
        }
    }
    
    @objc func deletePic(_ sender: AnyObject) {
        let myAlert = UIAlertController(title: "Options", message: nil, preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: "Delete", style: .default) { (ACTION) in
            let defaultPic = UIImage(named: "profile pic")!
            self.myPhotos[sender.view.tag] = defaultPic
            self.changedPhoto[sender.view.tag] = false
            try? Disk.remove("myPhotos", from: .documents)
            try? Disk.save(self.myPhotos, to: .documents, as: "myPhotos")
            defaults.set(self.changedPhoto, forKey: "changedPhoto")
            self.delegate?.changedPhotos(newPhotos: self.myPhotos, newChangedPhoto: self.changedPhoto)
            self.saveToCloud()
            self.collectionView.reloadData()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (ACTION) in
            
        }
        
        myAlert.addAction(deleteAction)
        myAlert.addAction(cancelAction)
        
        self.present(myAlert, animated: true, completion: nil)
    }
    
    // MARK: start collectionview setup
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return myPhotos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell1", for: indexPath) as! ProfileCell
        cell.backgroundColor = UIColor.clear
        
        let image = myPhotos[indexPath.row]
        cell.profilePic.image = image
        cell.profilePic.layer.cornerRadius = cell.profilePic.frame.height/2
        cell.profilePic.layer.borderWidth = 3
        cell.profilePic.layer.borderColor = GlobalVariables.purple.cgColor
        
        cell.deleteIcon.isHidden = self.changedPhoto[indexPath.row] ? false : true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.deletePic))
        cell.deleteIcon.tag = indexPath.row
        cell.deleteIcon.addGestureRecognizer(tapGesture)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndexPath = indexPath
        
        let myAlert = UIAlertController(title: "Media Options", message: nil, preferredStyle: .actionSheet)
        
        let libraryAction = UIAlertAction(title: "Photo Library", style: .default) { _ in
            self.openLibrary()
        }
        
        let takePhotoAction = UIAlertAction(title: "Camera", style: .default) { _ in
            self.takePhoto()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        myAlert.addAction(libraryAction)
        myAlert.addAction(takePhotoAction)
        myAlert.addAction(cancelAction)
        
        self.present(myAlert, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let image = myPhotos[sourceIndexPath.row]
        myPhotos.remove(at: sourceIndexPath.row)
        myPhotos.insert(image, at: destinationIndexPath.row)
        
        let thisBool = changedPhoto[sourceIndexPath.row]
        changedPhoto.remove(at: sourceIndexPath.row)
        changedPhoto.insert(thisBool, at: destinationIndexPath.row)
        
        try? Disk.remove("myPhotos", from: .documents)
        try? Disk.save(self.myPhotos, to: .documents, as: "myPhotos")
    }
    // MARK: end collectionview setup

}

extension MyPhotosVC {
    func openLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    func takePhoto() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .camera
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true, completion: nil)
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.myPhotos[self.selectedIndexPath.row] = pickedImage.fixOrientation()
            self.changedPhoto[self.selectedIndexPath.row] = true
            self.collectionView.reloadData()
            self.saveToCloud()
            self.dismiss(animated: true, completion: {
                try? Disk.remove("myPhotos", from: .documents)
                try? Disk.save(self.myPhotos, to: .documents, as: "myPhotos")
                defaults.set(self.changedPhoto, forKey: "changedPhoto")
                print(self.changedPhoto)
                self.delegate?.changedPhotos(newPhotos: self.myPhotos, newChangedPhoto: self.changedPhoto)
            })
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
}

class ProfileCell: UICollectionViewCell {
    @IBOutlet weak var profilePic: UIImageView!
    @IBOutlet weak var deleteIcon: UIImageView!
}
