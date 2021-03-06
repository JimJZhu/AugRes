//
//  AdminViewController.swift
//  AugRes
//
//  Created by Jim on 2018-07-12.
//  Copyright © 2018 Jim. All rights reserved.
//
import UIKit
import SceneKit
import ARKit
import CoreLocation
import PlacenoteSDK

class AdminViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, UITableViewDelegate, UITableViewDataSource, PNDelegate, CLLocationManagerDelegate {
    
    
    //UI Elements
    @IBOutlet var scnView: ARSCNView!
    
    //UI Elements for the map table
    
    @IBOutlet var mapTable: UITableView!
    @IBOutlet var filterLabel2: UILabel!
    @IBOutlet var filterLabel1: UILabel!
    @IBOutlet var filterSlider: UISlider!
    
    
    @IBOutlet var newMapButton: UIButton!
    @IBOutlet var pickMapButton: UIButton!
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var showPNLabel: UILabel!
    @IBOutlet var showPNSelection: UISwitch!
    @IBOutlet var planeDetLabel: UILabel!
    @IBOutlet var planeDetSelection: UISwitch!
    @IBOutlet var fileTransferLabel: UILabel!
    @IBOutlet weak var addMarkerButton: UIButton!
    
    //AR Scene
    private var scnScene: SCNScene!
    
    //Status variables to track the state of the app with respect to libPlacenote
    private var trackingStarted: Bool = false;
    private var mappingStarted: Bool = false;
    private var mappingComplete: Bool = false;
    private var localizationStarted: Bool = false;
    private var reportDebug: Bool = false
    private var maxRadiusSearch: Float = 500.0 //m
    private var currRadiusSearch: Float = 0.0 //m
    
    
    //Application related variables
    private var shapeManager: MarkerManager!
    private var tapRecognizer: UITapGestureRecognizer? = nil //initialized after view is loaded
    
    
    //Variables to manage PlacenoteSDK features and helpers
    var maps: [(String, LibPlacenote.MapMetadata)] = [("Loading...", LibPlacenote.MapMetadata())]
    private var camManager: CameraManager? = nil;
    private var ptViz: FeaturePointVisualizer? = nil;
    private var planesVizAnchors = [ARAnchor]();
    private var planesVizNodes = [UUID: SCNNode]();
    
    private var showFeatures: Bool = true
    private var planeDetection: Bool = false
    
    var locationManager: CLLocationManager!
    private var lastLocation: CLLocation? = nil
    
