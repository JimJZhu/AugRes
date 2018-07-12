//
//  ARHelperFunctions.swift
//  BookMyRoom
//
//  Created by Jim on 2018-07-12.
//  Copyright © 2018 Jim. All rights reserved.
//

import Foundation
import ARKit

class ARHelperFunctions {
    static let moveForward = SCNAction.moveBy(x: 0, y: 0, z: 0.01, duration: 0.15)
    static let moveBack = SCNAction.moveBy(x: 0, y: 0, z: -0.01, duration: 0.15)
    
    static func clickAction(node: SCNNode) {
        let move = SCNAction.sequence([moveForward, moveBack])
        let repeatTwice = SCNAction.repeat(move, count: 1)
        node.runAction(repeatTwice)
    }
    
    static func flashAction(node: SCNNode){
        // get its material
        if let material = node.geometry?.firstMaterial {
            
            // highlight it
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.2
            let oldColor = material.emission.contents
            // on completion - unhighlight
            SCNTransaction.completionBlock = {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.2
                
                material.emission.contents = oldColor
                
                SCNTransaction.commit()
            }
            
            material.emission.contents = UIColor.red
            
            SCNTransaction.commit()
        } else {
            print("Flash failed. Material not found. Skipping.")
        }
    }
}
