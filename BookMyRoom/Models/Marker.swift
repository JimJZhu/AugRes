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
    var status: MarkerStatus
    
    //MARK: - Init
    init(id: String){
        self.id = id
        self.status = .Unavailable
        super.init()
        render()
        
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
    
    private enum CodingKeys:String,CodingKey {
        case id
    }
}
