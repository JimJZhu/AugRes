//
//  ClickableNode.swift
//  AugRes
//
//  Created by Jim on 2018-06-11.
//  Copyright © 2018 Jim. All rights reserved.
//

import Foundation
import ARKit

class ClickableNode: SCNNode {
    var clickAction: (()-> Void)?
    
    func click(){
        ARHelperFunctions.clickAction(node: self)
        ARHelperFunctions.flashAction(node: self)
        clickAction?()
    }
    
    func render(){
        fatalError("Render function must be implemented!")
    }
}
