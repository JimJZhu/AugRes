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
    
    static func addTextGeometry(forNode node: SCNNode, withText text: String, height: Float, width: Float, fill: UIColor, stroke: UIColor, alpha: Float, fontSize: Float){
        // Configure the Title Label Node
        let frame = SKShapeNode(rect: CGRect(x: 0, y: 0, width: width.cgFloat, height: height.cgFloat), cornerRadius: 2)
        frame.fillColor = fill
        frame.strokeColor = stroke
        frame.lineWidth = 5
        frame.alpha = alpha.cgFloat
        let scene = SKScene(size: CGSize(width: width.cgFloat, height: height.cgFloat))
        scene.backgroundColor = UIColor.clear
        let label = SKLabelNode(text: text)
        label.fontSize = fontSize.cgFloat
        label.fontName = "Futura"
        label.position = CGPoint(x:width.cgFloat/2, y: (height.cgFloat - fontSize.cgFloat)/2)
        label.lineBreakMode = NSLineBreakMode.byWordWrapping
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = width.cgFloat * 0.8
        scene.addChild(frame)
        scene.addChild(label)
        
        let plane = SCNPlane(width: CGFloat(width/ARHelperFunctions.resolutionFactor), height: CGFloat(height/ARHelperFunctions.resolutionFactor))
        let (minBound, maxBound) = plane.boundingBox
        let material = SCNMaterial()
        material.isDoubleSided = true
        material.diffuse.contents = scene
        material.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
        material.roughness.contents = UIColor.black
        
        plane.materials = [material]
        node.geometry = plane
        node.pivot = SCNMatrix4MakeTranslation((maxBound.x - minBound.x)/2, minBound.y, 0)
    }
}
