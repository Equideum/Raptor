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
    
    public enum VerifiableCredentialCreationError: Error {
        case issuerMustEqualRaptorIdentifier
        case mustContainSubject
        case mustContainId
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
    private let walletCore: WalletCore = WalletCore()
    private var imprimateurJWCs: [String: String] = [ : ]
    
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

        loadImprimateurs()
        
        getFHIRBlocksVersionNumber()
        getFbDidDoc()
        getIdentityDidDocFromChain()
        getAgentDidDocFromChain()
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
    
    public func createAndSendCalypso2Message(targetDid: String, relayUrl: String, message: String) throws {
        let ephemeralAESKey = cryptoCore.createAESKey()
        let iv = cryptoCore.createIV()
        let cipheredMessage = cryptoCore.encryptWithAES(key: ephemeralAESKey, initializationVector: iv, message: message)
        // need to read for the did of the target, to get their pub key
        NSLog("GET: did for calypso target")
        let url: String = baseUrl+"v4/operations/did?DID="+targetDid
        let headers: HTTPHeaders = ["Accept": "application/json"]
        AF.request(url, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                let code = response.response?.statusCode ?? 0
                if (code == 200) {
                    let didDocJson = JSON(value)
                    let TargetDidDoc = DidDocument(jsonRepresentation: didDocJson)
                    // now with target did in hand, encrypt the ephemeral AES key with the
                    let encryptedAESKey = self.cryptoCore.encryptAESKeyWithECPubKey(key: ephemeralAESKey)
                    var resp = JSON()
                    resp["target"].string = targetDid
                    resp["encryptedAESKey"].string = encryptedAESKey
                    resp["initilizationVector"].string = iv
                    resp["message"].string = cipheredMessage
                    
                    // now send the message to the relay
                    NSLog("SEND message to relay")
                } else {
                    NSLog("TODO - target did not read")
                }
            case .failure (let error):
                let msg = error.localizedDescription
                NSLog(msg)
            }
        }
    }
    
    public func getMyDidDoc() -> DidDocument? {
        return self.myDidDoc
    }
    
    public func getAgentDidDoc() -> DidDocument? {
        return self.agentDidDoc
    }
    
    public func autoDestruct() {
        NSLog("ACTIVATING AUTO DESTRUCT")
        cryptoCore.zeroize()
    }
    
    
    
    public func getTrustedDidDocuments(wot: String) -> [DidDocument] {
        let resp: [DidDocument] = []
        return resp
    }
    
    public func addCredentialToWallet (jwc: String) {
        walletCore.addBase64EncodedJWC(base64JWC: jwc)
    }
    
    public func getWalletItemByCredentialId (credentialId: String) -> WalletItem? {
        let k = walletCore.getWalletItemByCredentialId(credentialId: credentialId)
        return k
    }
    
    public func createCredentialAsJWC(claims: JSON) throws -> String {  // returns a base64 encoded JWC
        // you can only issue from the identity did
        if myDidDoc?.did != claims["iss"].string {
            throw  VerifiableCredentialCreationError.issuerMustEqualRaptorIdentifier
        }
        if claims["sub"].string == nil {
            throw VerifiableCredentialCreationError.mustContainSubject
        }
        if claims["id"].string == nil {
            throw VerifiableCredentialCreationError.mustContainId
        }
        let header = createJWCHeaderAsBase64()
        
        let body = claims.rawString()?.toBase64()
        let payload = header+"."+body!
        let sig = cryptoCore.sign(message: payload, whichDid: CryptoCore.DIDSelector.useIdentityDid)
        let jwc = payload+"."+sig!
        return jwc
    }
    
    /*
        this allows raptor to create VCs for other off platform dids and requires a imprimateur from that did
     */
    public func createPresentation(jwcs:  [String], imprimateurJwc: String, onBehalfOfDidGuid: String) -> String? {
        
        let epochTime = NSDate().timeIntervalSince1970
        
        var resp = JSON()
        resp["iss"].string = agentDidDoc?.did
        resp["sub"].string = onBehalfOfDidGuid
        resp["dt"].double = epochTime
        resp["imp"].string = imprimateurJwc
        resp["creds"].arrayObject = jwcs
    
        let header = createJWCHeaderAsBase64()
        let body = resp.rawString()?.toBase64()
        let payload = header+"."+body!
        let sig = cryptoCore.sign(message: payload, whichDid: CryptoCore.DIDSelector.useAgentDid)
        let r = payload+"."+sig!
        return r
    }

    public func fetchVerifiableCredentialsFromIssuerWithCalypso(issuerDid: String) {
        NSLog("TO DO - Fetch VC using calypso")
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
        let w = walletCore.getWallet()
        return w
    }
    
    public func getTrustedDidDocumentByIssuer(wot: String, iss: String) -> DidDocument? {
        NSLog("TODO - getTrustedDidDocumentByIssuer")
        return nil
    }
    
           //      try self.raptor.addDocumentSigningCert(walletItem:  walletItem)
    
    public func addDocumentSigningCert (walletItem: WalletItem) throws {
        NSLog("TODO - addDocumentSigningCert")
    }
    
    
    public func getImprimateurJWC(onBehalfOfDidGuid: String) -> String? {
        let x = imprimateurJWCs[onBehalfOfDidGuid]
        return x
    }
    
    public func addImprimateurAsJWC(onBehalfOfDidGuid: String, imprimateurVC: String) {
        imprimateurJWCs[onBehalfOfDidGuid] = imprimateurVC
        saveImprimateurs()
        NSLog("added imprimateur: \(imprimateurVC)")
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
    
    @objc private func getIdentityDidDocFromChain ()  {
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
                        Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getIdentityDidDocFromChain), userInfo: nil, repeats: false)
                    }
                case .failure (let error):
                    if code == 404 {  // DID was not on file, we need to create it
                        self.createIdentityDid()
                    } else {
                        let msg = error.localizedDescription
                        NSLog(msg)
                        self.state!["myDid"]="FB Did Error"
                        self.networkFailed=true;
                        Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getIdentityDidDocFromChain), userInfo: nil, repeats: false)
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
                           Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getAgentDidDocFromChain), userInfo: nil, repeats: false)
                       }
                   case .failure (let error):
                       if code == 404 {  // DID was not on file, we need to create it
                           self.createAgentDid()
                       } else {
                           let msg = error.localizedDescription
                           NSLog(msg)
                           self.state!["agentDid"]="FB Did Error"
                           self.networkFailed=true;
                           Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getAgentDidDocFromChain), userInfo: nil, repeats: false)
                       }
                   } // end of switch
               }  // end of response
           }
       }
    
    @objc private func getIDNListFromChain() {
          NSLog("GET: IDN List")
          self.state!["idns"]="Reading IDNs"
          let url: String = baseUrl + "v4/operations/idn"
          let headers: HTTPHeaders = ["Accept": "application/json"]
          AF.request(url, headers: headers).responseJSON { response in
              switch response.result {
              case .success(let value):
                  let code = response.response?.statusCode ?? 0
                  if code == 200 {
                      self.state!["idns"]="ready"
                      let resp = JSON(value)
                      for idnDidGuid in resp.array! {
                        self.getIdnDidDoc(idnDidGuid: idnDidGuid.string!)
                      }
                  } else {
                      self.state!["idns"]="IDNs Error"
                      self.networkFailed=true;
                      Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getIDNListFromChain), userInfo: nil, repeats: false)
                  }
              case .failure (let error):
                  NSLog(error.localizedDescription)
                  self.state!["idns"]="IDNs Error"
                  self.networkFailed = true
                  Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getIDNListFromChain), userInfo: nil, repeats: false)
              }  // end of switch
          }  // end of request
    }
      
    @objc private func getIdnDidDoc (idnDidGuid: String) {
        NSLog("Fetching did doc for idn \(idnDidGuid)")
        NSLog("GET: IDN did")
        let url: String = baseUrl+"v4/operations/did?DID="+idnDidGuid
        let headers: HTTPHeaders = ["Accept": "application/json"]
        AF.request(url, headers: headers).responseJSON { response in
            let code: Int = response.response?.statusCode ?? 0
            switch response.result {
            case .success(let value):
                if code == 200 {
                    let didDocJson = JSON(value)
                    var trustedIssuer = TrustedIssuer();
                    trustedIssuer.name = didDocJson["name"].string!
                    trustedIssuer.didDoc = DidDocument (jsonRepresentation: didDocJson)
                    var trustedIdns = self.trustWeb["idns"]
                    if trustedIdns == nil {
                        trustedIdns = [ : ]
                    }
                    let d = trustedIssuer.didDoc?.did
                    trustedIdns![d!]=trustedIssuer
                    self.trustWeb["idns"]=trustedIdns
                } else {
                    self.networkFailed=true;
                    Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getIdnDidDoc), userInfo: nil, repeats: false)
                }
            case .failure (let error):
                if code == 404 {  // DID was not on file, we need to create it
                    NSLog ("Trusted did is not found on the blockchain")
                } else {
                    let msg = error.localizedDescription
                    NSLog(msg)
                    self.networkFailed=true;
                    Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getIdnDidDoc), userInfo: nil, repeats: false)
                }
            } // end of switch
        }  // end of response
    }
    
    /*
            PRIVATE WORKER METHODS
    */
    
    @objc private func createIdentityDid() {
        self.state!["myDid"] = "Creating DID"
        NSLog("Creating a new DID Document from DID \(cryptoCore.identityDidGuid!)")
        
        if (cryptoCore.identityECPubKeyBase58 == nil) || (cryptoCore.rsaVerifPubKeyPem == nil)  {
                NSLog("Identity EC Pub Key not present - stall wait ")
                Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.createIdentityDid), userInfo: nil, repeats: false)
                return
        }
        
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
  
        NSLog("POST: identity did")
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
          
          if (cryptoCore.agentECPubKeyBase58 == nil) {
                    NSLog("Agent RC Pub Key not present - stall wait ")
                    Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.createIdentityDid), userInfo: nil, repeats: false)
                return
            }
            
        
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
    
          NSLog("POST: agent did")
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
          
    
    private func createJWCHeaderAsBase64() -> String {
        var h = JSON()
        h["typ"].string = "jwc"
        h["alg"].string = "ES256"
        let resp =  h.rawString()?.toBase64()
        return resp!
    }
    
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
        let sig = cryptoCore.sign(message: payload, whichDid: didToUse)
        return payload+"."+sig!
    }
    
    private func saveImprimateurs() {
        NSLog("TODO - saveImprimateurs")
    }

    private func loadImprimateurs() {
        NSLog("TODO - loadImprimateurs")

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
