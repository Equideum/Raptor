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
    
    public enum CalypsoError: Error {
        case unableToCipherMessage
    }
    
    private let BASE_TEST_URL = "https://cmt.fhirblocks.io/"
    private let BASE_PROD_URL = "https://prodchain.fhirblocks.io/"
    private let DID_AUTH_INITIATE_CONTEXT = "v5/didAuth/initiate"
    private let DID_AUTH_CHALLENGE_RESPONSE_CONTEXT = "v5/didAuth/challengeResp"
    private let SEND_CALYPSO_CONTEXT = "v5/calypso"
    private let RELAY_URL = "http://34.208.208.92:9080/"
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
    
    private (set) var calypsoSendFailed: Bool {
        didSet {
            NSLog("TODO - Calypso failure handler")
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
        calypsoSendFailed = false 
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

    public func test3 () {
        let ec = "r2kzlegBkksvThVjhL1sFFkFpuC4eJna2g0NsX6f9h5YwpMtGDN8tjbRh9GR/3eOSCLLpHSav813/xobKtGkOhaxnGhGBTHnICIFLTpv9BGIbhb4qTLsO4QaN11agFyfhe9JeAa+QIhk3KvuD6+NLQqKK9KTfGxogTE/dyhPpEaOC48yIsufgW4TtSjwBebO9YbOijFuho3zWSpDZnMdY4IuDqBLR2VsQHFAwTlqVcrGw0ZbJ6f6M4Q3KVqamgEeJVxA4zrA5uiE95+qVufAmsX6z1Je6DZGlbij4xL4qEzbqPE/S8/5+Nx5AmtJTGsoSyKCtVlyGYiBQYT7gypEGklFoIfCXJBsWTV3O0NerduAtZ+IZwDWWS3z2sgkWZOnWw3tZqOUX7HF+LuEekj/2tzKEcZthxoszbreJ79iCYm4vXD8ClVVMnYGmeCKIakwh0yZ9KLSrGqpXW+8oI5euzqHIYppIeSVQ6okeIx/pWLEpj2VycraG0Nmouh4AQXcD1ct9Qsj40IZDClH0XW1JBQSeBv3JhQaDZLnaLjTw7eQWD5N3tZUbXGXp4HuCKnM9AOXtzr6DLXx/2Do4O86uVIZzN6ytI0waJ1IE8NtAxSJ7LvNJULr2ZKlTYdN9NqJZydlY4nCsgdoxsTa3hX1iafBbAN3L3zHTo1c+D8LKrPqkC3RKea4LsIsda8eLaBHFODBMgZXWPtDrAWWQ3HINlraCe8ju9tU2/M+KJzn1oHYIo+Acf2AjRRGn4PMIOdqiVPTcmpGrzva/1B7HbZzGJosChu8MXQ9aw+mp5jbmeWDn5jBJO2BAN+oGI4lTQ+ZHIpMEiBmkUKOOYujoy6EGWkr9rmgH4iQ8u7n60Jbiv/bRAnsQBhpCmnJCQGUr8cm68XXHnE3YCttp+2uzrVjXR90QYmY/jl/7VX1ZaraCL+GujAmZ3ncKGJcbE4AfJroL3+YmYDA4ZP+CvEpM7am8Y9crdfqxM0Y/mDs47FQQuHF+s9SXug2RpW4o+MS+KhMQiqbHOkREFcvb312YVwW6tXcIg5Q/CzUkFM+IAR+wHqwVeNIWLLbkGEbGmUmStQdZI3sU5uW0TOc2/ymJBp6qLGMMccPY1T80Pi9+8GAt0pz4cFOBFrovbj+EcY1qy2oE/oQyH2ws3bZgs/ROYwdFPKHwOPEtgDjUcbLOCHIXyu4IQAv0zl7bR99Ylllikc/+nuyQZRDQsWBe+1ONUaeIl5hOp/0dVctwbarTkwAlUtJGX9/O/YiZ3MHoPvGWDa+0lEMNq3UTRxyqM0+IyklO5QgZDtPYifFgGP7bx9Hs3mWLxjKzAgR2Iicp0cOHkQQisLZr3tj2W5N9K+wbsCWJ6WFF2w4/eCe7me9FiuSC57XC+YAkTix6sDHwDG64JybeUW7MVezOZpMVsAcpGSk4BO631Wdl6toebSBHfUIXMivMD7DGJQmzZOfxl3Q3IpMH1lZIUJK+xxa/Q9txArsTPJarmwKfN+kUUC6nn+lKGAjmvidmOTYSpXFDxLK5vIa5+AmGQPDEaZzYLJtb0thMB3On0K730km2izy02o6t6pc1MUnMD9uqhvAhNweLVHbeydb1NJ7JkvahLCKZMCivKj5Gwn42w/bvA+wAZbSK1gBl2CTvjj01oEw1b3J917csoFLxCojQNryMxNKX2SveeZGDsScITnUlEkZGQWDNE1/G5Tqd4WQcCNJ4C+igU6ppy2800gSPXggrx8T894Ml3FLuAlJK2jXoWDVnH6KyVPSJgw9z1AyfMzMjignqY6wEXIF4mm8tYtEUC8y0I1TZ1E0zk2nooRMk5XwLOz3WrAfRcLL+PlzajK9Xrjq4aEWC/cC5h0uvahCkaD4gr5niw=="
        let okey = "FcFQ1+C2bviiXJugUHkCWc5ecqAxKajlPTz3z1CsOzSfd6IpFgRKH7S1b8nhEq1LUPIQEhO1ncOB/FwwnPuCtBdeWtEIWzJSZsvQy+1t6EjZgjScNsTY2z2PE/8sO1TqDsV6UuN1Ixwip/5NG7u4dQjfH8nlhEasN776nWLHbSbalpqNe+AWMIY4l76M5GFEgvuSGABabs9M57U3D11Nkjbl6uOExUTyix4bLhZtWsDFGkJJx4hbYSr77TVbQD0pZFMY1D0u4S35ePPuttKPbyIuAKxshT9IhEXqrZKY1IsSKssZbCaNGzkAIlDNRBFUMvm8rGFXgoFmcxceAM1Vkg=="
        let oiv = "kCYLA0UTFDETXLOQGBjE3g=="
        let ckey = cryptoCore.decryptWithAgentPrivateKey(message: okey)
        let clear = cryptoCore.decryptWithAes(key: ckey!, iv: oiv, cipherText: ec)
        print (clear)
    }
    
    public func test2 (key: String, iv: String, message: String) {
        let clearkey = cryptoCore.decryptWithAgentPrivateKey(message: key)
        let clearmsg = cryptoCore.decryptWithAes(key: clearkey!, iv: iv, cipherText: message)
        print (clearmsg)
    }
    
    public func test() {
        
        let clear  = "hello world how are you"
        
        let resp = try? cryptoCore.encryptWithAES(message: clear)
        let key = resp!.0
        let iv = resp!.1
        let msg = resp!.2
        
        let aesclear = cryptoCore.decryptWithAes(key: key!, iv: iv!, cipherText: msg!)
        print(aesclear)
        
        
        let cipher = cryptoCore.encryptWithPublicKey(message: key!, rsaPublicKey: cryptoCore.agentRSAVerifPubKeyPem!);
        let key2 = cryptoCore.decryptWithAgentPrivateKey(message: cipher!)

        let aesclear2 = cryptoCore.decryptWithAes(key: key2!, iv: iv!, cipherText: msg!)

        
        print (aesclear2)
        
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
    
    public func checkForCalypsoCredentials () {
        NSLog("Checking for Calypso Traffic")
        // first we need to get a token
        let didAuthInitUrl = RELAY_URL + DID_AUTH_INITIATE_CONTEXT
        var request = URLRequest(url: URL (string: didAuthInitUrl)!)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
         
        AF.request(request).responseJSON { response in
             switch response.result {
             case .success (let value):
                 let code = response.response?.statusCode ?? 0
                 if (code == 200) {
                     let jsonResp = JSON(value)
                     if let challenge = jsonResp["challenge"].string {
                         self.signChallengeAndRespond2 (challenge: challenge)
                     } else {
                         NSLog("no challenge in respone to did auth initiate")
                         self.calypsoSendFailed=true
                     }
                 }
             case .failure (let error):
                 self.calypsoSendFailed = true
                 let msg = error.localizedDescription
                 NSLog(msg)
             }  // end of switch
         } // end of response
    }
    
    private func signChallengeAndRespond2 (challenge: String) {
        let signature = cryptoCore.sign(message: challenge, whichDid: CryptoCore.DIDSelector.useAgentDid)
        var respJson = JSON()
        respJson["challenge"].string = challenge
        respJson["signedChallenge"].string = signature
        respJson["keyId"].string = cryptoCore.agentDidGuid!+"#key-1"
        respJson["did"].string = cryptoCore.agentDidGuid!
        respJson["verifiableCredentials"].arrayObject = []
        
        let didAuthChallengeRespUrl = RELAY_URL + DID_AUTH_CHALLENGE_RESPONSE_CONTEXT
        var request = URLRequest(url: URL (string: didAuthChallengeRespUrl)!)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let message = respJson.rawString()!
        let dataMessage = (message.data(using: .utf8))! as Data
        request.httpBody = dataMessage
        
        AF.request(request).responseJSON { response in
            switch response.result {
            case .success (let value):
                let code = response.response?.statusCode ?? 0
                if (code == 200) {
                    let jsonResp = JSON(value)
                    if let accessToken = jsonResp["token"].string {
                        print (accessToken)
                        self.withTokenInHandReceiveCalypsoMessages(accessToken: accessToken)
                    } else {
                        NSLog("NO token in challenge response")
                        self.calypsoSendFailed=true
                    }
                }
            case .failure (let error):
                self.calypsoSendFailed = true
                let msg = error.localizedDescription
                NSLog(msg)
            }  // end of switch
        } // end of response
    }
    
    private func withTokenInHandReceiveCalypsoMessages(accessToken: String) {
        let url = RELAY_URL + SEND_CALYPSO_CONTEXT
        var request = URLRequest(url: URL (string: url)!)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        
        AF.request(request).responseJSON { response in
            switch response.result {
            case .success (let value):
                let code = response.response?.statusCode ?? 0
                if (code == 200) {
                    let jsonResp = JSON(value)
                    let creds = jsonResp["messages"].array
                    for cred in creds! {
                        let encryptedCredential = cred["encryptedCredential"].string
                        let key = cred["key"].string
                        let iv = cred["iv"].string
                        if (encryptedCredential != nil) && (key != nil) && (iv != nil) {
                            if let jwc = self.decryptCalypsoCipheredVerifiableCredential(encryptedCredential: encryptedCredential!, key: key!, iv: iv!) {
                                self.addCredentialToWallet(jwc: jwc)
                            }
                        }
                    }
                }
            case .failure (let error):
                self.calypsoSendFailed = true
                let msg = error.localizedDescription
                NSLog(msg)
            }  // end of switch
        } // end of response
    }
    
    public func createAndSendCalypso2Message(targetDid: String, relayUrl: String, message: String) throws {
        guard let resp = try? cryptoCore.encryptWithAES(message: message) else {
            NSLog("cipher message failed")
            throw CalypsoError.unableToCipherMessage
        }
        // get the targetDidDoc
        if (targetDid != cryptoCore.agentDidGuid   ) {
            print("error")
        }
        NSLog("GET: target did of \(targetDid)")
        let url: String = baseUrl+"v4/operations/did?DID="+targetDid
        let headers: HTTPHeaders = ["Accept": "application/json"]
        AF.request(url, headers: headers).responseJSON{ response in
            switch response.result {
            case .success(let value):
                let code = response.response?.statusCode ?? 0
                if (code == 200) {
                    let didDocJson = JSON(value)
                    let authenticators = didDocJson["authentication"]
                    var pubKeyPem = ""
                    for authenticator in authenticators {
                        if "RSAVERIFICATIONKEY2018" == authenticator.1["type"].string {
                            pubKeyPem = authenticator.1["publicKeyPem"].string!
                        }
                    }
                    if (pubKeyPem == "") {
                        NSLog("no EC256 key in DID document")
                        self.calypsoSendFailed=true
                    } else {
                        //  public func encryptAESKeyWithECPubKey (AESKey: String?, ECPublicKey: String) -> String? {
                        
                        if let finalKey = self.cryptoCore.encryptWithPublicKey (message: resp.0, rsaPublicKey: pubKeyPem) {
                            try? self.sendCalypso2Message(targetDid: targetDid, relayUrl: relayUrl, key: finalKey, iv: resp.1!, cipheredMessage: resp.2!)
                        }
                    }
                } else {
                    self.calypsoSendFailed = true
                    Timer.scheduledTimer (timeInterval: self.TIMER_VALUE, target: self, selector: #selector(self.getFbDidDoc), userInfo: nil, repeats: false)
                }
            case .failure (let error):
                let msg = error.localizedDescription
                NSLog(msg)
            }
        }
    }
    
    private func processCalypso2Message(message: String) {
        guard let data = message.data(using: .utf8) else {
            NSLog("raw string to data failed")
            return
        }
    

        guard let jsonMessage = try? JSON(data: data) else {
            NSLog("cant make json object")
            return;
        }
        
        guard let version = jsonMessage["version"].string else {
            NSLog("pre 2.0 calypso message received")
            NSLog("TODO - process 1.0 message")
            return
        }
        if version != "2.0.0" {
            NSLog("message not 2.0.0 compliant - aborting")
            return
        }
        
        // now we know we have a v2.0.0 calypso message - make sure the message is addressed to me
        guard let targetDid = jsonMessage["targetDid"].string else {
            NSLog("targetDid is missing")
            return
        }
        if targetDid != agentDidDoc?.did {
            NSLog("Calypso message was addressed to \(targetDid) but my did is \(agentDidDoc?.did ?? "unknown")")
            return
        }
        
        // now lets get the encrypted Key, decrypt it into a useable key
        guard let encryptedKey = jsonMessage["key"].string else {
            NSLog("encrypted key not found")
            return
        }
        guard let aesKey = decryptCalypsoAESKey(encryptedKey: encryptedKey) else {
            NSLog("unable to decrypt key")
            return
        }
        
        // get the iv
        guard let iv = jsonMessage["iv"].string else {
            NSLog("no iv")
            return
        }
        
        // lastly get the VC, decrypt it into a JWC form
        guard let encryptedCredential = jsonMessage["encryptedCredential"].string else {
            NSLog("no encrypted credential")
            return
        }
        guard let jwc = decryptCalypsoCipheredVerifiableCredential(encryptedCredential: encryptedCredential, key: aesKey, iv: iv) else {
            NSLog("Unable to decrypt VC")
            return
        }
        // and add the VC to the wallet
        self.addCredentialToWallet(jwc: jwc)
    }
    
    private func decryptCalypsoAESKey (encryptedKey: String) -> String? {
        let k = cryptoCore.decryptWithAgentPrivateKey (message: encryptedKey)
        return k
    }
    
    private func decryptCalypsoCipheredVerifiableCredential (encryptedCredential: String, key: String, iv: String) -> String? {
        if let aesKeyInTheClear = cryptoCore.decryptWithAgentPrivateKey(message: key) {
            let jwc = cryptoCore.decryptWithAes(key: aesKeyInTheClear, iv: iv, cipherText: encryptedCredential)
            return jwc
        } else {
            NSLog("ERROR - unable to decrypt aes key")
            return nil
        }
    }
    
    /*
        calypso message parts are as follows:
     
        targetDid: the recipient of the message
        version:  2.0 for this version of calypso
        key:  encrypted symetrical key
        iv:  initialization veector
        message:   the message encrypted
     
     */
    private func sendCalypso2Message(targetDid: String, relayUrl: String, key: String, iv: String, cipheredMessage: String) throws {
        //  first we have to get a DID auth token -- then with the token in hand we can then post the calypso
        //  so to start off with, we do a did initiate to ask for a token:
        let didAuthInitUrl = relayUrl + DID_AUTH_INITIATE_CONTEXT
        var request = URLRequest(url: URL (string: didAuthInitUrl)!)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        AF.request(request).responseJSON { response in
            switch response.result {
            case .success (let value):
                let code = response.response?.statusCode ?? 0
                if (code == 200) {
                    let jsonResp = JSON(value)
                    if let challenge = jsonResp["challenge"].string {
                        self.signChallengeAndRespond (challenge: challenge, targetDid: targetDid, relayUrl: relayUrl, key: key, iv: iv, cipheredMessage: cipheredMessage)
                    } else {
                        NSLog("no challenge in respone to did auth initiate")
                        self.calypsoSendFailed=true
                    }
                }
            case .failure (let error):
                self.calypsoSendFailed = true
                let msg = error.localizedDescription
                NSLog(msg)
            }  // end of switch
        } // end of response
         
       
    }
    
    /*
     {
         "challenge": "e5732e33-377d-4c56-a751-d60a0c6fac23",
         "signedChallenge": "MEYCIQDf3alJs5_3edxFLx7FQ1fW7cDHaKiJR9jUaEPoIhJVFQIhAIsodEcSZkLi9uchB3ck9LfLQm8WprbAamFeciQCeSnq",
         "keyId": "did:fb:2ec7bc44-60d5-483a-ba60-e64b118bacbf#key-1",
         "did": "did:fb:2ec7bc44-60d5-483a-ba60-e64b118bacbf",
         "verifiableCredentials": []
     }
    
     */
    
    
    private func signChallengeAndRespond(challenge: String, targetDid: String, relayUrl: String, key: String, iv: String, cipheredMessage: String) {
        let signature = cryptoCore.sign(message: challenge, whichDid: CryptoCore.DIDSelector.useAgentDid)
        var respJson = JSON()
        respJson["challenge"].string = challenge
        respJson["signedChallenge"].string = signature
        respJson["keyId"].string = cryptoCore.agentDidGuid!+"#key-1"
        respJson["did"].string = cryptoCore.agentDidGuid!
        respJson["verifiableCredentials"].arrayObject = []
        
        let didAuthChallengeRespUrl = relayUrl + DID_AUTH_CHALLENGE_RESPONSE_CONTEXT
        var request = URLRequest(url: URL (string: didAuthChallengeRespUrl)!)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let message = respJson.rawString()!
        let dataMessage = (message.data(using: .utf8))! as Data
        request.httpBody = dataMessage
        
        AF.request(request).responseJSON { response in
            switch response.result {
            case .success (let value):
                let code = response.response?.statusCode ?? 0
                if (code == 200) {
                    let jsonResp = JSON(value)
                    if let accessToken = jsonResp["token"].string {
                        self.withTokenInHandSendCalypsoMessage (accessToken: accessToken, targetDid: targetDid,  relayUrl: relayUrl, key: key, iv: iv, cipheredMessage: cipheredMessage)
                    } else {
                        NSLog("NO token in challenge response")
                        self.calypsoSendFailed=true
                    }
                }
            case .failure (let error):
                self.calypsoSendFailed = true
                let msg = error.localizedDescription
                NSLog(msg)
            }  // end of switch
        } // end of response
    }
    
    private func withTokenInHandSendCalypsoMessage(accessToken: String, targetDid: String, relayUrl: String, key: String, iv: String, cipheredMessage: String) {
        var payload = JSON()
        payload["version"].string = "2.0.0"
        payload["targetDid"].string = targetDid
        payload["key"].string = key
        payload["iv"].string = iv
        payload["encryptedCredential"].string = cipheredMessage
        let rawMessage =  payload.rawString()
        
        
        let clear = test2 (key: key, iv: iv, message: cipheredMessage)
        
        // need to read for the did of the target, to get their pub key
        NSLog("POST: CALYPSO relay")
        let dataMessage: Data = rawMessage!.data(using: .utf8)!
        //let headers: HTTPHeaders = ["Accept": "application/json"]
        let finalUrl = relayUrl + SEND_CALYPSO_CONTEXT
        var request = URLRequest(url: URL(string: finalUrl)!)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("Bearer "+accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = dataMessage
               
               // Decode the Message Temporarily
              // processCalypso2Message(message: rawMessage!)
               
               
        AF.request(request).responseJSON { response in
            switch response.result {
                case .success(let value):
                    let code = response.response?.statusCode ?? 0
                    if (code == 201) {
                        NSLog("CALYPSO post worked aok")
                           
                        NSLog("SEND message to relay")
                    } else {
                        NSLog("TODO - target did not post \(code)")
                        self.calypsoSendFailed = true
                    }
                case .failure (let error):
                    self.calypsoSendFailed = true
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
        
        if (cryptoCore.identityECPubKeyBase58 == nil) || (cryptoCore.identityRSAVerifPubKeyPem == nil)  {
                NSLog("Identity EC Pub Key OR rsa verif key not present - stall wait ")
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
        rsaVerificationAuth.publicKeyPem =  cryptoCore.identityRSAVerifPubKeyPem
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
        
          var rsaVerificationAuth = DidAuthentication()
          rsaVerificationAuth.id = cryptoCore.agentDidGuid!+"#key-2"
          rsaVerificationAuth.controller = cryptoCore.agentDidGuid
          rsaVerificationAuth.publicKeyPem =  cryptoCore.agentRSAVerifPubKeyPem
          rsaVerificationAuth.type = "RSAVERIFICATIONKEY2018"
        
          
          self.agentDidDoc = DidDocument()
          self.agentDidDoc?.did = cryptoCore.agentDidGuid!
          self.agentDidDoc?.service = [:]
          self.agentDidDoc?.active = true
          self.agentDidDoc?.name = ""
          self.agentDidDoc?.authentication[auth.id!] = auth
          self.agentDidDoc?.authentication[rsaVerificationAuth.id!] = rsaVerificationAuth
          
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
