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
        image = _image
        imageType = _type
    }
}

extension DatabaseImage: Equatable {}
