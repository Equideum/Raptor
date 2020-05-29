//
//  ScanVenueQRCodeViewController.swift
//  Raptor_Example
//
//  Created by tom danner on 5/17/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import Raptor
import AVFoundation
import SwiftyJSON

class ScanVenueQRCodeViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate  {
    
    var raptor = Raptor.Engine.sharedTest
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }
    
    func failed() {
          let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
          ac.addAction(UIAlertAction(title: "OK", style: .default))
          present(ac, animated: true)
          captureSession = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if (captureSession?.isRunning == false) {
               captureSession.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if (captureSession?.isRunning == true) {
               captureSession.stopRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(rawVenueCode: stringValue)
        }

        //dismiss(animated: true)
    }

    func found(rawVenueCode: String) {
        
        guard let data = rawVenueCode.data(using: .utf8) else {
            NSLog("cant get dat from qr code")
            return
        }
        guard let venue = try? JSON(data: data) else {
            NSLog("data to json conversion failed")
            return
        }
        
        if let myIdentity = raptor.getMyDidDoc()?.did {
            var imp = JSON()
            imp["iss"].string = myIdentity
            imp["sub"].string = raptor.getAgentDidDoc()?.did
            imp["id"].string = "random id"
            if let impJwc = try? raptor.createCredentialAsJWC (claims: imp) {
                raptor.addImprimateurAsJWC(onBehalfOfDidGuid: myIdentity, imprimateurVC: impJwc)
            }
            
            var claims = JSON()
            claims["iss"].string = myIdentity
            claims["sub"].string = myIdentity
            claims["id"].string = "a random id"
            claims["dt"].double = 9999
            claims["typ"].string = "COVID ABBOTT 15"
            claims["result"].bool = false
        
            do {
                let jwc = try raptor.createCredentialAsJWC(claims: claims)
                var jwcs: [String] = []
                jwcs.append(jwc)
                if let imprimateurJWC = raptor.getImprimateurJWC(onBehalfOfDidGuid: myIdentity) {
                    let preso = raptor.createPresentation(jwcs: jwcs, imprimateurJwc: imprimateurJWC, onBehalfOfDidGuid: myIdentity)
                    print (preso)
                    //raptor.createCalypsoMessage (preso)
                    NSLog("TODO - clean up proper did to send calypso to")
                    let targetDid = raptor.getAgentDidDoc()!.did
                    //let relayUrl = venue["relayUrl"].string
                    let relayUrl: String?  = "http://34.208.208.92:9080/" 
                    NSLog("TODO - remove kludge in setting relay url")
                    try raptor.createAndSendCalypso2Message(targetDid: targetDid, relayUrl: relayUrl!,  message: preso!)
                }
                
                // revert to prior view controller
                navigationController?.popViewController(animated: true)
                
            } catch {
                print ("error")
            }
        } // if let myIdentity
        
    }

    func gotoNextViewController() {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let newViewController = storyBoard.instantiateViewController(withIdentifier: "TestResultsViewController") as! TestResultsViewController
        self.present(newViewController, animated: true, completion: nil)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }




}
