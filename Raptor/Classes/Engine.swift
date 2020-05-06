//
//  Engine.swift
//  Pods
//
//  Created by tom danner on 5/5/20.
//

import Foundation
import Alamofire
import SwiftyJSON


public let RaptorStateUpdate = "raptorStateUpdate"

open class Engine {
    
    /*
        PUBLIC
    */
       public enum VerifiableCredentialStatus {
           case unknown
           case signatureInvalid
           case signedButNotTrusted
           case signedAndTrusted
       }
    
    private let BASE_TEST_URL = "https://cmt.fhirblocks.io/"
    private var baseUrl: String
    private (set) var fhirblocksVersion = "unknown"
    private (set) var myDidDoc: DidDocument? = nil
    private (set) var state: String? {
          didSet {
              NotificationCenter.default.post(name: NSNotification.Name(rawValue: RaptorStateUpdate), object:nil)
          }
      }
    
    public init() {}

    /*
        INTERACTIONS W DID METHOD GO HERE
        */

    private func getFHIRBlocksVersionNumber() {
        NSLog("GET: ping")
        let url: String = baseURL+"v4/operations/ping"
        AF.request(url).responseJSON { response in
            switch response.result {
               case .success(let value):
                   let resp = JSON(value)
                   self.fhirblocksVersion = resp["version"].string ?? "Unknown"
                   self.initiateGetFBDid()
               case .failure (let error):
                   NSLog(error.localizedDescription)
            }  // end of switch
        }  // end of request
    }

    
}
