//
//  MarkerManager.swift
//  AugRes
//
//  Created by Jim on 2018-07-12.
//  Copyright © 2018 Jim. All rights reserved.
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
  private var markerIDs: [String] = []
  var markerNodes: [Marker] = []
  
  public var markersDrawn: Bool! = false

  
  init(scene: SCNScene, view: SCNView) {
    scnScene = scene
    scnView = view
  }
  
  func getMarkerArray() -> [[String: [String: String]]] {
    var markerArray: [[String: [String: String]]] = []
    if (markerPositions.count > 0) {
      for i in 0...(markerPositions.count-1) {
        markerArray.append(["shape": ["id": "\(markerIDs[i])", "x": "\(markerPositions[i].x)",  "y": "\(markerPositions[i].y)",  "z": "\(markerPositions[i].z)" ]])
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
        let id: String = item["shape"]!["id"]!
        let marker = Marker(id: id)
        marker.position = position
        markerPositions.append(position)
        markerIDs.append(id)
        markerNodes.append(marker)
        
        print ("Shape Manager: Retrieved " + String(describing: id) + " id at position" + String (describing: position))
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
      node.geometry?.firstMaterial?.normal.contents = nil
      node.geometry?.firstMaterial?.diffuse.contents = nil
    }
    markerNodes.removeAll()
    markerPositions.removeAll()
    markerIDs.removeAll()
  }
  
  func placeMarker (position: SCNVector3) {
    
    let geometryNode: Marker = Marker(id: "1")
    geometryNode.position = position
    
    markerPositions.append(position)
    markerIDs.append(geometryNode.id)
    markerNodes.append(geometryNode)
    
    scnScene.rootNode.addChildNode(geometryNode)
    markersDrawn = true
  }
}
