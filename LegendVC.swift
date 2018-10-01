//
//  LegendVC.swift
//  QuickChat
//
//  Created by Tony Jiang on 9/12/18.
//  Copyright © 2018 Mexonis. All rights reserved.
//

import UIKit

class LegendVC: UIViewController {
    @IBOutlet weak var legend: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController!.navigationBar.shadowImage = UIImage()
        self.navigationController!.navigationBar.isTranslucent = false
        self.navigationController!.navigationBar.backgroundColor = .white
    }

    
    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
