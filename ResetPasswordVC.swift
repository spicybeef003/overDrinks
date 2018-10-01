//
//  ResetPasswordVC.swift
//  QuickChat
//
//  Created by Tony Jiang on 9/13/18.
//  Copyright © 2018 Mexonis. All rights reserved.
//

import UIKit
import Firebase

class ResetPasswordVC: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var errorMessage: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        errorMessage.isHidden = true
        
        emailTextField.delegate = self
    }

    @IBAction func resetPressed(_ sender: RoundedButton) {
        emailTextField.resignFirstResponder()
        
        if let email = emailTextField.text {
            if isValidEmail(testStr: email) {
                Auth.auth().sendPasswordReset(withEmail: email) { error in
                    if error == nil {
                        let myAlert = UIAlertController(title: "Reset email sent.", message: "Please check your email to reset your password.", preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "OK", style: .default, handler: { _ in
                            self.errorMessage.isHidden = true
                            self.dismiss(animated: true, completion: nil)
                            self.popoverPresentationController?.delegate?.popoverPresentationControllerDidDismissPopover?(self.popoverPresentationController!)
                        })
                        
                        myAlert.addAction(okAction)
                        self.present(myAlert, animated: true, completion: nil)
                    }
                    else {
                        print(error)
                        self.errorMessage.isHidden = false
                    }
                }
            }
            else {
                print("invalid email")
                self.errorMessage.isHidden = false
            }
        }
        
    }
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
        self.popoverPresentationController?.delegate?.popoverPresentationControllerDidDismissPopover?(self.popoverPresentationController!)
    }
    
    func isValidEmail(testStr: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        
        let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: testStr)
    }
    
    //MARK: Delegates
    func textFieldDidBeginEditing(_ textField: UITextField) {
        errorMessage.isHidden = true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}
