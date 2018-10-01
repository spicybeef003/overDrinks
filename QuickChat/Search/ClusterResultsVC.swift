//
//  ClusterResultsVC.swift
//  QuickChat
//
//  Created by Tony Jiang on 9/9/18.
//  Copyright © 2018 Mexonis. All rights reserved.
//

import UIKit

class ClusterResultsVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var profilePics: [UIImage]!
    var firebaseIDs: [String]!
    var names: [String]!
    var ages: [String]!
    var buys: [Bool]!
    var receives: [Bool]!
    
    var selectedIndexPath: IndexPath!

    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.tintColor = .white
        
        setupTableView()
    }
    
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.tableFooterView = UIView(frame: CGRect.zero)
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
 
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return firebaseIDs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell1", for: indexPath) as! ClusterResultsCell
        cell.separatorInset = .zero
        
        cell.profilePic.layer.cornerRadius = cell.profilePic.frame.height / 2
        cell.profilePic.layer.borderColor = UIColor.white.cgColor
        cell.profilePic.layer.borderWidth = 1.5
        
        User.info(forUserID: firebaseIDs[indexPath.row], completion: { user in
            DispatchQueue.main.async {
                cell.profilePic.image = user.profilePic
            }
        })
        
        cell.nameLabel.text = names[indexPath.row]
        
        cell.ageLabel.text = ages[indexPath.row]
        
        if buys[indexPath.row] && receives[indexPath.row] {
            cell.statusLabel.text = "Wants to buy or receive a drink"
            cell.backgroundColor = GlobalVariables.blue
        }
        else if buys[indexPath.row] {
            cell.statusLabel.text = "Wants to buy someone a drink"
            cell.backgroundColor = UIColor(red: 10/255, green: 93/255, blue: 0/255, alpha: 1)
        }
        else if receives[indexPath.row] {
            cell.statusLabel.text = "Wants to receive a drink"
            cell.backgroundColor = UIColor(red: 250/255, green: 128/255, blue: 114/255, alpha: 1)
        }
        
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        selectedIndexPath = indexPath
        
        self.performSegue(withIdentifier: "toPicturesFromSearch", sender: self)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
   
    // MARK: end tableview markup

    

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nc = segue.destination as? UINavigationController {
            if let destination = nc.topViewController as? CustomTabVC {
                destination.firebaseID = firebaseIDs[selectedIndexPath.row]
            }
        }
    }

}

class ClusterResultsCell: UITableViewCell {
    @IBOutlet weak var ageLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var profilePic: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
}
