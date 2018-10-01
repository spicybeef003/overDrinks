//
//  StatusVC.swift
//  QuickChat
//
//  Created by Tony Jiang on 9/8/18.
//  Copyright © 2018 Mexonis. All rights reserved.
//

import UIKit
import Eureka
import ViewRow
import Disk
import Firebase
import CloudKit
import Reachability
import NVActivityIndicatorView
import GeoFire

class StatusVC: FormViewController, MyPhotosVCDelegate, CLLocationManagerDelegate, NVActivityIndicatorViewable {
    
    var underage: Bool = true
    
    var myPhotos: [UIImage]!
    var changedPhoto: [Bool]!
    
    let receiveStatement = "Receive a drink"
    let buyStatement = "Buy someone a drink"
    
    var locationManager: CLLocationManager!
    lazy var geocoder = CLGeocoder()
    var userLocation: CLLocationCoordinate2D?
    
    let defaultFont = UIFont(name: "AvenirNext-Regular", size: 16)!
    let boldFont = UIFont(name: "AvenirNext-Bold", size: 16)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        changeEurekaText()
        
        if Disk.exists("myPhotos", in: .documents) {
            myPhotos = try? Disk.retrieve("myPhotos", from: .documents, as: [UIImage].self)
        }
        else {
            myPhotos = [UIImage](repeating: UIImage(named: "profile pic")!, count: 6)
            try? Disk.save(myPhotos, to: .documents, as: "myPhotos")
        }
        
        if let arrayBool = defaults.array(forKey: "changedPhoto") as? [Bool] {
            changedPhoto = arrayBool
        }
        else {
            changedPhoto = [Bool](repeating: false, count: 6)
            defaults.setValue(changedPhoto, forKey: "changedPhoto")
        }
        
        if !defaults.bool(forKey: "secondTime") { // if first time, check cloud, otherwise use saved info
            defaults.set(false, forKey: "receive")
            defaults.set(false, forKey: "buy")
            
            checkCloudData()
            defaults.set(true, forKey: "secondTime")
        }
        
        // setup filters
        if let _ = defaults.array(forKey: "filters") as? [Bool] {
        }
        else {
            var filters = [Bool](repeating: true, count: 5)
            defaults.set(filters, forKey: "filters")
        }
        
        setupNav()
        setupForm()
        
