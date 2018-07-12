//
//  ShapeManager.swift
//  Shape Dropper (Placenote SDK iOS Sample)
//
//  Created by Prasenjit Mukherjee on 2017-10-20.
//  Copyright © 2017 Vertical AI. All rights reserved.
//

import Foundation
import SceneKit

extension String {
  func appendLineToURL(fileURL: URL) throws {
    try (self + "\n").appendToURL(fileURL: fileURL)
  }
  
  func appendToURL(fileURL: URL) throws {
    let data = self.data(using: String.Encoding.utf8)!
    try data.append(fileURL: fileURL)
  }
}


extension Data {
  func append(fileURL: URL) throws {
    if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
      defer {
        fileHandle.closeFile()
      }
      fileHandle.seekToEndOfFile()
      fileHandle.write(self)
    }
    else {
      try write(to: fileURL, options: .atomic)
    }
  }
}

func generateRandomColor() -> UIColor {
  let hue : CGFloat = CGFloat(arc4random() % 256) / 256 // use 256 to get full range from 0.0 to 1.0
  let saturation : CGFloat = CGFloat(arc4random() % 128) / 256 + 0.3 // from 0.3 to 1.0 to stay away from white
  let brightness : CGFloat = CGFloat(arc4random() % 128) / 256 + 0.3 // from 0.3 to 1.0 to stay away from black
  
  return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
}


//Class to manage a list of shapes to be view in Augmented Reality including spawning, managing a list and saving/retrieving from persistent memory using JSON
class MarkerManager {
  
  private var scnScene: SCNScene!
  private var scnView: SCNView!
  
  private var markerPositions: [SCNVector3] = []
  private var markerTypes: [ShapeType] = []
  private var markerNodes: [SCNNode] = []
  
  public var markersDrawn: Bool! = false

  
  init(scene: SCNScene, view: SCNView) {
    scnScene = scene
    scnView = view
  }
  
  func getMarkerArray() -> [[String: [String: String]]] {
    var markerArray: [[String: [String: String]]] = []
    if (markerPositions.count > 0) {
      for i in 0...(markerPositions.count-1) {
        markerArray.append(["shape": ["style": "\(markerTypes[i].rawValue)", "x": "\(markerPositions[i].x)",  "y": "\(markerPositions[i].y)",  "z": "\(markerPositions[i].z)" ]])
      }
    }
    return markerArray
  }

  // Load shape array
  func loadMarkerArray(markerArray: [[String: [String: String]]]?) -> Bool {
    clearMarkers() //clear currently viewing shapes and delete any record of them.

    if (markerArray == nil) {
        print ("Shape Manager: No shapes for this map")
        return false
    }

    for item in markerArray! {
      let x_string: String = item["shape"]!["x"]!
      let y_string: String = item["shape"]!["y"]!
      let z_string: String = item["shape"]!["z"]!
      let position: SCNVector3 = SCNVector3(x: Float(x_string)!, y: Float(y_string)!, z: Float(z_string)!)
      let type: ShapeType = ShapeType(rawValue: Int(item["shape"]!["style"]!)!)!
      markerPositions.append(position)
      markerTypes.append(type)
      markerNodes.append(createShape(position: position, type: type))

      print ("Shape Manager: Retrieved " + String(describing: type) + " type at position" + String (describing: position))
    }

    print ("Shape Manager: retrieved " + String(markerPositions.count) + " shapes")
    return true
  }

  func clearView() { //clear shapes from view
    for marker in markerNodes {
      marker.removeFromParentNode()
    }
    markersDrawn = false
  }
  
  func drawView(parent: SCNNode) {
    guard !markersDrawn else {return}
    for marker in markerNodes {
      parent.addChildNode(marker)
    }
    markersDrawn = true
  }
  
  func clearMarkers() { //delete all nodes and record of all shapes
    clearView()
    for node in markerNodes {
      node.geometry!.firstMaterial!.normal.contents = nil
      node.geometry!.firstMaterial!.diffuse.contents = nil
    }
    markerNodes.removeAll()
    markerPositions.removeAll()
    markerTypes.removeAll()
  }
  
  
  
  func spawnRandomMarker(position: SCNVector3) {
    
    let shapeType: ShapeType = ShapeType.random()
    placeMarker(position: position, type: shapeType)
  }
  
  func placeMarker (position: SCNVector3, type: ShapeType) {
    
    let geometryNode: SCNNode = createShape(position: position, type: type)
    
    markerPositions.append(position)
    markerTypes.append(type)
    markerNodes.append(geometryNode)
    
    scnScene.rootNode.addChildNode(geometryNode)
    markersDrawn = true
  }
  
  func createShape (position: SCNVector3, type: ShapeType) -> SCNNode {
    
    let geometry:SCNGeometry = ShapeType.generateGeometry(s_type: type)
    let color = generateRandomColor()
    geometry.materials.first?.diffuse.contents = color
    
    let geometryNode = SCNNode(geometry: geometry)
    geometryNode.position = position
    geometryNode.scale = SCNVector3(x:0.1, y:0.1, z:0.1)
    
    return geometryNode
  }
  
  
}
