//
//  Extensions.swift
//  AugRes
//
//  Created by Jim on 2018-07-12.
//  Copyright © 2018 Jim. All rights reserved.
//

import Foundation
import ARKit

extension Float {
    var cgFloat: CGFloat {
        return CGFloat(self)
    }
}

extension UIViewController{
    // Helps unwrap the nav controller
    var contents: UIViewController{
        if let navcon = self as? UINavigationController {
            return navcon.visibleViewController ?? self
        } else {
            return self
        }
    }
}
