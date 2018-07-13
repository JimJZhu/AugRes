//
//  OfficeSelectViewController.swift
//  AugRes
//
//  Created by Jim on 2018-07-12.
//  Copyright © 2018 Jim. All rights reserved.
//

import UIKit
import PlacenoteSDK
import CoreLocation
import BluemixAppID

class OfficeSelectViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate {
    
    var accessToken:AccessToken?
    var idToken:IdentityToken?

    @IBOutlet weak var mapTable: UITableView!
    
    // Map list
    private var maps: [(String, LibPlacenote.MapMetadata)] = [("Loading...", LibPlacenote.MapMetadata())]

    // Location Variables
    private var locationManager: CLLocationManager!
    private var lastLocation: CLLocation? = nil
    
    private var isFetching = false
    private var userData: [String:Any]?
    private var mapID: String?
    override func viewDidLoad() {
        super.viewDidLoad()

        //Initialize tableview for the list of maps
        mapTable.delegate = self
        mapTable.dataSource = self
        mapTable.allowsSelection = true
        mapTable.isUserInteractionEnabled = true
        mapTable.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        //UI Updates
        locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self;
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
            locationManager.startUpdatingLocation()
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        DispatchQueue.global(qos: .background).async{
            while !LibPlacenote.instance.initialized() {}
            DispatchQueue.main.async {
                self.updateMapTable()
            }
        }
    }
    func onMapList(success: Bool, mapList: [String: LibPlacenote.MapMetadata]) -> Void {
        
        maps.removeAll()
        if (!success) {
            print ("failed to fetch map list")
            return
        }
        
        print ("map List received")
        for place in mapList {
            maps.append((place.key, place.value))
            print ("place:" + place.key + ", metadata: ")
            print (place.value)
        }
        print("MAPS:\(maps)")
        self.mapTable.reloadData() //reads from maps array (see: tableView functions)
    }
    
    // MARK: - UITableViewDelegate and UITableviewDataSource to manage retrieving, viewing, deleting and selecting maps on a TableView
    
    //Return count of maps
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print(String(format: "Map size: %d", maps.count))
        return maps.count
    }
    
    //Label Map rows
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let map = self.maps[indexPath.row]
        var cell:UITableViewCell? = mapTable.dequeueReusableCell(withIdentifier: map.0)
        if cell==nil {
            cell = UITableViewCell(style: UITableViewCellStyle.subtitle, reuseIdentifier: map.0)
        }
        cell?.textLabel?.text = map.0
        
        let name = map.1.name
        if name != nil && !name!.isEmpty {
            cell?.textLabel?.text = name
        }
        
        var subtitle = "Distance Unknown"
        
        let location = map.1.location
        
        if (lastLocation == nil) {
            subtitle = "User location unknown"
        } else if (location == nil) {
            subtitle = "Map location unknown"
        } else {
            let distance = lastLocation!.distance(from: CLLocation(
                latitude: location!.latitude,
                longitude: location!.longitude))
            subtitle = String(format: "Distance: %0.3fkm", distance / 1000)
        }
        
        cell?.detailTextLabel?.text = subtitle
        print("MAP!\(map.1)")
        return cell!
    }
    
    //Map selected
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(String(format: "Retrieving row: %d", indexPath.row))
        print("Retrieving mapId: " + maps[indexPath.row].0)
        self.userData = self.maps[indexPath.row].1.userdata as? [String:Any]
        self.mapID = self.maps[indexPath.row].0
        self.performSegue(withIdentifier: "user", sender: nil)
    }
    
    //Make rows editable for deletion
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    //Delete Row and its corresponding map
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            LibPlacenote.instance.deleteMap(mapId: maps[indexPath.row].0, deletedCb: {(deleted: Bool) -> Void in
                if (deleted) {
                    print("Deleting: " + self.maps[indexPath.row].0)
                    self.maps.remove(at: indexPath.row)
                    self.mapTable.reloadData()
                }
                else {
                    print ("Can't Delete: " + self.maps[indexPath.row].0)
                }
            })
        }
    }
    
    func updateMapTable() {
        print("updateMapTable")
        LibPlacenote.instance.fetchMapList(listCb: onMapList)
    }
    
    func updateMapTable(radius: Float) {
        LibPlacenote.instance.searchMaps(latitude: self.lastLocation!.coordinate.latitude, longitude: self.lastLocation!.coordinate.longitude, radius: Double(radius), listCb: onMapList)
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Switches destination depending on which button was clicked
        if segue.identifier != nil {
            if let destinationVC = segue.destination.contents as? AfterLoginViewController {
                destinationVC.maps = maps
                destinationVC.locationManager = locationManager
                destinationVC.userData = userData
                destinationVC.mapID = mapID
            }else if let destinationVC = segue.destination.contents as? AdminViewController {
                destinationVC.maps = maps
                destinationVC.locationManager = locationManager
            }else{
                print("Bad Segue!")
            }
        }
    }

}
