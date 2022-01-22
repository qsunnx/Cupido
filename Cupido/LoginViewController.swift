//
//  LoginViewController.swift
//  Cupido
//
//  Created by Kirill Yudin on 03.09.2021.
//

import UIKit
import Firebase

class LoginViewController: UIViewController {
    
    @IBOutlet weak var loginLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    @IBOutlet weak var loginButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        passwordTextField.delegate = self
        emailTextField.delegate.self
    }
    
    @IBAction func logInButtonPressed(_ sender: Any) {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            let alertController = UIAlertController(title: "Ошибка", message: "Необходимо заполнить поля логина и пароля", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "ОК", style: UIAlertAction.Style.default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            
            return
        }
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if error != nil {
                //TODO: обработка ошибки как в экране регистрации
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "showScanVC", sender: nil)
            }
        }
    }
    
    @IBAction func forgotPasswordButtonPressed(_ sender: Any) {
    }
}

extension LoginViewController: UITextFieldDelegate {
    
}

extension LoginViewController {
    var userPassword: String {
        return ""
    }
}
