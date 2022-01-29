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
        
        guard localImages.isEmpty || !localImages.contains(where: {$0.imageType == .trigger}) || !localImages.contains(where: {$0.imageType == .media})
        else { return localImages }
        
        return try await withThrowingTaskGroup(of: [DatabaseImage].self, returning: [DatabaseImage].self) { group in
            group.addTask(priority: .userInitiated) {
                let downloadedResult =  try await dowloadImagesToLocalSystem(uid: uid, imagesType: .trigger)
                let mappedResult = downloadedResult.compactMap( { UIImage(fromURL: $0) } )
                let mappedResult1 =  mappedResult.map({ DatabaseImage(withImage: $0, imageType: .trigger) })
                
                return mappedResult1
            }
            group.addTask(priority: .userInitiated) {
                let downloadedResult =  try await dowloadImagesToLocalSystem(uid: uid, imagesType: .media)
                let mappedResult = downloadedResult.compactMap( { UIImage(fromURL: $0) } )
                let mappedResult1 =  mappedResult.map({ DatabaseImage(withImage: $0, imageType: .media) })
                
                return mappedResult1
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
            .map({ DatabaseImage(withImage: $0, imageType: .trigger) })
        async let localMediaImages   = getLocalImagesURL(uid: uid, imagesType: .media)
            .compactMap({ UIImage(fromURL: $0) })
            .map({ DatabaseImage(withImage: $0, imageType: .media) })
        
        await localImages.append(contentsOf: localTriggerImages)
        await localImages.append(contentsOf: localMediaImages)
        
        return localImages
    }
    
    
    private func getLocalImagesURL(uid: String, imagesType: ImageType) -> [URL] {
        var localImages = [URL]()
        
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return localImages }
        guard let contentDir = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: []) else { return localImages }
        localImages.append(contentsOf:contentDir.filter{
            $0.lastPathComponent.hasPrefix( imagesType == .trigger ? "trigger_" : "media_" )
        } )
        
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
        
        // TODO: для параллельности здесь сделать таск!
        for currentRef in photoRef {
            let fileURL = dir.appendingPathComponent((imagesType == .trigger ? "trigger_" : "media_") + currentRef.name)
            let currentLocalFile = try await currentRef.writeAsync(toFile: fileURL)
            
            if currentLocalFile != nil { localURLs.append(currentLocalFile!) }
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


extension StorageReference {
    func writeAsync(toFile fileURL: URL) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            write(toFile: fileURL) { url, error in
                if error != nil { continuation.resume(throwing: error!) }
                continuation.resume(returning: url)
            }
        }
    }
}
