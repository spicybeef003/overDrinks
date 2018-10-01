//
//  FilterOptionsTVC.swift
//  QuickChat
//
//  Created by Tony Jiang on 9/11/18.
//  Copyright © 2018 Mexonis. All rights reserved.
//

import UIKit

protocol FilterOptionsTVCDelegate: class {
    func filterChanged(newFilters: [Bool])
}

class FilterOptionsTVC: UITableViewController {
    let filterChoices: [String] = ["Men", "Women", "Non-binary", "People who want a drink", "People who want to buy me a drink"]
    
    var filters: [Bool] = []
    
    var delegate: FilterOptionsTVCDelegate?


    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.frame.size.width = self.view.frame.width * 0.6
        
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController!.navigationBar.shadowImage = UIImage()
        self.navigationController!.navigationBar.isTranslucent = false
        self.navigationController!.navigationBar.backgroundColor = .white
        
        tableView.tableFooterView = UIView(frame: .zero)
        
        filters = defaults.array(forKey: "filters") as! [Bool]
    }
    
    
    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        //self.delegate?.filterChanged(newFilters: self.filters)
        self.dismiss(animated: true, completion: nil)
    }
    

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "I am looking for:"
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont(name: "AvenirNext-Bold", size: 16)!
        header.textLabel?.textColor = .black
        header.backgroundColor = .lightGray
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filterChoices.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.separatorInset = .zero
        
        cell.textLabel?.text = filterChoices[indexPath.row]
        cell.textLabel?.font = UIFont(name: "AvenirNext-Regular", size: 16)!

        cell.accessoryType = filters[indexPath.row] ? .checkmark : .none
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        filters[indexPath.row] = !filters[indexPath.row]
        defaults.set(filters, forKey: "filters")
        delegate?.filterChanged(newFilters: filters)
        tableView.reloadData()
    }
}
