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
//        if _type == .media { image = image.imageWithSize(newSize: ImageProperties.Size()) }
        imageType = _type
    }
}

extension UIImage {
    func rotatedDownImage() -> UIImage {        
        switch self.imageOrientation {
        case .down:
            return self
        default:
            return UIImage(cgImage: self.cgImage!, scale: 1.0, orientation: .down)
        }
    }
    
    func imageWithSize(newSize: CGSize) -> UIImage {
        let image = UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return image.withRenderingMode(renderingMode)
    }
}