    private var screenCenter: CGPoint {
        let bounds = scnView.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
        
    //Setup view once loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupScene()
        
        //App Related initializations
        shapeManager = MarkerManager(scene: scnScene, view: scnView)
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapRecognizer!.numberOfTapsRequired = 1
        tapRecognizer!.isEnabled = false
        scnView.addGestureRecognizer(tapRecognizer!)
        
        //IMPORTANT: need to run this line to subscribe to pose and status events
        //Declare yourself to be one of the delegates of PNDelegate to receive pose and status updates
        LibPlacenote.instance.multiDelegate += self;
        
        //Initialize tableview for the list of maps
        mapTable.delegate = self
        mapTable.dataSource = self
        mapTable.allowsSelection = true
        mapTable.isUserInteractionEnabled = true
        mapTable.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        //UI Updates
        newMapButton.isEnabled = false
        toggleMappingUI(true) //hide mapping UI options
        locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self;
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
            locationManager.startUpdatingLocation()
        }
    }
    
    //Initialize view and scene
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureSession();
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        scnView.session.pause()
    }
    
    //Function to setup the view and setup the AR Scene including options
    func setupView() {
        scnView = self.view as! ARSCNView
        scnView.showsStatistics = true
        scnView.autoenablesDefaultLighting = true
        scnView.delegate = self
        scnView.session.delegate = self
        scnView.isPlaying = true
        scnView.debugOptions = []
        mapTable.isHidden = true //hide the map list until 'Load Map' is clicked
        filterSlider.isContinuous = false
        toggleSliderUI(true, reset: true) //hide the radius search UI, reset values as we are initializating
        //scnView.debugOptions = ARSCNDebugOptions.showFeaturePoints
        //scnView.debugOptions = ARSCNDebugOptions.showWorldOrigin
    }
    
    //Function to setup AR Scene
    func setupScene() {
        scnScene = SCNScene()
        scnView.scene = scnScene
        ptViz = FeaturePointVisualizer(inputScene: scnScene);
        ptViz?.enableFeaturePoints()
        
        if let camera: SCNNode = scnView?.pointOfView {
            camManager = CameraManager(scene: scnScene, cam: camera)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scnView.frame = view.bounds
    }
    
    
    // MARK: - PNDelegate functions
    
    //Receive a pose update when a new pose is calculated
    func onPose(_ outputPose: matrix_float4x4, _ arkitPose: matrix_float4x4) -> Void {
        
    }
    
    //Receive a status update when the status changes
    func onStatusChange(_ prevStatus: LibPlacenote.MappingStatus, _ currStatus: LibPlacenote.MappingStatus) {
        if prevStatus != LibPlacenote.MappingStatus.running && currStatus == LibPlacenote.MappingStatus.running { //just localized draw shapes you've retrieved
            print ("Just localized, drawing view")
            shapeManager.drawView(parent: scnScene.rootNode) //just localized redraw the shapes
            if mappingStarted {
                statusLabel.text = "Tap anywhere to add Shapes, Move Slowly"
            }
            else if localizationStarted {
                statusLabel.text = "Map Found!"
            }
            addMarkerButton?.isEnabled = true
            tapRecognizer?.isEnabled = true
            
            //As you are localized, the camera has been moved to match that of Placenote's Map. Transform the planes
            //currently being drawn from the arkit frame of reference to the Placenote map's frame of reference.
            for (_, node) in planesVizNodes {
                node.transform = LibPlacenote.instance.processPose(pose: node.transform);
            }
        }
        
        if prevStatus == LibPlacenote.MappingStatus.running && currStatus != LibPlacenote.MappingStatus.running { //just lost localization
            print ("Just lost")
            if mappingStarted {
                statusLabel.text = "Moved too fast. Map Lost"
            }
            addMarkerButton?.isEnabled = false
            tapRecognizer?.isEnabled = false
            
        }
        
    }
    
    //Receive list of maps after it is retrieved. This is only fired when fetchMapList is called (see updateMapTable())
    func onMapList(success: Bool, mapList: [String: LibPlacenote.MapMetadata]) -> Void {
        maps.removeAll()
        if (!success) {
            print ("failed to fetch map list")
            statusLabel.text = "Map List not retrieved"
            return
        }
        
        print ("map List received")
        for place in mapList {
            maps.append((place.key, place.value))
            print ("place:" + place.key + ", metadata: ")
            print (place.value)
        }
        
        statusLabel.text = "Map List"
        self.mapTable.reloadData() //reads from maps array (see: tableView functions)
        self.mapTable.isHidden = false
        self.toggleSliderUI(false, reset: false)
        self.addMarkerButton?.isEnabled = false
        tapRecognizer?.isEnabled = false
    }
    
    // MARK: - UI functions
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    @IBAction func newSaveMapButton(_ sender: Any) {
        if (trackingStarted && !mappingStarted) { //ARKit is enabled, start mapping
            print ("New Map")
            mappingStarted = true
            
            LibPlacenote.instance.stopSession()
            
            LibPlacenote.instance.startSession()
            
            if (reportDebug) {
                LibPlacenote.instance.startReportRecord(uploadProgressCb: {(completed: Bool, faulted: Bool, percentage: Float) -> Void in
                    if (completed) {
                        self.statusLabel.text = "Dataset Upload Complete"
                        self.fileTransferLabel.text = ""
                    } else if (faulted) {
                        self.statusLabel.text = "Dataset Upload Faulted"
                        self.fileTransferLabel.text = ""
                    } else {
                        self.fileTransferLabel.text = "Dataset Upload: " + String(format: "%.3f", percentage) + "/1.0"
                    }
                })
                print ("Started Debug Report")
            }
            
            localizationStarted = false
            pickMapButton.setTitle("Load Map", for: .normal)
            newMapButton.setTitle("Save Map", for: .normal)
            statusLabel.text = "Mapping: Tap to add shapes!"
            addMarkerButton?.isEnabled = true
            tapRecognizer?.isEnabled = true
            mapTable.isHidden = true
            toggleSliderUI(true, reset: false)
            toggleMappingUI(false)
            shapeManager.clearMarkers() //creating new map, remove old shapes.
        }
        else if (mappingStarted) { //mapping been running, save map
            print("Saving Map")
            statusLabel.text = "Saving Map"
            mappingStarted = false
            mappingComplete = true
            LibPlacenote.instance.saveMap(
                savedCb: {(mapId: String?) -> Void in
                    if (mapId != nil) {
                        self.statusLabel.text = "Saved Id: " + mapId! //update UI
                        LibPlacenote.instance.stopSession()
                        
                        let metadata = LibPlacenote.MapMetadataSettable()
//                        metadata.name = RandomName.Get()
                        metadata.name = "120 Bloor"
                        self.statusLabel.text = "Saved Map: " + metadata.name! //update UI
                        
                        if (self.lastLocation != nil) {
                            metadata.location = LibPlacenote.MapLocation()
                            metadata.location!.latitude = self.lastLocation!.coordinate.latitude
                            metadata.location!.longitude = self.lastLocation!.coordinate.longitude
                            metadata.location!.altitude = self.lastLocation!.altitude
                        }
                        var userdata: [String:Any] = [:]
                        userdata["markerArray"] = self.shapeManager.getMarkerArray()
                        metadata.userdata = userdata
                        
                        if (!LibPlacenote.instance.setMapMetadata(mapId: mapId!, metadata: metadata)) {
                            print ("Failed to set map metadata")
                        }
                        self.planeDetSelection.isOn = false
                        self.planeDetection = false
                        self.configureSession()
                    } else {
                        NSLog("Failed to save map")
                    }
            },
                uploadProgressCb: {(completed: Bool, faulted: Bool, percentage: Float) -> Void in
                    if (completed) {
                        print ("Uploaded!")
                        self.fileTransferLabel.text = ""
                    } else if (faulted) {
                        print ("Couldnt upload map")
                    } else {
                        print ("Progress: " + percentage.description)
                        self.fileTransferLabel.text = "Map Upload: " + String(format: "%.3f", percentage) + "/1.0"
                    }
            }
            )
            newMapButton.setTitle("New Map", for: .normal)
            addMarkerButton?.isEnabled = false
            tapRecognizer?.isEnabled = false
            toggleMappingUI(true) //hide mapping UI
        }
    }
    
    @IBAction func pickMap(_ sender: Any) {
        print("pick")
        if (localizationStarted) { // currently a map is loaded. StopSession and clearView
            shapeManager.clearMarkers()
            ptViz?.reset()
            LibPlacenote.instance.stopSession()
            localizationStarted = false
            pickMapButton.setTitle("Load Map", for: .normal)
            statusLabel.text = "Cleared"
            toggleMappingUI(true) //hided mapping options
            planeDetSelection.isOn = false
            planeDetection = false
            configureSession()
            return
        }
        
        if (mapTable.isHidden) { //fetch map list and show table of maps
            updateMapTable()
            pickMapButton.setTitle("Cancel", for: .normal)
            newMapButton.isEnabled = false
            statusLabel.text = "Fetching Map List"
            toggleSliderUI(true, reset: true)
        }
        else { //map load/localization session cancelled
            mapTable.isHidden = true
            toggleSliderUI(true, reset: false)
            pickMapButton.setTitle("Load Map", for: .normal)
            newMapButton.isEnabled = true
            statusLabel.text = "Map Load cancelled"
        }
    }
    @IBAction func addMarker(_ sender: UIButton) {
        let hitTestResults = scnView.hitTest(screenCenter, types: .featurePoint)
        if let result = hitTestResults.first {
            let pose = LibPlacenote.instance.processPose(pose: result.worldTransform)
            shapeManager.placeMarker(position: pose.position())
            
        }
    }
    
    @IBAction func onShowFeatureChange(_ sender: Any) {
        showFeatures = !showFeatures
        if (showFeatures) {
            ptViz?.enableFeaturePoints()
        }
        else {
            ptViz?.disableFeaturePoints()
        }
    }
    
    @IBAction func onDistanceFilterChange(_ sender: UISlider) {
        let currentValue = Float(sender.value)*maxRadiusSearch
        filterLabel1.text = String.localizedStringWithFormat("Distance filter: %.2f km", currentValue/1000.0)
        currRadiusSearch = currentValue
        updateMapTable(radius: currRadiusSearch)
    }
    
    @IBAction func onPlaneDetectionOnOff(_ sender: Any) {
        planeDetection = !planeDetection
        configureSession()
    }
    
    func configureSession() {
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = ARWorldTrackingConfiguration.WorldAlignment.gravity //TODO: Maybe not heading?
        
        if (planeDetection) {
            if #available(iOS 11.3, *) {
                configuration.planeDetection = [.horizontal, .vertical]
            } else {
                configuration.planeDetection = [.horizontal]
            }
        }
        else {
            for (_, node) in planesVizNodes {
                node.removeFromParentNode()
            }
            for (anchor) in planesVizAnchors { //remove anchors because in iOS versions <11.3, the anchors are not automatically removed when plane detection is turned off.
                scnView.session.remove(anchor: anchor)
            }
            planesVizNodes.removeAll()
            configuration.planeDetection = []
        }
        // Run the view's session
        scnView.session.run(configuration)
    }
    
    func toggleSliderUI (_ on: Bool, reset: Bool) {
        filterSlider.isHidden = on
        filterLabel1.isHidden = on
        filterLabel2.isHidden = on
        if (reset) {
            filterSlider.value = 1.0
            filterLabel1.text = "Distance slider: Off"
        }
    }
    
    func toggleMappingUI(_ on: Bool) {
        planeDetLabel.isHidden = on
        planeDetSelection.isHidden = on
        showPNLabel.isHidden = on
        showPNSelection.isHidden = on
        addMarkerButton.isHidden = on
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
            cell =  UITableViewCell(style: UITableViewCellStyle.subtitle, reuseIdentifier: map.0)
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
        
        return cell!
    }
    
    //Map selected
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(String(format: "Retrieving row: %d", indexPath.row))
        print("Retrieving mapId: " + maps[indexPath.row].0)
        statusLabel.text = "Retrieving mapId: " + maps[indexPath.row].0
        
        LibPlacenote.instance.loadMap(mapId: maps[indexPath.row].0,
          downloadProgressCb: {(completed: Bool, faulted: Bool, percentage: Float) -> Void in
            if (completed) {
                self.mappingStarted = false
                self.mappingComplete = false
                self.localizationStarted = true
                self.mapTable.isHidden = true
                self.pickMapButton.setTitle("Stop/Clear", for: .normal)
                self.newMapButton.isEnabled = true
                self.toggleMappingUI(false) //show mapping options UI
                self.toggleSliderUI(true, reset: true) //hide + reset UI for later
                let userdata = self.maps[indexPath.row].1.userdata as? [String:Any]
                if (self.shapeManager.loadMarkerArray(markerArray: userdata?["markerArray"] as? [[String: [String: String]]])) {
                    self.statusLabel.text = "Map Loaded. Look Around"
                } else {
                    self.statusLabel.text = "Map Loaded. Shape file not found"
                }
                LibPlacenote.instance.startSession()
                
                if (self.reportDebug) {
                    LibPlacenote.instance.startReportRecord (uploadProgressCb: ({(completed: Bool, faulted: Bool, percentage: Float) -> Void in
                        if (completed) {
                            self.statusLabel.text = "Dataset Upload Complete"
                            self.fileTransferLabel.text = ""
                        } else if (faulted) {
                            self.statusLabel.text = "Dataset Upload Faulted"
                            self.fileTransferLabel.text = ""
                        } else {
                            self.fileTransferLabel.text = "Dataset Upload: " + String(format: "%.3f", percentage) + "/1.0"
                        }
                    })
                    )
                    print ("Started Debug Report")
                }
                
                self.addMarkerButton?.isEnabled = true
                self.tapRecognizer?.isEnabled = true
            } else if (faulted) {
                print ("Couldnt load map: " + self.maps[indexPath.row].0)
                self.statusLabel.text = "Load error Map Id: " +  self.maps[indexPath.row].0
            } else {
                print ("Progress: " + percentage.description)
            }
        }
        )
    }
    
    //Make rows editable for deletion
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    //Delete Row and its corresponding map
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            statusLabel.text = "Deleting Map:" + maps[indexPath.row].0
            LibPlacenote.instance.deleteMap(mapId: maps[indexPath.row].0, deletedCb: {(deleted: Bool) -> Void in
                if (deleted) {
                    print("Deleting: " + self.maps[indexPath.row].0)
                    self.statusLabel.text = "Deleted Map: " + self.maps[indexPath.row].0
                    self.maps.remove(at: indexPath.row)
                    self.mapTable.reloadData()
                }
                else {
                    print ("Can't Delete: " + self.maps[indexPath.row].0)
                    self.statusLabel.text = "Can't Delete: " + self.maps[indexPath.row].0
                }
            })
        }
    }
    
    func updateMapTable() {
        LibPlacenote.instance.fetchMapList(listCb: onMapList)
    }
    
    func updateMapTable(radius: Float) {
        LibPlacenote.instance.searchMaps(latitude: self.lastLocation!.coordinate.latitude, longitude: self.lastLocation!.coordinate.longitude, radius: Double(radius), listCb: onMapList)
    }
    
    @objc func handleTap(sender: UITapGestureRecognizer) {
        // Deselect from dragging
        if sender.state == .ended {
            let location: CGPoint = sender.location(in: scnView)
            let hits = self.scnView.hitTest(location, options: nil)
            if !hits.isEmpty{
                if let tappedNode = hits.first?.node as? ClickableNode{
                    tappedNode.click()
                } else{
                    return
                }
            }
        }
    }
    
    
    // MARK: - ARSCNViewDelegate
    
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Create a SceneKit plane to visualize the plane anchor using its position and extent.
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let planeNode = SCNNode(geometry: plane)
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        node.transform = LibPlacenote.instance.processPose(pose: node.transform); //transform through
        planesVizNodes[anchor.identifier] = node; //keep track of plane nodes so you can move them once you localize to a new map.
        
        /*
         `SCNPlane` is vertically oriented in its local coordinate space, so
         rotate the plane to match the horizontal orientation of `ARPlaneAnchor`.
         */
        planeNode.eulerAngles.x = -.pi / 2
        
        // Make the plane visualization semitransparent to clearly show real-world placement.
        planeNode.opacity = 0.25
        
        /*
         Add the plane visualization to the ARKit-managed node so that it tracks
         changes in the plane anchor as plane estimation continues.
         */
        node.addChildNode(planeNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Update content only for plane anchors and nodes matching the setup created in `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        // Plane estimation may shift the center of a plane relative to its anchor's transform.
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        /*
         Plane estimation may extend the size of the plane, or combine previously detected
         planes into a larger one. In the latter case, `ARSCNView` automatically deletes the
         corresponding node for one plane, then calls this method to update the size of
         the remaining plane.
         */
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
        
        node.transform = LibPlacenote.instance.processPose(pose: node.transform)
    }
    
    // MARK: - ARSessionDelegate
    
    //Provides a newly captured camera image and accompanying AR information to the delegate.
    func session(_ session: ARSession, didUpdate: ARFrame) {
        let image: CVPixelBuffer = didUpdate.capturedImage
        let pose: matrix_float4x4 = didUpdate.camera.transform
        
        if (!LibPlacenote.instance.initialized()) {
            print("SDK is not initialized")
            return
        }
        
        if (mappingStarted || localizationStarted) {
            LibPlacenote.instance.setFrame(image: image, pose: pose)
        }
    }
    
    
    //Informs the delegate of changes to the quality of ARKit's device position tracking.
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        var status = "Loading.."
        switch camera.trackingState {
        case ARCamera.TrackingState.notAvailable:
            status = "Not available"
        case ARCamera.TrackingState.limited(.excessiveMotion):
            status = "Excessive Motion."
        case ARCamera.TrackingState.limited(.insufficientFeatures):
            status = "Insufficient features"
        case ARCamera.TrackingState.limited(.initializing):
            status = "Initializing"
        case ARCamera.TrackingState.limited(.relocalizing):
            status = "Relocalizing"
        case ARCamera.TrackingState.normal:
            if (!trackingStarted) {
                trackingStarted = true
                print("ARKit Enabled, Start Mapping")
                newMapButton.isEnabled = true
                newMapButton.setTitle("New Map", for: .normal)
            }
            status = "Ready"
        }
        statusLabel.text = status
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for (anchor) in anchors {
            planesVizAnchors.append(anchor)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
}

