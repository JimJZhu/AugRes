//
//  Menu.swift
//  ARCloudAnchors
//
//  Created by Jim on 2018-06-08.
//  Copyright © 2018 Jim. All rights reserved.
//

import Foundation
import ARKit
enum MarkerStatus {
    case Available
    case Unavailable
}
class Marker: ClickableNode, Codable{
    var id: String
    var status: MarkerStatus {
        didSet {
            switch status {
            case .Available:
                self.geometry?.materials.first?.diffuse.contents = UIColor.green
            case .Unavailable:
                self.geometry?.materials.first?.diffuse.contents = UIColor.red
            }
        }
    }
    private var width = 500
    private var height = 500
    
    //MARK: - Init
    init(id: String){
        self.id = id
        self.status = .Available
        super.init()
        render()
        self.clickAction = {
            if self.status == .Available {
                self.status = .Unavailable
            } else {
                self.status = .Available
            }
        }
        self.name = "marker"
    }
    
    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        self.init(id: id)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func render(){
        let pyramid = SCNPyramid(width:0.3, height:0.5, length:0.3)
//        let (minBound, maxBound) = pyramid.boundingBox
        let material = SCNMaterial()
        material.isDoubleSided = true
        material.diffuse.contents = UIColor.green
        material.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
        material.roughness.contents = UIColor.black
        
        pyramid.materials = [material]
        self.geometry = pyramid
//        self.pivot = SCNMatrix4MakeTranslation((maxBound.x - minBound.x)/2, minBound.y, 0)
    }
    private enum CodingKeys:String,CodingKey {
        case id
    }
}
