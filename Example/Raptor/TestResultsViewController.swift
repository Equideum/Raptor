//
//  TestResultsViewController.swift
//  Raptor_Example
//
//  Created by tom danner on 5/7/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import Raptor
import SwiftyJSON

class TestResultsViewController: UIViewController {

    let raptor = Raptor.Engine.sharedTest
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    @IBAction func generateVCClicked(_ sender: Any) {
        grantImprimateur()
        
        var cred = JSON()
        cred["iss"].string = raptor.getMyDidDoc()?.did
        cred["sub"].string = raptor.getMyDidDoc()?.did
        cred["id"].string = UUID().uuidString
        cred["testDate"].string = "2020-05-14T22:22:09Z"
        cred["testType"].string = "antigen 241"
        cred["testResults"].string = "negative"
        cred["context"].string="http://foo/testresults"
        
        do {
            let jwc = try raptor.createCredentialAsJWC(claims: cred)
            raptor.addCredentialToWallet(jwc: jwc)
            print (jwc)
            let jwcs: [String] = [jwc]
            let onBehalfOfDidGuid = raptor.getMyDidDoc()!.did
            if let imprimateurJwc = raptor.getImprimateurJWC(onBehalfOfDidGuid: onBehalfOfDidGuid) {
                let preso = raptor.createPresentation(jwcs: jwcs,
                                                      imprimateurJwc: imprimateurJwc,
                                                      onBehalfOfDidGuid: onBehalfOfDidGuid)
                print (preso)
                print (preso?.count)
                //   time for the QR code VC that shows the qr code of the vc
                initiateNextViewController(preso: preso!)
            } else {
                NSLog("No imprimateur given!")
            }
        
        } catch {
            print("Error in vc create")
        }
    }
    
    private func initiateNextViewController(preso: String) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let nvc = storyBoard.instantiateViewController(withIdentifier: "IssuerVCPresentViewController") as! IssuerVCPresentViewController
        nvc.preso = preso
        self.present(nvc, animated: true, completion: nil)
    }
    
    private func grantImprimateur() {
        var cred = JSON()
        cred["iss"].string = raptor.getMyDidDoc()?.did
        cred["sub"].string = raptor.getAgentDidDoc()?.did
        cred["id"].string = UUID().uuidString
        cred["context"].string="http://foo/imprimateur"
        
        do {
            let vcAsJSONString = try raptor.createCredentialAsJWC (claims: cred)
            //raptor.addCredentialToWallet(jwc: jwc)
            raptor.addImprimateurAsJWC  (onBehalfOfDidGuid: (raptor.getMyDidDoc()?.did)!, imprimateurVC: vcAsJSONString)
        } catch {
            print("error in imprimateur create")
        }
    }
    
}
