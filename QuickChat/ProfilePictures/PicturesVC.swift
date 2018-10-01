//
//  PicturesVC.swift
//  QuickChat
//
//  Created by Tony Jiang on 9/9/18.
//  Copyright © 2018 Mexonis. All rights reserved.
//

import UIKit

class PicturesVC: UIViewController {

    @IBOutlet weak var pictureImageView: UIImageView!
    var picture: UIImage!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        pictureImageView.image = picture
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
