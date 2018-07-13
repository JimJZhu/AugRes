//
//  ViewController.swift
//  BookMyRoom
//
//  Created by Jim on 2018-07-12.
//  Copyright © 2018 Jim. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import CoreLocation
import PlacenoteSDK
import BluemixAppID

class AfterLoginViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, PNDelegate, CLLocationManagerDelegate {

    //UI Elements
    @IBOutlet var scnView: ARSCNView!

    //UI Elements for the map table
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var showPNLabel: UILabel!
    @IBOutlet var showPNSelection: UISwitch!
    @IBOutlet var planeDetLabel: UILabel!
    @IBOutlet var planeDetSelection: UISwitch!
    @IBOutlet var fileTransferLabel: UILabel!

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
    var maps: [(String, LibPlacenote.MapMetadata)] = [("Sample Map", LibPlacenote.MapMetadata())]
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

    var userData: [String: Any]?
    var mapID: String?
    //Setup view once loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupScene()

        //App Related initializations
        shapeManager = MarkerManager(scene: scnScene, view: scnView)
        if shapeManager.loadMarkerArray(markerArray: self.userData?["markerArray"] as? [[String: [String: String]]]) {
            self.statusLabel.text = "Map Loaded. Look Around"
        } else {
            self.statusLabel.text = "Map Loaded. Shape file not found"
        }
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapRecognizer!.numberOfTapsRequired = 1
        tapRecognizer!.isEnabled = true
//        print("isdisabled")

        scnView.addGestureRecognizer(tapRecognizer!)

        //IMPORTANT: need to run this line to subscribe to pose and status events
        //Declare yourself to be one of the delegates of PNDelegate to receive pose and status updates
        LibPlacenote.instance.multiDelegate += self;

        //UI Updates
        toggleMappingUI(true) //hide mapping UI options
        locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()

        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self;
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
            locationManager.startUpdatingLocation()
        }

        // Start session
        LibPlacenote.instance.loadMap(mapId: mapID!,
          downloadProgressCb: {(completed: Bool, faulted: Bool, percentage: Float) -> Void in
            if (completed) {
                self.mappingStarted = false
                self.mappingComplete = false
                self.localizationStarted = true
                self.toggleMappingUI(false) //show mapping options UI
                if (self.shapeManager.loadMarkerArray(markerArray: self.userData?["markerArray"] as? [[String: [String: String]]])) {
                    self.statusLabel.text = "Map Loaded. Look Around"
                } else {
                    self.statusLabel.text = "Map Loaded. Shape file not found"
                }
                LibPlacenote.instance.startSession()
//                self.tapRecognizer?.isEnabled = true
//                print("isenabled")

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
            } else if (faulted) {
                print ("Couldnt load map: " + self.mapID!)
                self.statusLabel.text = "Load error Map Id: " +  self.mapID!
            } else {
                print ("Progress: " + percentage.description)
            }
        })
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
            for node in shapeManager.markerNodes {
                node.clickAction = {
                    self.showSessionCodeDialog(marker: node)
                }
            }
            if mappingStarted {
                statusLabel.text = "Tap anywhere to add Shapes, Move Slowly"
            }
            else if localizationStarted {
                statusLabel.text = "Map Found!"
            }
            tapRecognizer?.isEnabled = true
            print("isenabled")
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
//            tapRecognizer?.isEnabled = false
//            print("isdisabled")

        }

    }

    // MARK: - UI functions

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
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

    func toggleMappingUI(_ on: Bool) {
        planeDetLabel.isHidden = on
        planeDetSelection.isHidden = on
        showPNLabel.isHidden = on
        showPNSelection.isHidden = on
    }

    @objc func handleTap(sender: UITapGestureRecognizer) {
        print("tapped")
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

    func showSessionCodeDialog(marker: Marker) {
        // Brings up the dialog box for anchor resolution
        let alertController = UIAlertController(title: "Book Desk \(randomInt(min: 300, max: 800))?", message: "", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: {[unowned self] (_ action: UIAlertAction?) -> Void in
            if marker.status == .Available {
                marker.status = .Unavailable
            } else {
                marker.status = .Available
            }
        })
        let cancelAction = UIAlertAction(title: "CANCEL", style: .default, handler: {(_ action: UIAlertAction?) -> Void in
            alertController.dismiss(animated: true, completion: nil)
        })
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: false, completion: nil)
    }
    func randomInt(min: Int, max:Int) -> Int {
        return min + Int(arc4random_uniform(UInt32(max - min + 1)))
    }
}
