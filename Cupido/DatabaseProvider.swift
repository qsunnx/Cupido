//
//  DatabaseProvider.swift
//  Cupido
//
//  Created by Kirill Yudin on 06.09.2021.
//

import Foundation
import Firebase


struct DatabaseProvider {
    private var databaseRef: DatabaseReference!
    private let dispatchQueue = DispatchQueue(label: "database.queue", qos: .userInteractive)
    
    init() {
        databaseRef = Database.database().reference()
    }
    
    func writeUser(name: String, surname: String, email: String, phone: String, uid: String, completion: @escaping () -> Void) {
        dispatchQueue.async {
            let newUser = self.databaseRef.child(uid)
            newUser.setValue(["name" : name,
                              "surname" : surname,
                              "email" : email,
                              "phone" : phone])
            completion()
        }
    }
}
