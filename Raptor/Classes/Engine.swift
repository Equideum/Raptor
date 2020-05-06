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
    private let BASE_PROD_URL = "https://prodchain.fhirblocks.io/"
    private var baseUrl: String
    
    public var k: DidDocument?
    
    private (set) var fhirblocksVersion = "unknown"
    private (set) var isProdChain: Bool
    private (set) var myDidDoc: DidDocument? = nil
    private (set) var state: String? {
          didSet {
              NotificationCenter.default.post(name: NSNotification.Name(rawValue: RaptorStateUpdate), object:nil)
          }
      }
    private (set) var networkFailed: Bool {
        didSet {
            NSLog("TODO - Network failure handler")
        }
    }

    private let cryptoCore: CryptoCore = CryptoCore()
    private var fbDidDoc: DidDocument = DidDocument()

    
    public init(prodChain: Bool) {
        self.isProdChain = prodChain
        if (prodChain) {
            baseUrl = BASE_PROD_URL
        } else {
            baseUrl = BASE_TEST_URL
        }
        
        networkFailed = false
        
        getFHIRBlocksVersionNumber()
        getFbDidDoc()
        getMyDidDocFromChain()
        
    }

    /*
        INTERACTIONS W DID METHOD GO HERE
        */

    private func getFHIRBlocksVersionNumber() {
        NSLog("GET: ping")
        let url: String = baseUrl + "v4/operations/ping"
        AF.request(url).responseJSON { response in
            switch response.result {
               case .success(let value):
                   let resp = JSON(value)
                   self.fhirblocksVersion = resp["version"].string ?? "Unknown"
               case .failure (let error):
                   NSLog(error.localizedDescription)
                   self.networkFailed = true
            }  // end of switch
        }  // end of request
    }

    private func getFbDidDoc () {
        NSLog("GET: fb did")
        let url: String = baseUrl+"v4/operations/did?DID=did:fb:"
           let headers: HTTPHeaders = ["Accept": "application/json"]
           AF.request(url, headers: headers).responseJSON{ response in
               switch response.result {
               case .success(let value):
                   let didDocJson = JSON(value)
                   self.fbDidDoc = DidDocument(jsonRepresentation: didDocJson)
               case .failure (let error):
                   let msg = error.localizedDescription
                   NSLog(msg)
               }
           }
    }
    
    /*
            PRIVATE WORKER METHODS
     */
    
    private func getMyDidDocFromChain ()  {
        let guid = cryptoCore.didGuid
        NSLog("GET: my did")
        let url: String = baseUrl+"v4/operations/did?DID=did:fb:"
        let headers: HTTPHeaders = ["Accept": "application/json"]
        AF.request(url, headers: headers).responseJSON{ response in
            switch response.result {
                case .success(let value):
                    let code: Int = response.response?.statusCode ?? 0
                    let didDocJson = JSON(value)
                    self.myDidDoc = DidDocument(jsonRepresentation: didDocJson)
                case .failure (let error):
                    let msg = error.localizedDescription
                    NSLog(msg)
            }
        }
    }
}
