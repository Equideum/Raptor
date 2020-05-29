//
//  SubjectLandingPageViewController.swift
//  Raptor_Example
//
//  Created by tom danner on 5/26/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import Raptor
import SwiftyJSON

class SubjectLandingPageViewController: UIViewController {

    var raptor = Raptor.Engine.sharedTest
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func calypsoClicked(_ sender: Any) {
  
       //raptor.test()
       raptor.checkForCalypsoCredentials()
      //  raptor.test3()
        
        
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
                } catch {
                    print ("error")
                }
        }
        
        //raptor.checkForCalypsoCredentials()
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
