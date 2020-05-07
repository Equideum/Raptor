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
    
    public static let sharedTest = Engine(prodChain: false)
    
    private let TIMER_VALUE  = 5.0
    
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
    
    private (set) var fhirblocksVersion = "unknown"
    private (set) var isProdChain: Bool
    private (set) var myDidDoc: DidDocument? = nil
    private (set) var state: [String: String]? {
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
    private var trustWeb: [String: [String: TrustedIssuer]] = [:]
    
    public init(prodChain: Bool) {
        self.isProdChain = prodChain
        if (prodChain) {
            baseUrl = BASE_PROD_URL
        } else {
            baseUrl = BASE_TEST_URL
        }
        
        networkFailed = false
        state = [:]
        state!["ping"]="Need Ping"
        state!["fbDid"]="Need fbDid"
        state!["myDid"]="Need myDid"

        getFHIRBlocksVersionNumber()
        getFbDidDoc()
        getMyDidDocFromChain()
        
    }

    public func getState () -> String {
        var resp: String  = ""
        for x in state! {
            resp = resp + x.value + ","
        }
        return resp
    }
    
    public func getMyDidDoc() -> DidDocument? {
        return self.myDidDoc
    }
    
    public func autoDestruct() {
        NSLog("ACTIVATING AUTO DESTRUCT")
        cryptoCore.zeroize()
    }
    
    public func fetchVerifiableCredentialsFromIssuerWithCalypso(issuerDid: String) {
        NSLog("TO DO - Fetch VC using calypso")
    }
    
    
    public func getTrustedDidDocuments(wot: String) -> [DidDocument] {
        let resp: [DidDocument] = []
        return resp
    }
    
    public func addCredentialToWallet (rawCredential: String) {
        NSLog("TODO - add credential")
    }
    
    public func getWalletItemByCredentialId (credentialId: String) -> WalletItem? {
        NSLog("TODO - get wallet item by credential id")
        let k = WalletItem()
        return k
    }
    
    public func getTrustedAuthenticationEndPoints() -> [String: String] {
        NSLog("TODO - getTrustedAuthenticationEndPoints")
        let k: [String : String] = [:]
        return k
    }
    
    public func isWalletEmpty() -> Bool {
        NSLog("TODO - is wallet empty")
        return true
    }
    
    public func getWallet() -> [String: [String: WalletItem]] {
        NSLog("TODO - get wallet")
        let k:[String: [String: WalletItem]]  = [ : ]
        return k
    }
    
    /*
        INTERACTIONS W DID METHOD GO HERE
        */

    @objc private func getFHIRBlocksVersionNumber() {
        NSLog("GET: ping")
        self.state!["ping"]="Reading FB Version"
        let url: String = baseUrl + "v4/operations/ping"
        AF.request(url).responseJSON { response in
            switch response.result {
            case .success(let value):
                let code = response.response?.statusCode ?? 0
                if code == 200 {
                    self.state!["ping"]="Got FB Version!"
                    let resp = JSON(value)
                    self.fhirblocksVersion = resp["version"].string ?? "Unknown"
                } else {
                    self.state!["ping"]="Ping Error"
                    self.networkFailed=true;
                    Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getFHIRBlocksVersionNumber), userInfo: nil, repeats: false)
                }
            case .failure (let error):
                NSLog(error.localizedDescription)
                self.state!["ping"]="Ping Error"
                self.networkFailed = true
                Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getFHIRBlocksVersionNumber), userInfo: nil, repeats: false)
            }  // end of switch
        }  // end of request
    }

    private func getFbDidDoc () {
        NSLog("GET: fb did")
        self.state!["fbDid"]="Reading FB Did"
        let url: String = baseUrl+"v4/operations/did?DID=did:fb:"
        let headers: HTTPHeaders = ["Accept": "application/json"]
        AF.request(url, headers: headers).responseJSON{ response in
            switch response.result {
            case .success(let value):
                let code = response.response?.statusCode ?? 0
                if (code == 200) {
                    self.state!["fbDid"]="Got FB Did!"
                    let didDocJson = JSON(value)
                    self.fbDidDoc = DidDocument(jsonRepresentation: didDocJson)
                } else {
                    self.state!["fbDid"]="FB Did Error"
                    self.networkFailed=true;
                    Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getFHIRBlocksVersionNumber), userInfo: nil, repeats: false)
                }
            case .failure (let error):
                self.state!["fbDid"]="FB Did Error"
                let msg = error.localizedDescription
                NSLog(msg)
                self.networkFailed = true
                Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getFHIRBlocksVersionNumber), userInfo: nil, repeats: false)
            }
        }
    }
    
    private func getMyDidDocFromChain ()  {
        if let guid = cryptoCore.didGuid {
            self.state!["myDid"]="Reading My Did"
            NSLog("GET: my did")
            let url: String = baseUrl+"v4/operations/did?DID="+guid
            let headers: HTTPHeaders = ["Accept": "application/json"]
            AF.request(url, headers: headers).responseJSON { response in
                switch response.result {
                case .success(let value):
                    let code: Int = response.response?.statusCode ?? 0
                    if code == 200 {
                        self.state!["myDid"]="Got My Did!"
                        let didDocJson = JSON(value)
                        self.myDidDoc = DidDocument(jsonRepresentation: didDocJson)
                    } else {
                        self.state!["myDid"]="FB Did Error"
                        self.networkFailed=true;
                        Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getFHIRBlocksVersionNumber), userInfo: nil, repeats: false)
                    }
                case .failure (let error):
                    let msg = error.localizedDescription
                    NSLog(msg)
                    self.state!["myDid"]="FB Did Error"
                    self.networkFailed=true;
                    Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getFHIRBlocksVersionNumber), userInfo: nil, repeats: false)
                } // end of switch
            }  // end of response
        }
    }

    
    
    /*
            PRIVATE WORKER METHODS
    */
    

}
