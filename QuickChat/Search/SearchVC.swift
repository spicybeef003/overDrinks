//
//  SearchVC.swift
//  QuickChat
//
//  Created by Tony Jiang on 9/8/18.
//  Copyright © 2018 Mexonis. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Firebase
import Cluster
import GeoFire

class SearchVC: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UIPopoverPresentationControllerDelegate, FilterOptionsTVCDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var refreshOutlet: UIBarButtonItem!
    @IBOutlet weak var filterOutlet: UIBarButtonItem!
    @IBOutlet weak var legendOutlet: UIBarButtonItem!
    
    var locationManager: CLLocationManager!
    lazy var geocoder = CLGeocoder()
    var userLocation: CLLocationCoordinate2D?
    
    let clusterManager = ClusterManager()
    
    var names: [String] = []
    var ages: [String] = []
    var firebaseIDs: [String] = []
    var buys: [Bool] = []
    var receives: [Bool] = []
    
    let searchRadius: Double = 400 // // meters; change to 400 before publication
    
    var refreshGroup = DispatchGroup()
    var isRefreshing = false
    
    var userInfo = [String: CLLocation]()
    var circleQuery: GFCircleQuery!
    var queryHandle: UInt!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupNav()
        
        refreshOutlet.tintColor = .white
        filterOutlet.tintColor = .white
        legendOutlet.tintColor = .white
        
        mapView.delegate = self
        
        clusterManager.minCountForClustering = 3
        clusterManager.maxZoomLevel = 10000000
        clusterManager.cellSize = 85
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if reachability.connection == .none {
            print("No internet connection")
            self.alert(message: "Please check your internet connection and try again.", title: "Internet connection is not available")
        }
        else {
            clusterManager.removeAll()
            for annotation in mapView.annotations {
                mapView.removeAnnotation(annotation)
            }
            
            if defaults.bool(forKey: "buy") || defaults.bool(forKey: "receive") {
                determineMyCurrentLocation()
            }
            else {
                let myAlert = UIAlertController(title: "Please enter your status", message: nil, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .cancel, handler: { _ in
                    self.tabBarController?.selectedIndex = 0
                })
                myAlert.addAction(okAction)
                self.present(myAlert, animated: true)
            }
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.clusterManager.reload(mapView: mapView)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
            self.clusterManager.reload(mapView: self.mapView)
            
            for overlay in self.mapView.overlays {
                self.mapView.remove(overlay)
            }
            
            let circle = MKCircle(center: self.mapView.userLocation.coordinate, radius: self.searchRadius)
            self.mapView.add(circle)
        })
    }
    
    
    @IBAction func legendPressed(_ sender: UIBarButtonItem) {
        let popoverContent = self.storyboard?.instantiateViewController(withIdentifier: "LegendVC") as! LegendVC
        
        let nav = UINavigationController(rootViewController: popoverContent)
        nav.modalPresentationStyle = .popover
        let popover = nav.popoverPresentationController
        
        popoverContent.preferredContentSize = CGSize(width: 350, height: 170)
        
        popover?.barButtonItem = sender
        popover?.permittedArrowDirections = [.down, .up]
        popover?.delegate = self
        self.present(nav, animated: true, completion: nil)
    }
    
    
    @IBAction func filterPressed(_ sender: UIBarButtonItem) {
        let popoverContent = self.storyboard?.instantiateViewController(withIdentifier: "FilterOptionsTVC") as! FilterOptionsTVC
        popoverContent.delegate = self
        
        let nav = UINavigationController(rootViewController: popoverContent)
        nav.modalPresentationStyle = .popover
        let popover = nav.popoverPresentationController
        
        let height = popoverContent.tableView.contentSize.height < self.view.frame.height/2 ? popoverContent.tableView.contentSize.height : self.view.frame.height/2
        popoverContent.preferredContentSize = CGSize(width: self.view.frame.width * 0.8, height: height)
        
        popover?.barButtonItem = sender
        popover?.permittedArrowDirections = [.down, .up]
        popover?.delegate = self
        self.present(nav, animated: true, completion: nil)
    }
    
    func filterChanged(newFilters: [Bool]) {
        refreshPressed(nil)
    }
    
    
    @IBAction func refreshPressed(_ sender: UIBarButtonItem?) {
        sender?.isEnabled = false
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        refreshGroup.enter()
        isRefreshing = true
        
        clusterManager.removeAll()
        for overlay in self.mapView.overlays {
            self.mapView.remove(overlay)
        }
        DispatchQueue.main.async {
            self.findPeopleNearMe()
        }
        
        refreshGroup.notify(queue: .main) {
            sender?.isEnabled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                self.clusterManager.reload(mapView: self.mapView)
                let region = MKCoordinateRegionMakeWithDistance(self.userLocation!, self.searchRadius*2, self.searchRadius*2)
                self.mapView.setRegion(region, animated: true)
                
                let circle = MKCircle(center: self.mapView.userLocation.coordinate, radius: self.searchRadius)
                self.mapView.add(circle)
            })
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
    }
    
    func findPeopleNearMe() {
        let geofireRef = Database.database().reference()
        let geoFire = GeoFire(firebaseRef: geofireRef.child("userLocations"))
        
        circleQuery = geoFire.query(at: CLLocation(latitude: userLocation!.latitude, longitude: userLocation!.longitude), withRadius: searchRadius/1000)
        userInfo = [String: CLLocation]()
        queryHandle = circleQuery.observe(.keyEntered, with: { (userID: String!, location: CLLocation!) in
            print("start query")
            self.clusterManager.removeAll()
            if userID != Auth.auth().currentUser!.uid {
                self.userInfo.updateValue(location, forKey: userID)
                //print("userID '\(userID)' entered the search area and is at location '\(location)'")
            }
            //geoFire.removeKey(userID)
        })

        circleQuery.observeReady({
            print("finished getting users and locations")
            if self.userInfo.count > 0 {
                self.addUsersToMap(userInfo: self.userInfo)
                for (userID, location) in self.userInfo {
                    geoFire.removeKey(userID)
                }
            }
            else {
                if self.tabBarController?.selectedIndex == 1 {
                    self.alert(message: "Please try again later.", title: "No one is exciting around you 😞")
                }
            }
        })
    
    }
    
    func addUsersToMap(userInfo: [String: CLLocation]) {
        let group = DispatchGroup()
        Database.database().reference().child("users").observe(.value, with: { (snapshot) in
            if snapshot.exists() {
                for child in snapshot.children {
                    let snap = child as! DataSnapshot
                    if let location = userInfo[snap.key] {
                        group.enter()
                        
                        let person = snap.childSnapshot(forPath: "credentials").value as! [String: String]
                        
                        let thisLocation = location.coordinate
                        
                        let personBuying = Double(Date().timeIntervalSince1970) - Double(person["buy"]!)! < 60 * 60 * 4
                        let personReceiving = Double(Date().timeIntervalSince1970) - Double(person["receive"]!)! < 60 * 60 * 4
                        
                        if personBuying || personReceiving {
                            let annotation = PeopleAnnotation()
                            annotation.coordinate = thisLocation
                            annotation.firebaseID = snap.key
                            annotation.name = person["name"]
                            annotation.age = person["age"]
                            annotation.buy = personBuying
                            annotation.receive = personReceiving
                            
                            if personBuying {
                                annotation.style = .color(UIColor(red: 10/255, green: 93/255, blue: 0/255, alpha: 1), radius: 25)
                            }
                            if personReceiving {
                                annotation.style = .color(UIColor(red: 250/255, green: 128/255, blue: 114/255, alpha: 1), radius: 25)
                            }
                            if personBuying && personReceiving {
                                annotation.style = .color(GlobalVariables.blue, radius: 25)
                            }
                            
                            self.clusterManager.add(annotation)
                            
                            let filters = defaults.array(forKey: "filters") as! [Bool]
                            
                            if !filters[0] && person["sex"] == "Male" {
                                self.clusterManager.remove(annotation)
                                group.leave()
                            }
                            else if !filters[1] && person["sex"] == "Female" {
                                self.clusterManager.remove(annotation)
                                group.leave()
                            }
                            else if !filters[2] && person["sex"] == "Non-binary" {
                                self.clusterManager.remove(annotation)
                                group.leave()
                            }
                            else if !filters[3] && annotation.receive {
                                self.clusterManager.remove(annotation)
                                group.leave()
                            }
                            else if !filters[4] && annotation.buy {
                                self.clusterManager.remove(annotation)
                                group.leave()
                            }
                            else { // remove if blocked
                                Database.database().reference().child("users").child(annotation.firebaseID).child("blockList").observe(.value, with: { snapshot in
                                    if snapshot.exists() {
                                        let data = snapshot.value as! [String: Bool]
                                        if let blocked = data[Auth.auth().currentUser!.uid] {
                                            if blocked {
                                                self.clusterManager.remove(annotation)
                                            }
                                        }
                                        group.leave()
                                    }
                                })
                            }
                        }
                        else {
                            group.leave()
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    print("finished updating map")
                    
                    self.clusterManager.reload(mapView: self.mapView)
                    
                    if self.clusterManager.annotations.count == 0 {
                        if self.tabBarController?.selectedIndex == 1 {
                            self.alert(message: "Please try again later.", title: "No one is exciting around you 😞")
                        }
                    }
                }
            }
        })
        
        if self.isRefreshing { // leave refresh dispatch group
            self.isRefreshing = false
            self.refreshGroup.leave()
        }
    }
    
    func region(for annotation: MKAnnotation) -> MKCoordinateRegion {
        let region: MKCoordinateRegion = MKCoordinateRegionMakeWithDistance(annotation.coordinate, searchRadius, searchRadius)
        
        return mapView.regionThatFits(region)
    }
    
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if let userLocation = annotation as? MKUserLocation {
            userLocation.title = nil
            return nil
        }
        
        if let annotation = annotation as? ClusterAnnotation {
            //guard let style = annotation.style else { return nil }
            let identifier = "Cluster"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if let view = view as? BorderedClusterAnnotationView {
                view.annotation = annotation
                view.style = .color(.orange, radius: 25)
                view.configure()
            }
            else {
                view = BorderedClusterAnnotationView(annotation: annotation, reuseIdentifier: identifier, style: .color(.orange, radius: 25), borderColor: .white)
            }
            
            return view
        }
        else if let annotation = annotation as? MyPointAnnotation {
            let reuseId = "person"
            
            var anView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
            if anView == nil {
                anView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                anView?.canShowCallout = true
            }
            else {
                anView?.annotation = annotation
            }
            
            anView?.image = UIImage(named: annotation.imageName)
            anView?.contentMode = .scaleAspectFill
            anView?.frame.size = CGSize(width: 35, height: 35)
            
            return anView
        }
        else {
            guard let annotation = annotation as? PeopleAnnotation, let style = annotation.style else { return nil }
            let identifier = "Pin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
            if let view = view {
                view.annotation = annotation
                
                view.canShowCallout = false
            }
            else {
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            if case let .color(color, _) = style {
                view?.pinTintColor = color
            }
            else {
                view?.pinTintColor = .green
            }
            
            return view
        }
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        clusterManager.reload(mapView: mapView) { finished in
            
        }
    }
    
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        views.forEach { $0.alpha = 0 }
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [], animations: {
            views.forEach { $0.alpha = 1 }
        }, completion: nil)
    }
    
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else { return }
        
        names = []
        ages = []
        firebaseIDs = []
        buys = []
        receives = []
        
        if let cluster = annotation as? ClusterAnnotation {
            for annotation in cluster.annotations {
                let annotation = annotation as! PeopleAnnotation
                names.append(annotation.name)
                ages.append(annotation.age)
                firebaseIDs.append(annotation.firebaseID)
                buys.append(annotation.buy)
                receives.append(annotation.receive)
            }
            /*
            var zoomRect = MKMapRectNull
            for annotation in cluster.annotations {
                let annotationPoint = MKMapPointForCoordinate(annotation.coordinate)
                let pointRect = MKMapRectMake(annotationPoint.x, annotationPoint.y, 0, 0)
                if MKMapRectIsNull(zoomRect) {
                    zoomRect = pointRect
                } else {
                    zoomRect = MKMapRectUnion(zoomRect, pointRect)
                }
            }
            mapView.setVisibleMapRect(zoomRect, animated: true) */
        }
        
        if let annotation = annotation as? PeopleAnnotation {
            names.append(annotation.name)
            ages.append(annotation.age)
            firebaseIDs.append(annotation.firebaseID)
            buys.append(annotation.buy)
            receives.append(annotation.receive)
        }
        
        if firebaseIDs.count > 1 {
            self.performSegue(withIdentifier: "toClusterResults", sender: self)
        }
        else if firebaseIDs.count == 1 {
            self.performSegue(withIdentifier: "toProfilePicsFromMap", sender: self)
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay.isKind(of: MKCircle.self) {
            let view = MKCircleRenderer(overlay: overlay)
            view.fillColor = UIColor.blue.withAlphaComponent(0.1)
            view.strokeColor = .blue
            view.lineWidth = 1
            return view
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? ClusterResultsVC {
            destination.names = names
            destination.ages = ages
            destination.firebaseIDs = firebaseIDs
            destination.buys = buys
            destination.receives = receives
        }
        
        if let nc = segue.destination as? UINavigationController {
            if let destination = nc.topViewController as? CustomTabVC {
                destination.firebaseID = firebaseIDs[0]
            }
        }
        
    }
}

extension SearchVC {
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
            let center = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let region = MKCoordinateRegionMakeWithDistance(center, searchRadius*2, searchRadius*2)
            self.mapView.setRegion(region, animated: true)

            let annotation = MyPointAnnotation()
            annotation.coordinate = center
            annotation.imageName = "profile pic"
            //mapView.addAnnotation(annotation)
            
            userLocation = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            
            let circle = MKCircle(center: self.mapView.userLocation.coordinate, radius: self.searchRadius)
            self.mapView.add(circle)
            
            clusterManager.removeAll()
            self.findPeopleNearMe()
            
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    func prepareForPopoverPresentation(_ popoverPresentationController: UIPopoverPresentationController) {
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        
    }
    
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        return true
    }
    
}

class BorderedClusterAnnotationView: ClusterAnnotationView {
    let borderColor: UIColor
    
    init(annotation: MKAnnotation?, reuseIdentifier: String?, style: ClusterAnnotationStyle, borderColor: UIColor) {
        self.borderColor = borderColor
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier, style: style)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func configure() {
        super.configure()
        
        switch style {
        case .image:
            layer.borderWidth = 0
        case .color:
            layer.borderColor = borderColor.cgColor
            layer.borderWidth = 2
        }
    }
}

