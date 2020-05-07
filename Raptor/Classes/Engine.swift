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
                    self.state!["fbDid"]="Got FB Did!"
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
        if let guid = cryptoCore.didGuid {
            self.state!["myDid"]="Reading My Did"
            NSLog("GET: my did")
            let url: String = baseUrl+"v4/operations/did?DID="+guid
            let headers: HTTPHeaders = ["Accept": "application/json"]
            AF.request(url, headers: headers).responseJSON { response in
                let code: Int = response.response?.statusCode ?? 0
                switch response.result {
                case .success(let value):
                    if code == 200 {
                        self.state!["myDid"]="Got My Did!"
                        let didDocJson = JSON(value)
                        self.myDidDoc = DidDocument(jsonRepresentation: didDocJson)
                    } else {
                        self.state!["myDid"]="FB Did Error"
                        self.networkFailed=true;
                        Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getMyDidDocFromChain), userInfo: nil, repeats: false)
                    }
                case .failure (let error):
                    if code == 404 {  // DID was not on file, we need to create it
                        self.createDid()
                    }
                    let msg = error.localizedDescription
                    NSLog(msg)
                    self.state!["myDid"]="FB Did Error"
                    self.networkFailed=true;
                    Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getMyDidDocFromChain), userInfo: nil, repeats: false)
                } // end of switch
            }  // end of response
        }
    }

    
    
    /*
            PRIVATE WORKER METHODS
    */
    
    private func createDid() {
        self.state!["makeDid"] = "Creating DID"
        NSLog("Creating a new DID Document from DID \(cryptoCore.didGuid!)")
        
        var auth = DidAuthentication()
        auth.id = cryptoCore.didGuid!+"#key-1"
        auth.controller = cryptoCore.didGuid
        auth.publicKeyPem = cryptoCore.ecPubKeyBase58
        auth.type = "ED25519VERIFICATIONKEY2018"
        
        var rsaVerificationAuth = DidAuthentication()
        rsaVerificationAuth.id = cryptoCore.didGuid!+"#key-2"
        rsaVerificationAuth.controller = cryptoCore.didGuid
        rsaVerificationAuth.publicKeyPem =  cryptoCore.rsaVerifPubKeyPem
        rsaVerificationAuth.type = "RSAVERIFICATIONKEY2018"
        
        self.myDidDoc = DidDocument()
        self.myDidDoc?.did = cryptoCore.didGuid!
        self.myDidDoc?.service = [:]
        self.myDidDoc?.active = true
        self.myDidDoc?.name = ""
        self.myDidDoc?.authentication[auth.id!] = auth
        self.myDidDoc?.authentication[rsaVerificationAuth.id!] = rsaVerificationAuth
        
        let proof = makeProof(didDoc: self.myDidDoc!)
        
        // now make up the Did Package
        var didPackage = DidPackage()
        didPackage.context = "https://w3id.org/fhirblocks/v4"
        didPackage.type = "ED25519VERIFICATIONKEY2018"
        didPackage.record = self.myDidDoc
        didPackage.proof = proof
        
        // and initiate sending it
        
        self.state!["makeDid"] = "sending DID to Blockchain"
        
        //fbDidApi.postDid(didPackage: didPackage)
        
    }
    
  
    
    private func makeProof(didDoc: DidDocument) -> Proof {
          let dateString = Date().iso8601withFractionalSeconds
          var proof = Proof()
          proof.type="Ed25519Signature2018"
          proof.created = dateString
          proof.creator = cryptoCore.didGuid!+"#key-1"
          proof.capability=cryptoCore.didGuid!
          proof.capabilityAction="registerDID"
          proof.proofPurpose="invokeCapability"
          proof.jws = makeJWS(didDoc: didDoc)
          
          return proof
      }
    
    private func makeJWS(didDoc: DidDocument) -> String {
        var body = didDoc.toJSONString()
        var header = "{\"alg\":\"EdDSA\",\"b64\":true,\"crit\":[\"b64\"]}"
        
        body = body.toBase64()
        header = header.toBase64()
        
        let payload = header+"."+body
        var sig = cryptoCore.sign(message: payload)
        return payload+"."+sig!
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
