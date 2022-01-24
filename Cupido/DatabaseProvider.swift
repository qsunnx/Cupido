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
    private var localDocumentsDirectory: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    private (set) var triggerImage: UIImage?
    private (set) var mediaImages: [UIImage]?
    
    init() {
        databaseRef = Database.database().reference()
    }
    
    func writeUser(name: String, surname: String, email: String, phone: String, uid: String, completion: @escaping () -> Void) {
        // MARK: переделать регистрацию
        //        DispatchQueue.global(qos: .userInitiated).async {
        //            let newUser = self.databaseRef.child(uid)
        //            newUser.setValue(["name" : name,
        //                              "surname" : surname,
        //                              "email" : email,
        //                              "phone" : phone])
        //            completion()
        //        }
    }
    
    func getDatabaseImages(uid: String) async throws  -> [DatabaseImage] {
        let localImages = await getLocalImages(uid: uid)
        
        guard localImages.isEmpty else { return localImages }
        
        return try await withThrowingTaskGroup(of: [DatabaseImage].self, returning: [DatabaseImage].self) { group in
            group.addTask(priority: .userInitiated) {
                return try await dowloadImagesToLocalSystem(uid: uid, imagesType: .trigger)
                    .compactMap( { UIImage(fromURL: $0) } )
                    .map({ DatabaseImage(image: $0, imageType: .trigger) })
            }
            group.addTask(priority: .userInitiated) {
                return try await dowloadImagesToLocalSystem(uid: uid, imagesType: .media)
                    .compactMap( { UIImage(fromURL: $0) })
                    .map({ DatabaseImage(image: $0, imageType: .media) })
            }
            
            var result = [DatabaseImage]()
            
            for try await childResult in group {
                result.append(contentsOf: childResult)
            }
            
            return result
        }
    }
    
    private func getLocalImages(uid: String) async -> [DatabaseImage] {
        var localImages = [DatabaseImage]()
        
        async let localTriggerImages = getLocalImagesURL(uid: uid, imagesType: .trigger)
            .compactMap({ UIImage(fromURL: $0) })
            .map({ DatabaseImage(image: $0, imageType: .trigger) })
        async let localMediaImages   = getLocalImagesURL(uid: uid, imagesType: .media)
            .compactMap({ UIImage(fromURL: $0) })
            .map({ DatabaseImage(image: $0, imageType: .media) })
        
        await localImages.append(contentsOf: localTriggerImages)
        await localImages.append(contentsOf: localMediaImages)
        
        return localImages
    }
    
    
    private func getLocalImagesURL(uid: String, imagesType: ImageType) -> [URL] {
        var localImages = [URL]()
        
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return localImages }
        guard let contentDir = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: []) else { return localImages }
        localImages.append(contentsOf:contentDir.filter{ $0.lastPathComponent == uid + (imagesType == .trigger ? "_trigger" : "_media") } )
        
        return localImages
    }
    
    private func dowloadImagesToLocalSystem(uid: String, imagesType: ImageType) async throws-> [URL] {
        guard let dir = localDocumentsDirectory else { throw DownloadError.documentDirectoryNotFound }
        
        let storage = Storage.storage()
        let userRef = storage.reference().child(uid);
        var photoRef = [StorageReference]()
        
        if imagesType == .trigger {
            photoRef.append(userRef.child("triggerImage.jpg"))
        } else {
            let userFiles = try await userRef.child("User").listAll()
            photoRef.append(contentsOf: userFiles.items)
        }
        
        var localURLs = [URL]()
        
        for currentRef in photoRef {
            let fileURL = dir.appendingPathComponent(uid + (imagesType == .trigger ? "_trigger" : "_media"))
            currentRef.write(toFile: fileURL) { url, error in
                guard let url = url else { return }
                localURLs.append(url)
            }
        }
        
        return localURLs
    }
}

enum DownloadError: Error {
    case documentDirectoryNotFound
}

extension UIImage {
    convenience init?(fromURL url: URL) {
        var data: Data
        
        do {
            try data = Data(contentsOf: url)
        } catch {
            return nil
        }
        
        self.init(data: data)
    }
}
