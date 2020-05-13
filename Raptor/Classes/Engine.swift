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
    private (set) var agentDidDoc: DidDocument?  = nil
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
        state!["agentDid"]="Need agentDid"
        state!["idns"]="Need IDN List"

        getFHIRBlocksVersionNumber()
        getFbDidDoc()
        getMyDidDocFromChain()
        getAgentDidFromChain()
        getIDNListFromChain()
    }

    public func getState () -> String {
        var resp: String  = ""
        for x in state! {
            if x.value != "ready" {
                resp = resp + x.value + ","
            }
        }
        if resp == "" {
            resp = "Ready for Action"
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
    
    public func getTrustedDidDocumentByIssuer(wot: String, iss: String) -> DidDocument? {
        NSLog("TODO - getTrustedDidDocumentByIssuer")
        return nil
    }
    
           //      try self.raptor.addDocumentSigningCert(walletItem:  walletItem)
    
    public func addDocumentSigningCert (walletItem: WalletItem) throws {
        NSLog("TODO - addDocumentSigningCert")
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
                    self.state!["ping"]="ready"
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

    @objc private func getFbDidDoc () {
        NSLog("GET: fb did")
        self.state!["fbDid"]="Reading FB Did"
        let url: String = baseUrl+"v4/operations/did?DID=did:fb:"
        let headers: HTTPHeaders = ["Accept": "application/json"]
        AF.request(url, headers: headers).responseJSON{ response in
            switch response.result {
            case .success(let value):
                let code = response.response?.statusCode ?? 0
                if (code == 200) {
                    self.state!["fbDid"]="ready"
                    let didDocJson = JSON(value)
                    self.fbDidDoc = DidDocument(jsonRepresentation: didDocJson)
                } else {
                    self.state!["fbDid"]="FB Did Error"
                    self.networkFailed=true;
                    Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getFbDidDoc), userInfo: nil, repeats: false)
                }
            case .failure (let error):
                self.state!["fbDid"]="FB Did Error"
                let msg = error.localizedDescription
                NSLog(msg)
                self.networkFailed = true
                Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getFbDidDoc), userInfo: nil, repeats: false)
            }
        }
    }
    
    @objc private func getMyDidDocFromChain ()  {
        if let guid = cryptoCore.identityDidGuid {
            self.state!["myDid"]="Reading My Did"
            NSLog("GET: my did")
            let url: String = baseUrl+"v4/operations/did?DID="+guid
            let headers: HTTPHeaders = ["Accept": "application/json"]
            AF.request(url, headers: headers).responseJSON { response in
                let code: Int = response.response?.statusCode ?? 0
                switch response.result {
                case .success(let value):
                    if code == 200 {
                        let didDocJson = JSON(value)
                        self.myDidDoc = DidDocument(jsonRepresentation: didDocJson)
                        self.state!["myDid"]="ready"
                    } else {
                        self.state!["myDid"]="FB Did Error"
                        self.networkFailed=true;
                        Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getMyDidDocFromChain), userInfo: nil, repeats: false)
                    }
                case .failure (let error):
                    if code == 404 {  // DID was not on file, we need to create it
                        self.createIdentityDid()
                    } else {
                        let msg = error.localizedDescription
                        NSLog(msg)
                        self.state!["myDid"]="FB Did Error"
                        self.networkFailed=true;
                        Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getMyDidDocFromChain), userInfo: nil, repeats: false)
                    }
                } // end of switch
            }  // end of response
        }
    }

    @objc private func getAgentDidDocFromChain ()  {
           if let guid = cryptoCore.agentDidGuid {
               self.state!["agentDid"]="Reading Agent Did"
               NSLog("GET: agent did")
               let url: String = baseUrl+"v4/operations/did?DID="+guid
               let headers: HTTPHeaders = ["Accept": "application/json"]
               AF.request(url, headers: headers).responseJSON { response in
                   let code: Int = response.response?.statusCode ?? 0
                   switch response.result {
                   case .success(let value):
                       if code == 200 {
                           let didDocJson = JSON(value)
                           self.agentDidDoc = DidDocument(jsonRepresentation: didDocJson)
                           self.state!["agentDid"]="ready"
                       } else {
                           self.state!["agentDid"]="FB Did Error"
                           self.networkFailed=true;
                           Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getMyDidDocFromChain), userInfo: nil, repeats: false)
                       }
                   case .failure (let error):
                       if code == 404 {  // DID was not on file, we need to create it
                           self.createAgentDid()
                       } else {
                           let msg = error.localizedDescription
                           NSLog(msg)
                           self.state!["agentDid"]="FB Did Error"
                           self.networkFailed=true;
                           Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getMyDidDocFromChain), userInfo: nil, repeats: false)
                       }
                   } // end of switch
               }  // end of response
           }
       }
    
    
    
    /*
            PRIVATE WORKER METHODS
    */
    
    @objc private func createIdentityDid() {
        self.state!["myDid"] = "Creating DID"
        NSLog("Creating a new DID Document from DID \(cryptoCore.identityDidGuid!)")
        
        var auth = DidAuthentication()
        auth.id = cryptoCore.identityDidGuid!+"#key-1"
        auth.controller = cryptoCore.identityDidGuid
        auth.publicKeyPem = cryptoCore.identityECPubKeyBase58
        auth.type = "ED25519VERIFICATIONKEY2018"
        
        var rsaVerificationAuth = DidAuthentication()
        rsaVerificationAuth.id = cryptoCore.identityDidGuid!+"#key-2"
        rsaVerificationAuth.controller = cryptoCore.identityDidGuid
        rsaVerificationAuth.publicKeyPem =  cryptoCore.rsaVerifPubKeyPem
        rsaVerificationAuth.type = "RSAVERIFICATIONKEY2018"
        
        self.myDidDoc = DidDocument()
        self.myDidDoc?.did = cryptoCore.identityDidGuid!
        self.myDidDoc?.service = [:]
        self.myDidDoc?.active = true
        self.myDidDoc?.name = ""
        self.myDidDoc?.authentication[auth.id!] = auth
        self.myDidDoc?.authentication[rsaVerificationAuth.id!] = rsaVerificationAuth
        
        let proof = makeProof(didDoc: self.myDidDoc!, didToUse: CryptoCore.DIDSelector.useIdentityDid)
        
        // now make up the Did Package
        var didPackage = DidPackage()
        didPackage.context = "https://w3id.org/fhirblocks/v4"
        didPackage.type = "ED25519VERIFICATIONKEY2018"
        didPackage.record = self.myDidDoc
        didPackage.proof = proof
        
        // and initiate sending it
        
        self.state!["myDid"] = "sending DID to Blockchain"
  
        NSLog("POST: did")
        let message = didPackage.toJSONString()
        let dataMessage = (message.data(using: .utf8))! as Data
            let url = baseUrl+"v4/operations/did"
            var request = URLRequest(url: URL(string: url)!)
            request.httpMethod = HTTPMethod.post.rawValue
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = dataMessage
           
            AF.request(request).responseJSON{ response in
                let code: Int = response.response?.statusCode ?? 0
                if code == 201 {
                    self.state!["myDid"]="ready"
                    return
                }
                switch response.result {
                case .success:
                    if code == 201 {
                        self.state!["myDid"]="DID Created"
                    } else {
                        self.state!["myDid"]="DID create error"
                        Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.createIdentityDid), userInfo: nil, repeats: false)
                    }
                case .failure (let error):
                    let msg = error.localizedDescription
                    NSLog(msg)
                    self.state!["myDid"]="DID create error"
                    Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.createIdentityDid), userInfo: nil, repeats: false)
                }  // end of switch
            } // end of response
    }  // end of func
        
    @objc private func createAgentDid() {
          self.state!["agentDid"] = "Creating Agent DID"
        NSLog("Creating a new Agent DID Document from DID \(cryptoCore.agentDidGuid!)")
          
          var auth = DidAuthentication()
          auth.id = cryptoCore.agentDidGuid!+"#key-1"
          auth.controller = cryptoCore.agentDidGuid
          auth.publicKeyPem = cryptoCore.agentECPubKeyBase58
          auth.type = "ED25519VERIFICATIONKEY2018"
          
          self.agentDidDoc = DidDocument()
          self.agentDidDoc?.did = cryptoCore.agentDidGuid!
          self.agentDidDoc?.service = [:]
          self.agentDidDoc?.active = true
          self.agentDidDoc?.name = ""
          self.agentDidDoc?.authentication[auth.id!] = auth
          
          // safe pt
          let proof = makeProof(didDoc: self.agentDidDoc!, didToUse: CryptoCore.DIDSelector.useAgentDid)
          
          // now make up the Did Package
          var didPackage = DidPackage()
          didPackage.context = "https://w3id.org/fhirblocks/v4"
          didPackage.type = "ED25519VERIFICATIONKEY2018"
          didPackage.record = self.agentDidDoc
          didPackage.proof = proof
          
          // and initiate sending it
          
          self.state!["agentDid"] = "sending Agent DID to Blockchain"
    
          NSLog("POST: did")
          let message = didPackage.toJSONString()
          let dataMessage = (message.data(using: .utf8))! as Data
              let url = baseUrl+"v4/operations/did"
              var request = URLRequest(url: URL(string: url)!)
              request.httpMethod = HTTPMethod.post.rawValue
              request.setValue("application/json", forHTTPHeaderField: "Content-Type")
              request.setValue("application/json", forHTTPHeaderField: "Accept")
              request.httpBody = dataMessage
             
              AF.request(request).responseJSON{ response in
                  let code: Int = response.response?.statusCode ?? 0
                  if code == 201 {
                      self.state!["agentDid"]="ready"
                      return
                  }
                  switch response.result {
                  case .success:
                      if code == 201 {
                          self.state!["agentDid"]="DID Created"
                      } else {
                          self.state!["agentDid"]="DID create error"
                          Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.createAgentDid), userInfo: nil, repeats: false)
                      }
                  case .failure (let error):
                      let msg = error.localizedDescription
                      NSLog(msg)
                      self.state!["agentDid"]="DID create error"
                      Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.createAgentDid), userInfo: nil, repeats: false)
                  }  // end of switch
              } // end of response
      }  // end of func
          
    
  
    
    private func makeProof(didDoc: DidDocument, didToUse: CryptoCore.DIDSelector) -> Proof {
        var didGuidToUse: String
            if didToUse == CryptoCore.DIDSelector.useAgentDid {
                didGuidToUse = self.agentDidDoc!.did
            } else {
                didGuidToUse = self.myDidDoc!.did
            }
            let dateString = Date().iso8601withFractionalSeconds
            var proof = Proof()
            proof.type="Ed25519Signature2018"
            proof.created = dateString
            proof.creator = didGuidToUse+"#key-1"
            proof.capability = didGuidToUse
            proof.capabilityAction = "registerDID"
            proof.proofPurpose = "invokeCapability"
            proof.jws = makeJWS(didDoc: didDoc, didToUse: didToUse)
          
            return proof
      }
    
    private func makeJWS(didDoc: DidDocument, didToUse: CryptoCore.DIDSelector) -> String {
        var body = didDoc.toJSONString()
        var header = "{\"alg\":\"EdDSA\",\"b64\":true,\"crit\":[\"b64\"]}"
        
        body = body.toBase64()
        header = header.toBase64()
        
        let payload = header+"."+body
        var sig = cryptoCore.sign(message: payload, whichDid: didToUse)
        return payload+"."+sig!
    }
    
    private func getAgentDidFromChain() {
    }
    
    private func getIDNListFromChain() {
        
    }
    
}


extension ISO8601DateFormatter {
    convenience init(_ formatOptions: Options, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) {
        self.init()
        self.formatOptions = formatOptions
        self.timeZone = timeZone
    }
}

extension Formatter {
    static let iso8601withFractionalSeconds = ISO8601DateFormatter([.withInternetDateTime, .withFractionalSeconds])
}

extension Date {
    var iso8601withFractionalSeconds: String { return Formatter.iso8601withFractionalSeconds.string(from: self) }
}

extension String {
    var iso8601withFractionalSeconds: Date? { return Formatter.iso8601withFractionalSeconds.date(from: self) }
}

extension String {
        func fromBase64() -> String? {
                guard let data = Data(base64Encoded: self) else {
                        return nil
                }
                return String(data: data, encoding: .utf8)
        }
        func toBase64() -> String {
                return Data(self.utf8).base64EncodedString()
        }
}
