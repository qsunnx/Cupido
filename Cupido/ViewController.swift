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
    @MainActor private var databaseImages: [DatabaseImage] = [DatabaseImage]()
    
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
        
        sceneView.delegate = self
        
        let scene = SCNScene()
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configuration.worldAlignment = .camera
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x = -.pi / 2
        
        let mediaImages = databaseImages.filter({ $0.imageType == .media })
        var animateActions = [SCNAction]()
        
        for mediaImage in mediaImages {
            // TODO: retain cycle!
            let action = SCNAction.run { $0.geometry?.firstMaterial?.diffuse.contents = mediaImage.image }
            animateActions.append(action)
            animateActions.append(SCNAction.wait(duration: 10.0))
        }
        
        animateActions.append( SCNAction.run({ node in node.geometry?.firstMaterial?.diffuse.contents = self.databaseImages.first }) )
        
        let infiniteAction = SCNAction.repeatForever(SCNAction.sequence(animateActions))
        planeNode.runAction(infiniteAction)
        
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
            
            // TODO: затестить фриз экрана с диспатчем
            
            Task {
                do {
                    let _databaseImages = try await self.databaseProvider.getDatabaseImages(uid: uid)
                    self.databaseImages = _databaseImages
                } catch {
                    // TODO: сообщение об ошибке
                }
                
                let referenceImages = self.databaseImages
                    .filter({ $0.imageType == .trigger })
                    .map({ ARReferenceImage($0.image.cgImage!, orientation: .down, physicalWidth: 0.2) })
                var ARtriggerImages = Set<ARReferenceImage>()
                
                for referenceImage in referenceImages {
                    ARtriggerImages.insert(referenceImage)
                }
                
                self.startRender(trackingImages: ARtriggerImages)
            }
        }
    }
}

