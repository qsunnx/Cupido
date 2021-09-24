//
//  SignUpViewController.swift
//  Cupido
//
//  Created by Kirill Yudin on 03.09.2021.
//

import UIKit
import Firebase

class SignUpViewController: UIViewController {

    @IBOutlet private weak var signUpLabel: UILabel!
    @IBOutlet private weak var firstNameTextField: UITextField!
    @IBOutlet private weak var secondNameTextField: UITextField!
    @IBOutlet private weak var emailTextField: UITextField!
    @IBOutlet private weak var phoneTextField: UITextField!
    @IBOutlet private weak var passwordTextField: UITextField!
    @IBOutlet private weak var createAccountButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func createAccountButtonPressed(_ sender: Any) {
        guard let firstName = firstNameTextField.text, let email = emailTextField.text, let password = passwordTextField.text else {
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if error != nil {
                if let errorCode = AuthErrorCode.init(rawValue: error!._code) {
                    var message  = "";
                    switch errorCode {
                    case .invalidEmail: message = "Некорректный email"
                    case .emailAlreadyInUse: message = "Учетная запись электронной почты уже используется"
                        // Call fetchProvidersForEmail to check which sign-in mechanisms the user used, and prompt the user to sign in with one of those.
                    case .operationNotAllowed: message = "Операция не разрешена"
                    case .weakPassword: message = "Слишком слабый пароль"
                    default: message = "Неизвестная ошибка"
                    }
                    
                    DispatchQueue.main.async { [weak self] in
                        let alert = UIAlertController(title: "Ошибка регистрации", message: message, preferredStyle: UIAlertController.Style.alert)
                        alert.addAction(UIAlertAction(title: "ОК", style: UIAlertAction.Style.default, handler: nil))
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
                
                return
            }
            
            let databaseProvider = DatabaseProvider()
            databaseProvider.writeUser(name: firstName, surname: self.secondNameTextField.text ?? "", email: email, phone: self.phoneTextField.text ?? "", uid: authResult?.user.uid ?? "") {
                DispatchQueue.main.async { [weak self] in
                    //self?.performSegue(withIdentifier: "showScanVC", sender: nil)
                }
            }
        }
    }
    
}
