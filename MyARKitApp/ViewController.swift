//
//  ViewController.swift
//  MyARKitApp
//
//  Created by Zak Wegweiser on 2/26/19.
//  Copyright © 2019 Zak Wegweiser. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var infoLabel: UILabel!
    @IBOutlet var sceneView: ARSCNView!
    var ship: SCNNode!
    var currentAngleY: Float = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.debugOptions = .showFeaturePoints
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(didPinch(_:)))
        sceneView.addGestureRecognizer(pinchGesture)
        
        let rotateGesture = UIRotationGestureRecognizer(target: self, action: #selector(didRotate(_:)))
        sceneView.addGestureRecognizer(rotateGesture)
    }
    
    @objc func didTap(_ gesture: UIPanGestureRecognizer) {
        // Ensure ship is on screen
        guard let _ = ship else { return }
        
        let tapLocation = gesture.location(in: sceneView)
        let results = sceneView.hitTest(tapLocation, types: .featurePoint)
        
        if let result = results.first {
            let translation = result.worldTransform.translation
            ship.position = SCNVector3Make(translation.x, translation.y, translation.z)
            sceneView.scene.rootNode.addChildNode(ship)
        }
    }
    
    @objc func didPinch(_ gesture: UIPinchGestureRecognizer) {
        // Ensure ship is on screen
        guard let _ = ship else { return }
        var originalScale = ship?.scale
        
        // Get state of pinch
        switch gesture.state {
        case .began:
            // Pinch began
            originalScale = ship?.scale
            gesture.scale = CGFloat((ship?.scale.x)!)
        case .changed:
            // Pinch changed
            // Get new scale (if any)
            guard var newScale = originalScale else { return }
            if gesture.scale < 0.5{
                newScale = SCNVector3(x: 0.5, y: 0.5, z: 0.5)
            }
            else if gesture.scale > 2 {
                newScale = SCNVector3(2, 2, 2)
            }else{
                newScale = SCNVector3(gesture.scale, gesture.scale, gesture.scale)
            }
            ship?.scale = newScale
        case .ended:
            // Pinch ended
            guard var newScale = originalScale else { return }
            if gesture.scale < 0.5 {
                newScale = SCNVector3(x: 0.5, y: 0.5, z: 0.5)
            } else if gesture.scale > 2 {
                newScale = SCNVector3(2, 2, 2)
            } else{
                newScale = SCNVector3(gesture.scale, gesture.scale, gesture.scale)
            }
            ship?.scale = newScale
            gesture.scale = CGFloat((ship?.scale.x)!)
        default:
            gesture.scale = 1.0
            originalScale = nil
        }
    }
    
    @objc func didRotate(_ gesture: UIRotationGestureRecognizer) {
        guard let _ = ship else { return }
        var newAngleY = (Float)(-gesture.rotation)
        
        newAngleY += currentAngleY
        ship?.eulerAngles.z = newAngleY
        
        if gesture.state == .ended{
            currentAngleY = newAngleY
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Called when any node has been added to the anchor
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        DispatchQueue.main.async {
            self.infoLabel.text = "Surface Detected."
        }
        
        let shipScn = SCNScene(named: "ship.scn", inDirectory: "art.scnassets")
        ship = shipScn?.rootNode
        ship.simdPosition = float3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        sceneView.scene.rootNode.addChildNode(ship)
        node.addChildNode(ship)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        // This method will help when any node has been removed from sceneview
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Called when any node has been updated with data from anchor
    }
    
    // MARK: - ARSessionObserver
    
    func sessionWasInterrupted(_ session: ARSession) {
        infoLabel.text = "Session was interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        infoLabel.text = "Session interruption ended"
        resetTracking()
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        infoLabel.text = "Session failed: \(error.localizedDescription)"
        resetTracking()
    }
    
    func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        // help us inform the user when the app is ready
        switch camera.trackingState {
        case .normal :
            infoLabel.text = "Move the device to detect horizontal surfaces."
            
        case .notAvailable:
            infoLabel.text = "Tracking not available."
            
        case .limited(.excessiveMotion):
            infoLabel.text = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            infoLabel.text = "Tracking limited - Point the device at an area with visible surface detail."
            
        case .limited(.initializing):
            infoLabel.text = "Initializing AR session."
            
        default:
            infoLabel.text = ""
        }
    }
}

extension float4x4 {
    var translation: float3 {
        let translation = self.columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}
