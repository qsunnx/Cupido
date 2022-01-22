//
//  ViewController.swift
//  Cupido
//
//  Created by Kirill Yudin on 05.08.2021.
//

import UIKit
import SceneKit
import ARKit
import Foundation

class ViewController: UIViewController {
    
    @IBOutlet var sceneView: ARSCNView!
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let databaseProvider = DatabaseProvider()
    private let configuration = ARImageTrackingConfiguration()
    private var databaseImages: [DatabaseImage] = [DatabaseImage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            //TODO: обработка ошибки c алертом
            return
        }
        
        var videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            //TODO: обработка ошибки с алертом
            return
        }
        
        if captureSession.canAddInput(videoInput) { captureSession.addInput(videoInput) }
        else {
            //TODO: обработка ошибки с алертом
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            //TODO: обработка ошибки с алертом
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        configuration.worldAlignment = .camera
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
}

extension ViewController {
   @MainActor private func startRender(trackingImages: Set<ARReferenceImage>) {
        self.configuration.trackingImages = trackingImages
        self.previewLayer.removeFromSuperlayer()
        self.sceneView.session.run(self.configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController: AVCaptureMetadataOutputObjectsDelegate, ARSCNViewDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let imageAnchor = anchor as? ARImageAnchor else { return nil }
        
        let plane = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height)
        plane.firstMaterial?.diffuse.contents = UIColor.blue
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x = -.pi / 2
        
        
        let material = SCNMaterial()
        material.isDoubleSided = true
        
        DispatchQueue.main.async {
            let imageView = UIImageView(image: self.databaseImages[0].image)
            material.diffuse.contents = imageView
            
            planeNode.geometry?.materials = [material]
        }
        
        let node = SCNNode()
        node.addChildNode(planeNode)
        return node
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let uid = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            Task {
                do {
                    let _databaseImages = try await databaseProvider.getDatabaseImages(uid: uid)
                    databaseImages = _databaseImages
                } catch {
                    // TODO: сообщение об ошибке
                }
                
                let referenceImages = databaseImages
                    .filter({ $0.imageType == .trigger })
                    .map({ ARReferenceImage($0.image.cgImage!, orientation: .up, physicalWidth: 0.1) })
                self.databaseImages
                var ARtriggerImages = Set<ARReferenceImage>()
                
                for referenceImage in referenceImages {
                    ARtriggerImages.insert(referenceImage)
                }
                
                startRender(trackingImages: ARtriggerImages)
            }
        }
    }
}