        try? reachability.startNotifier()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        if reachability.connection == .none {
            print("No internet connection")
            self.alert(message: "Please check your internet connection and try again.", title: "Internet connection is not available")
        }
        else {
            self.updateForm()
            self.determineMyCurrentLocation()
        }
    }
    
    func checkCloudData() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        self.tabBarController?.tabBar.isHidden = true
        
        NVActivityIndicatorView.DEFAULT_COLOR = .white
        NVActivityIndicatorView.DEFAULT_TEXT_COLOR = .white
        NVActivityIndicatorView.DEFAULT_BLOCKER_MESSAGE = "Setting up profile"
        self.startAnimating()
        let predicate = NSPredicate(format: "firebaseID == %@", Auth.auth().currentUser!.uid)
        let query = CKQuery(recordType: "CloudProfilePictures", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.qualityOfService = .userInitiated

        operation.queryCompletionBlock = { cursor, error in
            DispatchQueue.main.async {
                self.updateForm()
                self.stopAnimating()
                self.tabBarController?.tabBar.isHidden = false
                
                
            }
        }
        
        operation.recordFetchedBlock = { record in
            self.changedPhoto = [Bool](repeating: false, count: 6)
            if let picAssets = record.value(forKey: "pictureAssets") as? [CKAsset] {
                for (index,asset) in picAssets.enumerated() {
                    self.myPhotos[index] = asset.image()!
                    self.changedPhoto[index] = true
                    if index == 0 {
                        self.updateFirebaseProfilePic(picture: self.myPhotos[0])
                    }
                }
                
                try? Disk.remove("myPhotos", from: .documents)
                try? Disk.save(self.myPhotos, to: .documents, as: "myPhotos")
                defaults.setValue(self.changedPhoto, forKey: "changedPhoto")
            }
        }
        
        database.add(operation)
    }
    
    func updateFirebaseProfilePic(picture: UIImage) {
        if let userID = Auth.auth().currentUser?.uid {
            let imageData = UIImageJPEGRepresentation(picture, 0.2)
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
        }
    }
 
    func changedPhotos(newPhotos: [UIImage], newChangedPhoto newChangedPhotos: [Bool]) {
        myPhotos = newPhotos
        changedPhoto = newChangedPhotos
        if let viewRow:ViewRow<UIImageView> = form.rowBy(tag: "profilePic") {
            for (index, boolValue) in changedPhoto.enumerated() {
                if boolValue {
                    let image = self.myPhotos[index]
                    viewRow.view?.image = image
                    viewRow.reload()
                    break
                }
            }
        }
    }
    
    func uploadCoordinates() {
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .authorizedAlways, .authorizedWhenInUse:
                if let _ = userLocation {
                    let geofireRef = Database.database().reference()
                    let geoFire = GeoFire(firebaseRef: geofireRef.child("userLocations"))
                    geoFire.setLocation(CLLocation(latitude: userLocation!.latitude, longitude: userLocation!.longitude), forKey: Auth.auth().currentUser!.uid)
                    
                    //geoFire.setLocation(CLLocation(latitude: 39.1329, longitude: 84.5150), forKey: "N0O9bfURrhbFeIWagPYFkWmBEiD2")
                }
                
                var values = [String: String]()
                
                if defaults.bool(forKey: "receive") {
                    values.updateValue(String(Date().timeIntervalSince1970), forKey: "receive")
                }
                else {
                    values.updateValue("0", forKey: "receive")
                }
                
                if defaults.bool(forKey: "buy") {
                    values.updateValue(String(Date().timeIntervalSince1970), forKey: "buy")
                }
                else {
                    values.updateValue("0", forKey: "buy")
                }
                
                if let currentUserId = Auth.auth().currentUser?.uid {
                    Database.database().reference().child("users").child(currentUserId).child("credentials").updateChildValues(values, withCompletionBlock: { (errr, _) in
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    })
                }
                else {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
                
                
            case .notDetermined, .restricted, .denied:
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                print("No access")
            }
        }
    }
    
    func updateForm() {
        
        checkTimers()
        
        if let bdayLabel = form.rowBy(tag: "validBday") {
            if let dateRow = form.rowBy(tag: "birthday") as? DateRow {
                if let bday = dateRow.value {
                    let ageComponents = Calendar.current.dateComponents([.year], from: bday, to: Date())
                    let age = ageComponents.year!
                    bdayLabel.title = age > 21 ? "\(age) years old" : "Under 21 years old"
                    defaults.set(age > 21 ? "\(age) years old" : "Under 21 years old", forKey: "age")
                    underage = age > 21 ? false : true
                    bdayLabel.updateCell()
                }
            }
        }
        
        reloadReceiveElapse()
        reloadBuyElapse()
        
        if let viewRow: ViewRow<UIImageView> = form.rowBy(tag: "profilePic") {
            if let _ = changedPhoto {
                for (index, boolValue) in changedPhoto.enumerated() {
                    if boolValue {
                        let image = self.myPhotos[index]
                        viewRow.view?.image = image
                        viewRow.reload()
                        break
                    }
                }
            }
        }
        
        if let section = form.sectionBy(tag: "section1") {
            section.evaluateHidden()
        }
        
        if let section = form.sectionBy(tag: "section3") {
            section.evaluateHidden()
        }
    }
    
    func checkTimers() {
        if defaults.bool(forKey: "receive") {
            let elapsedTime = Date().timeIntervalSince(defaults.object(forKey: "receiveCreated") as! Date)
            if elapsedTime > 60 * 60 * 4 {
                let switchRow: SwitchRow = form.rowBy(tag: "receive")!
                switchRow.value = false
                switchRow.reload(with: .fade)
                defaults.set(false, forKey: "receive")
            }
        }
        
        if defaults.bool(forKey: "buy") {
            let elapsedTime = Date().timeIntervalSince(defaults.object(forKey: "buyCreated") as! Date)
            if elapsedTime > 60 * 60 * 4 {
                let switchRow: SwitchRow = form.rowBy(tag: "buy")!
                switchRow.value = false
                switchRow.reload(with: .fade)
                defaults.set(false, forKey: "buy")
            }
        }
    }
    
    func reloadReceiveElapse() {
        if let receiveElapse = form.rowBy(tag: "receiveElapse") {
            if defaults.bool(forKey: "receive") {
                if let receiveCreated = defaults.object(forKey: "receiveCreated") as? Date {
                    receiveElapse.title = "Wanted a drink for \(Date().offset(from: receiveCreated))"
                    receiveElapse.reload(with: .top)
                }
            }
        }
    }
    
    func reloadBuyElapse() {
        if let buyElapse = form.rowBy(tag: "buyElapse") {
            if defaults.bool(forKey: "buy") {
                if let buyCreated = defaults.object(forKey: "buyCreated") as? Date {
                    buyElapse.title = "Wanted a drink for \(Date().offset(from: buyCreated))"
                    buyElapse.reload(with: .top)
                }
            }
        }
    }
    
    func setupForm() {
        form
        // WHAT I WANT
        +++ Section(header: "I would like to...", footer: "Note: Desires only remain active for 4 hours. Tap refresh to reset the timer.") { section in
            section.tag = "section1"
            section.hidden = Condition.function(["name", "birthday", "manage", "profilePic", "sex"], { form in
                if let _ = (form.rowBy(tag: "name") as? TextRow)?.value {
                    if !self.underage {
                        if self.changedPhoto.contains(true) {
                            if let segRow: SegmentedRow<String> = form.rowBy(tag: "sex") {
                                if let _ = segRow.value {
                                    self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
                                    return false
                                }
                            }
                            
                        }
                    }
                }
                return true
            })
        }
            
            <<< SwitchRow("receive") { row in
                row.value = defaults.bool(forKey: "receive") ? true : false
                if row.value! {
                    row.title = "ACTIVE: " + receiveStatement
                }
                else {
                    row.title = "INACTIVE: " + receiveStatement
                }
                }.onChange { row in
                    row.title = row.value! ? "ACTIVE: " + self.receiveStatement : "INACTIVE: " + self.receiveStatement
                    if row.value! {
                        defaults.set(true, forKey: "receive")
                        defaults.set(Date(), forKey: "receiveCreated")
                    }
                    else {
                        defaults.set(false, forKey: "receive")
                    }
                    self.uploadCoordinates()
                    self.reloadReceiveElapse()
                    row.updateCell()
                }.cellUpdate { cell, row in
                    cell.textLabel?.font = defaults.bool(forKey: "receive") ? self.boldFont : self.defaultFont
            }
            
            <<< LabelRow("receiveElapse"){
                $0.hidden = Condition.function(["receive"], { form in
                    return !((form.rowBy(tag: "receive") as? SwitchRow)?.value ?? false)
                })
                if defaults.bool(forKey: "receive") {
                    if let receiveCreated = defaults.object(forKey: "receiveCreated") as? Date {
                        $0.title = "Wanted a drink for \(Date().offset(from: receiveCreated))"
                    }
                }
            }
            
            <<< SwitchRow("buy") { row in
                row.value = defaults.bool(forKey: "buy") ? true : false
                if row.value! {
                    row.title = "ACTIVE: " + buyStatement
                }
                else {
                    row.title = "INACTIVE: " + buyStatement
                }
                }.onChange { row in
                    row.title = row.value! ? "ACTIVE: " + self.buyStatement : "INACTIVE: " + self.buyStatement
                    if row.value! {
                        defaults.set(true, forKey: "buy")
                        defaults.set(Date(), forKey: "buyCreated")
                    }
                    else {
                        defaults.set(false, forKey: "buy")
                    }
                    self.uploadCoordinates()
                    self.reloadBuyElapse()
                    row.updateCell()
                }.cellUpdate { cell, row in
                    cell.textLabel?.font = defaults.bool(forKey: "buy") ? self.boldFont : self.defaultFont
            }
            
            <<< LabelRow("buyElapse"){
                $0.hidden = Condition.function(["buy"], { form in
                    return !((form.rowBy(tag: "buy") as? SwitchRow)?.value ?? false)
                })
                if defaults.bool(forKey: "buy") {
                    if let buyCreated = defaults.object(forKey: "buyCreated") as? Date {
                        $0.title = "Wanted a drink for \(Date().offset(from: buyCreated))"
                    }
                }
            }
            
            <<< ButtonRow("refresh") {
                $0.title = "Refresh"
                $0.onCellSelection( { (cell, row) in
                    if defaults.bool(forKey: "receive") {
                        defaults.set(Date(), forKey: "receiveCreated")
                        self.reloadReceiveElapse()
                    }
                    
                    if defaults.bool(forKey: "buy") {
                        defaults.set(Date(), forKey: "buyCreated")
                        self.reloadBuyElapse()
                    }
                    
                    self.uploadCoordinates()
                })
            }
        
            
        // MY INFORMATION
        +++ Section("My Information")
            <<< TextRow("name") { row in
                row.title = "First Name"
                row.placeholder = "Name Here"
                
                NVActivityIndicatorView.DEFAULT_COLOR = .white
                NVActivityIndicatorView.DEFAULT_TEXT_COLOR = .white
                NVActivityIndicatorView.DEFAULT_BLOCKER_MESSAGE = "Loading profile"
                self.startAnimating()
                User.info(forUserID: Auth.auth().currentUser!.uid, completion: { user in
                    DispatchQueue.main.async {
                        self.stopAnimating()
                        row.value = user.name
                        row.updateCell()
                        defaults.set(user.name.trimmingCharacters(in: .whitespaces), forKey: "name")
                    }
                })
                
                }.onCellHighlightChanged { cell, row in
                    if !row.isHighlighted {
                        if let name = row.value {
                            if name.trimmingCharacters(in: .whitespaces).count > 0 {
                                defaults.set(name.trimmingCharacters(in: .whitespaces), forKey: "name")
                                let value = ["name": name.trimmingCharacters(in: .whitespaces)]
                                Database.database().reference().child("users").child(Auth.auth().currentUser!.uid).child("credentials").updateChildValues(value, withCompletionBlock: { (errr, _) in
                                    if errr == nil {
                                        print("updated name")
                                    }
                                })
                            }
                        }
                    }
                }.onChange { row in
                    row.updateCell()
                }.cellUpdate { cell, row in
                    if let name = row.value {
                        if name.trimmingCharacters(in: .whitespaces).count > 0 {
                            cell.textLabel?.textColor = .black
                        }
                    }
                    else {
                        cell.textLabel?.textColor = .red
                    }
            }
            
            <<< SegmentedRow<String>("sex") {
                $0.title = "Sex"
                $0.options = ["Male", "Female", "Non-binary"]
                
                if let sex = defaults.object(forKey: "sex") as? String {
                    $0.value = sex
                }
                
                }.onChange { row in
                    defaults.set(row.value!, forKey: "sex")
                    
                    var filters = [Bool](repeating: true, count: 5)
                    if row.value! == "Male" {
                        filters[0] = false
                        filters[2] = false
                        defaults.set(filters, forKey: "filters")
                    }
                    else if row.value! == "Female" {
                        filters[1] = false
                        filters[2] = false
                        defaults.set(filters, forKey: "filters")
                    }
                    
                    let value = ["sex": row.value!]
                    Database.database().reference().child("users").child(Auth.auth().currentUser!.uid).child("credentials").updateChildValues(value, withCompletionBlock: { (errr, _) in
                        print("updated sex")
                    })
                    row.updateCell()
                }.cellUpdate { cell, row in
                    cell.segmentedControl.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .horizontal)
                    if let _ = defaults.object(forKey: "sex") as? String {
                        cell.textLabel?.textColor = .black
                    }
                    else {
                        cell.textLabel?.textColor = .red
                    }
            }
            
            <<< DateRow("birthday") {
                $0.title = "Date of Birth"
                if let bday = defaults.object(forKey: "birthday") as? Date {
                    $0.value = bday
                }
                else {
                    $0.value = Date()
                }
                }.onChange { row in
                    if let date = row.value {
                        defaults.set(date, forKey: "birthday")
                        let ageComponents = Calendar.current.dateComponents([.year], from: date, to: Date())
                        let age = ageComponents.year!
                        self.underage = age > 21 ? false : true
                        
                        if let bdayLabel = self.form.rowBy(tag: "validBday") {
                            bdayLabel.title = age > 21 ? "\(age) years old" : "Under 21 years old"
                            let value = ["age": bdayLabel.title!]
                            Database.database().reference().child("users").child(Auth.auth().currentUser!.uid).child("credentials").updateChildValues(value, withCompletionBlock: { (errr, _) in
                                print("updated age")
                            })
                            print("saved bday")
                            bdayLabel.updateCell()
                        }
                    }
            }
            
            <<< LabelRow("validBday") {
                $0.title = ""
                $0.cellStyle = .default
                }.cellUpdate { cell, row in
                    cell.textLabel?.textColor = self.underage ? UIColor.red : UIColor.black
                    cell.textLabel?.textAlignment = .right
                }
            
            // MY PICTURES
            +++ Section("My Profile pictures") { section in
                section.tag = "section3"
                section.hidden = Condition.function(["name", "birthday", "sex"], { form in
                    if let _ = (form.rowBy(tag: "name") as? TextRow)?.value {
                        if !self.underage {
                            if let segRow: SegmentedRow<String> = form.rowBy(tag: "sex") {
                                if let _ = segRow.value {
                                    return false
                                }
                            }
                        }
                    }
                    return true
                })
            }
            
            <<< ButtonRow("manage") {
                $0.title = "Manage Pictures"
                $0.onCellSelection( { (cell, row) in
                    self.toManagePhotos()
                })
            }
            
            <<< ViewRow<UIImageView>("profilePic")
                .cellSetup { (cell, row) in
                    cell.height = { return CGFloat(200) }
                    
                    cell.view = UIImageView()
                    cell.contentView.addSubview(cell.view!)
                    cell.view?.isUserInteractionEnabled = true
                    
                    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.toManagePhotos))
                    cell.view?.addGestureRecognizer(tapGesture)
                    
                    //  Get something to display
                    var image = UIImage(named: "profile pic")!
                    for (index, boolValue) in self.changedPhoto.enumerated() {
                        if boolValue {
                            let profilePic = self.myPhotos[index]
                            image = profilePic
                            break
                        }
                    }
                    
                    cell.view!.image = image
                    cell.view!.contentMode = .scaleAspectFit
                    
                    cell.view!.layer.cornerRadius = 300
                    cell.view!.layer.masksToBounds = true
                    //cell.view!.layer.borderWidth = 1.5
                    cell.view!.clipsToBounds = true
                    cell.clipsToBounds = true
            }
        
            <<< ButtonRow("view") {
                $0.title = "View Pictures"
                $0.onCellSelection( { (cell, row) in
                    self.performSegue(withIdentifier: "toPicturesFromProfile", sender: self)
                })
        }
        
    }
    
    @objc func toManagePhotos() {
        self.performSegue(withIdentifier: "toPhotos", sender: self)
    }
    
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? MyPhotosVC {
            destination.myPhotos = myPhotos
            destination.changedPhoto = changedPhoto
            destination.delegate = self
        }
        
        if let nc = segue.destination as? UINavigationController {
            if let destination = nc.topViewController as? CustomTabVC {
                destination.firebaseID = Auth.auth().currentUser!.uid
            }
        }
    }

}

extension StatusVC {
    func determineMyCurrentLocation() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        manager.delegate = nil
        manager.stopUpdatingLocation()
        
        if let location = locations.last{
            userLocation = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            self.uploadCoordinates()
        }
    }
    
    func changeEurekaText() {
        SwitchRow.defaultCellSetup =  { cell, row in
            cell.textLabel?.font = self.defaultFont
        }
        
        LabelRow.defaultCellSetup =  { cell, row in
            cell.textLabel?.font = self.defaultFont
        }
        
        ButtonRow.defaultCellSetup =  { cell, row in
            cell.textLabel?.font = self.defaultFont
        }
        
        SegmentedRow<String>.defaultCellSetup =  { cell, row in
            cell.textLabel?.font = self.defaultFont
        }
        
        DateRow.defaultCellSetup =  { cell, row in
            cell.textLabel?.font = self.defaultFont
            cell.detailTextLabel?.font = self.defaultFont
        }
        
        TextRow.defaultCellSetup =  { cell, row in
            cell.textLabel?.font = self.defaultFont
            cell.detailTextLabel?.font = self.defaultFont
        }
    }
}
