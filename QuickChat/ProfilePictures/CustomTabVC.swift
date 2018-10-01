//
//  CustomTabmanVC.swift
//  QuickChat
//
//  Created by Tony Jiang on 9/9/18.
//  Copyright © 2018 Mexonis. All rights reserved.
//

import UIKit
import Parchment
import CloudKit
import NVActivityIndicatorView

class CustomTabVC: UIViewController, NVActivityIndicatorViewable {
    
    @IBOutlet weak var doneOutlet: UIBarButtonItem!
    @IBOutlet weak var messageOutlet: UIBarButtonItem!
    
    var viewControllers: [UIViewController]! = []
    
    var firebaseID: String!
    
    var selectedUser: User?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        doneOutlet.tintColor = .white
        messageOutlet.tintColor = .white
        
        loadVCs()
        
        messageOutlet.isEnabled = false
        User.info(forUserID: firebaseID, completion: { user in
            self.selectedUser = user
            DispatchQueue.main.async {
                self.title = user.name
                self.messageOutlet.isEnabled = true
            }
        })
    }
    
    @IBAction func messagePressed(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "toChat", sender: self)
    }
    
    func loadVCs() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        NVActivityIndicatorView.DEFAULT_COLOR = .white
        NVActivityIndicatorView.DEFAULT_TEXT_COLOR = .white
        NVActivityIndicatorView.DEFAULT_BLOCKER_MESSAGE = "Loading pictures"
        self.startAnimating()
        
        viewControllers = []
        
        let predicate = NSPredicate(format: "firebaseID == %@", firebaseID)
        let query = CKQuery(recordType: "CloudProfilePictures", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.qualityOfService = .userInitiated
        
        operation.queryCompletionBlock = { cursor, error in
            if self.viewControllers.count == 0 {
                self.stopAnimating()
            }
            
            DispatchQueue.main.async {
                let pagingViewController = FixedPagingViewController(viewControllers: self.viewControllers)
                self.addChildViewController(pagingViewController)
                self.view.addSubview(pagingViewController.view)
                pagingViewController.didMove(toParentViewController: self)
                pagingViewController.view.translatesAutoresizingMaskIntoConstraints = false
                
                let width = self.view.frame.width / CGFloat(self.viewControllers.count)
                pagingViewController.menuItemSize = PagingMenuItemSize.fixed(width: width, height: 5)
                
                pagingViewController.indicatorOptions = .visible(height: 4, zIndex: Int.max, spacing: .zero, insets: .zero)
                
                NSLayoutConstraint.activate([
                    pagingViewController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                    pagingViewController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                    pagingViewController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                    pagingViewController.view.topAnchor.constraint(equalTo: self.view.topAnchor)
                    ])
                
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.stopAnimating()
            }
        }
        
        operation.recordFetchedBlock = { record in
            let assets = record["pictureAssets"] as! [CKAsset]
            for asset in assets {
                let vc = self.storyboard?.instantiateViewController(withIdentifier: "PicturesVC") as! PicturesVC
                vc.picture = asset.image()
                
                self.viewControllers.append(vc)
            }
                
        }
        
        database.add(operation)
    }
    
    
    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? ChatVC {
            destination.currentUser = selectedUser
        }
    }
    
}
