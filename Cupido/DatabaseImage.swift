//
//  DatabaseImage.swift
//  Cupido
//
//  Created by Kirill Yudin on 29.12.2021.
//

import Foundation
import UIKit

struct DatabaseImage {
    var image: UIImage
    var imageType: ImageType
    
    init(withImage _image: UIImage, imageType _type: ImageType) {
        image = _image.rotatedDownImage()
        imageType = _type
        
        print(image.imageOrientation.rawValue.description)
    }
}

extension DatabaseImage: Equatable {}

extension UIImage {
    func rotatedDownImage() -> UIImage {        
        switch self.imageOrientation {
        case .down:
            return self
        default:
            return UIImage(cgImage: self.cgImage!, scale: 1.0, orientation: .down)
        }
    }
}
