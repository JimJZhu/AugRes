//  ViewController.swift
//  ARMaps
//
//  Created by Tamer Sherif on 2018-07-12.
//  Copyright © 2018 Tamer Sherif. All rights reserved.
//

import UIKit
import GoogleMaps
import Foundation
import SwiftyJSON

//Define office struct that includes necessary information
struct Office {
    let long: Double
    let lat: Double
    let addr: String
    let city: String
}
class MapViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate {
    
    //intializaing necessary variables
    var locationManager = CLLocationManager()
    lazy var mapView = GMSMapView()
    var resultLong = [Double]()
    var resultLat = [Double]()
    var resultAddr = [String]()
    var resultCity = [String]()
    var resultArr = [Office]()
    
    
    override func viewDidLoad() {
        
        //setup map view
        super.viewDidLoad()
        let camera = GMSCameraPosition.camera(withLatitude: 43.6712937, longitude: -79.3850568, zoom: 15)
        mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.isMyLocationEnabled = true
        mapView.delegate = self
        self.view = mapView
        
        // User Location
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        
    }
    
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let userLocation = locations.last
        _ = CLLocationCoordinate2D(latitude: userLocation!.coordinate.latitude, longitude: userLocation!.coordinate.longitude)
        
        let camera = GMSCameraPosition.camera(withLatitude: userLocation!.coordinate.latitude,
                                              longitude: userLocation!.coordinate.longitude, zoom: 13.0)
        
        
        
        
        //Getting the the office info from cloudant
        func getOfficeArray() -> (){
            
            let headers = [
                "Content-Type": "application/json",
                "Authorization": "Basic b21pbnlvdXRlbnRlcmVuZWRvb21tZW50OjVhYjdkZGNhNzlmOGU3OTBjMzU4NjVkNzU0NzljYTAyMTQzYzY5YTg=",
                "Cache-Control": "no-cache"
                //"postman-token": "15f01b4f-a354-8445-122a-7d49a21971ee"
            ]
            
            let parameters = [
                "selector": ["_id": ["$gt": "0"]],
                "fields": ["_id", "latitude", "longitude","address","city"],
                "sort": [["_id": "asc"]]
                ] as [String : Any]
            
            let postData = try! JSONSerialization.data(withJSONObject: parameters, options: [])
            
            let request = NSMutableURLRequest(url: NSURL(string: "https://2c89fa35-6349-4b78-be94-e5c574feb79d-bluemix.cloudant.com/offices/_find")! as URL,
                                              cachePolicy: .useProtocolCachePolicy,
                                              timeoutInterval: 10.0)
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = headers
            request.httpBody = postData as Data
            
            var longArr = [Double]()
            var latArr = [Double]()
            var addrArr = [String]()
            var cityArr = [String]()
            
            
            let session = URLSession.shared
            let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
                if (error != nil) {
                    print(error!)
                } else {
                    
                    //let responseJson = try! JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: Any]
                    //let docs = responseJson!["docs"] as! [Array]
                    //print(docs[0])
                    
                    let jsonData = try! JSON(data: data!)
                    let officesArray = jsonData["docs"]
                    
                    let count = (officesArray.count)-1
                    
                    //append the values we received into our respective arrays
                    for i in 0...count {
                        longArr.append(officesArray[i]["longitude"].double!)
                        latArr.append(officesArray[i]["latitude"].double!)
                        cityArr.append(officesArray[i]["city"].string!)
                        addrArr.append(officesArray[i]["address"].string!)
                    }
                    
                    //saveArrays will now store the respective values into a type Office resultArray
                    saveArrays(longArr: longArr, latArr: latArr, cityArr: cityArr, addrArr: addrArr)
                }
                
            })
            
            dataTask.resume()
        }
        getOfficeArray()
        
        
        
        func saveArrays(longArr:Array<Double>, latArr:Array<Double>, cityArr:Array<String>, addrArr:Array<String>) -> (){
            
            resultLong = longArr
            resultLat = latArr
            resultCity = cityArr
            resultAddr = addrArr
            
            
            for i in 0...resultLong.count-1 {
                resultArr.append(Office(long: resultLong[i], lat: resultLat[i], addr: resultAddr[i], city: resultCity[i]))
            }
            
            //            print(resultArr)
            putMarkers(resultArr: resultArr)
        }
        
        
        //putMarkers will now set the markers up
        func putMarkers(resultArr:Array<Office>) -> (){
            DispatchQueue.main.async {
                for office in resultArr {
                    
                    let office_marker = GMSMarker()
                    office_marker.position = CLLocationCoordinate2D(latitude: office.lat, longitude: office.long)
                    office_marker.title = office.addr
                    office_marker.snippet = office.city
                    office_marker.map = self.mapView
                }
            }
            
        }
        
        //MARK: - GMS DELEGATE
        //        func mapView(_ mapView: GMSMapView, didTapMarker marker: GMSMarker) -> Bool {
        //
        //        }
        func mapView(mapView: GMSMapView, didTap: GMSMarker) -> Bool {
            print("tapp")
            let update = GMSCameraUpdate.zoom(by: 10)
            mapView.animate(with: update)
            return true
        }
    }
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}
extension ViewController: GMSMapViewDelegate {
    
}
