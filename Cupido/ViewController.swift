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
    @IBOutlet var nextButton: UIButton!
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let databaseProvider = DatabaseProvider()
    private let configuration = ARImageTrackingConfiguration()
    private var mediaNode: SCNNode?
    private var databaseImages: [DatabaseImage] = [DatabaseImage]()
    private var timer: Timer?
    private var currentMediaImageIndex = 0
    private var operationsQueue = DispatchQueue(label: "com.cupido.MainOperationsQueue", qos: .userInitiated)
    
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
        sceneView.session.pause()
    }
    
    @IBAction func nextButtonPressed(_ sender: Any) {
        guard let mediaNode = mediaNode else {
            return
        }
        mediaNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "TestImage2")

    }
}

extension ViewController {
   @MainActor private func startRender(trackingImages: Set<ARReferenceImage>) {
        self.configuration.trackingImages = trackingImages
        self.previewLayer.removeFromSuperlayer()
        self.sceneView.session.run(self.configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    @MainActor private func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(changeMediaImage), userInfo: nil, repeats: true)
    }
    
    @MainActor private func destroyTimer() {
        timer?.invalidate()
    }
    
    @objc private func changeMediaImage() {
        // TODO: сделать потокобезопасный код - вынести в функцию с семафорами или сделать отдельную очередь для получения именно этого значения
        DispatchQueue.main.async {
            self.mediaNode?.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "TestImage2")
        }
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
        
        mediaNode = SCNNode(geometry: SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height))
        mediaNode?.eulerAngles.x = -.pi / 2
//        let material = SCNMaterial()
//        material.isDoubleSided = true
//
//        DispatchQueue.main.async {
//            let imageView = UIImageView(image: UIImage.init(named: "TestImage"))
//            material.diffuse.contents = imageView
//
//            planeNode.geometry?.materials = [material]
//        }
        
//        let node = SCNNode()
//        node.addChildNode(mediaNode)
//        return node
        
        DispatchQueue.main.async {
            // TODO: сделать потокобезопасный код - вынести в функцию с семафорами или сделать отдельную очередь для получения именно этого значения
            let mediaItem = self.databaseImages.first{ $0.imageType == .media }
            self.currentMediaImageIndex = self.databaseImages.firstIndex{ $0 == mediaItem }
            self.mediaNode?.geometry?.firstMaterial?.diffuse.contents = mediaItem?.image
        }
        
        //  а вот тут у нас проблема! асинк!
        
        return mediaNode
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
                var ARtriggerImages = Set<ARReferenceImage>()
                
                for referenceImage in referenceImages {
                    ARtriggerImages.insert(referenceImage)
                }
                
                startRender(trackingImages: ARtriggerImages)
                startTimer()
            }
        }
    }
}
