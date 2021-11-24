//
//  DatabaseProvider.swift
//  Cupido
//
//  Created by Kirill Yudin on 06.09.2021.
//

import Foundation
import Firebase
import UIKit


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
    
    func downloadTriggerImage(uid: String, completion: @escaping (Result<URL?, Error>) -> Void) {
        //TODO: spinner
        //TODO: обработка если фотография уже загружена
        let storage = Storage.storage()
        let userRef = storage.reference().child(uid);
        let originalPhotoRef = userRef.child("User/triggerImage.jpg")
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(uid + "_trigger")
            let _ = originalPhotoRef.write(toFile: fileURL) {url, error in
                if error != nil { completion(.failure(error!)) }
                else { completion(.success(url)) }
            }
        }        
    }
}
