//
//  WalletItem.swift
//  Alamofire
//
//  Created by tom danner on 5/7/20.
//

import Foundation
import SwiftyJSON

public enum WalletItemError: Error {
    case missingRequiredClaims
}


public class WalletItem {
    
    private var jsonCredential: JSON
    private var rawCredential: String
       
    private var isDirtySignatureOk: Bool = false
    private var isDirtyExpired: Bool = false
    private var isDirtyHighTrust: Bool = false
    private var isDirtyRevoked: Bool = false
    
    private var iss: String = ""
    private var sub: String = ""
    private var id: String = ""
    private var context: String = ""
    
    
    

    public init() {
        jsonCredential = JSON()
        rawCredential = ""
    }
    
    public init(jwc: String) throws {
        jsonCredential = JSON()
        rawCredential = ""

        self.rawCredential = jwc
        self.jsonCredential = rawCredentialToJSON(rawCredential: rawCredential) ?? JSON()
        
        // perform basic validation that minimal components are available
        let isValid = isCredentialGotRequiredClaims (verifiableCredential: self.jsonCredential)
        if (!isValid) {
            throw WalletItemError.missingRequiredClaims
        }
        
        self.iss = self.jsonCredential["iss"].string!
        self.sub = self.jsonCredential["sub"].string!
        self.id = self.jsonCredential["id"].string!
        self.context = self.jsonCredential["context"].string!
        
        
        self.isDirtySignatureOk = testSignatureOk(credential: self.jsonCredential)
        self.isDirtyExpired = testExpired(credential: self.jsonCredential)
        self.isDirtyRevoked = testRevoked(credential: self.jsonCredential)
        self.isDirtyHighTrust = testHighTrust(credential: self.jsonCredential)
    }
    
    public func getRawCredential() -> String {
        return self.rawCredential
    }
    
    public func getIss() -> String {
        return self.iss
    }
    
    public func getSub() -> String {
        return self.sub
    }
    
    public func getId()  -> String{
        return self.id
    }
    
    public func getContext() -> String {
        return self.context
    }
    
    
    
    public func getJsonCredential() -> JSON {
        return self.jsonCredential
    }

    /*
            Func determines whether claim has minimal required claims of iss, sub, id, context
     */
    private func isCredentialGotRequiredClaims (verifiableCredential: JSON) -> Bool {
        guard let _ = verifiableCredential["iss"].string else { return false }
        guard let _ = verifiableCredential["sub"].string else { return false }
        guard let _ = verifiableCredential["id"].string else { return false }
        guard let _ = verifiableCredential["context"].string else { return false }
        return true
    }

    private func rawCredentialToJSON(rawCredential: String) -> JSON? {
        let credentialParts = rawCredential.components(separatedBy: ".")
        if (credentialParts.count == 3) {  // a raw credential always has header, body and signature}
            // decode the B64 into utf8
            let credentialAsJSONString = String (data: Data(base64Encoded: credentialParts[1])!, encoding: .utf8)!
            if let dataFromString = credentialAsJSONString.data(using: .utf8, allowLossyConversion: false) {
                var jsonCredential = try? JSON(data: dataFromString)
                //let iss = jsonCredential?["iss"].string
                var id = jsonCredential?["id"].string
                var context = jsonCredential?["context"].string
                // temp kludge to make up an id if its missing (Gen4 VCs do not have a id)
                if (id == nil) {
                    id = UUID().uuidString
                    jsonCredential?["id"].stringValue = id!
                }
                //another cludge
                if (context==nil) {
                    context="patientDemographicCredential"
                    jsonCredential?["context"].stringValue = context!
                }
                return jsonCredential
            }  else { // end if let
                NSLog("TODO - unable to decode B64 in body")
                return nil
            }
        } else {  // mal formed jwc
            NSLog ("TODO - malformed jwc without 3 parts")
            return nil
        }
    }

/*
   Test whether the credential is expired.  If credential has no exp claim, then they never expire
   */
    private func testExpired (credential: JSON) -> Bool {
        if let exp:  Double = jsonCredential["exp"].double{
            let currentTime = NSDate().timeIntervalSince1970
            if currentTime > exp {
                isDirtyExpired = true
            } else {
                isDirtyExpired = false
            }
        } else {
            isDirtyExpired = false
        }
        
        NSLog("TODO - testExpired unimplemented")
        return false
    }
  
  /*
   Test whether cred is a high trusted cred with WOT.  If not WOT claim, then return false (it's untrusted)
   */
  private func testHighTrust (credential: JSON) -> Bool {
      NSLog("TODO - testHighTrust unimplemented")
      return false
  }
  
  /*
   Test to see if signature is valid
   */
  private func testSignatureOk (credential: JSON) -> Bool {
      NSLog("TODO - testSignatureOk unimplemented")
      return false
  }
  
  /*
   Test to see if credential has been revoked
   */
  private func testRevoked (credential: JSON) -> Bool {
      NSLog("TODO - testRevoked unimplemented")
      return false
  }
}
