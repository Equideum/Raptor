//
//  CryptoCore.swift
//  Raptor
//
//  Created by tom danner on 5/5/20.
//

import Foundation
import SwiftKeychainWrapper
import BigInt
import SwiftyRSA


public enum Base58String {
    public static let btcAlphabet = [UInt8]("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    public static let flickrAlphabet = [UInt8]("123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ".utf8)
}


public class CryptoCore {

    public enum DIDSelector {
        case useIdentityDid
        case useAgentDid
    }
    
    private let IDENTITY_EC_PRIVATE_KEY_TAG = "org.fhirblocks.identityECMaster.priv"
    private let IDENTITY_EC_PUBLIC_KEY_TAG = "org.fhirblocks.identityECMaster.pub"
    private let AGENT_EC_PRIVATE_KEY_TAG = "org.fhirblocks.agentECMaster.priv"
    private let AGENT_EC_PUBLIC_KEY_TAG = "org.fhirblocks.agentECMaster.pub"
    private let RSA_VERIF_PRIVATE_KEY_TAG = "org.fhirblocks.rsaVerif.priv"
    private let RSA_VERIF_PUBLIC_KEY_TAG = "org.fhirblocks.rsaVerif.pub"
    private let EC_KEY_SIZE = 256
    private let IDENTITY_DID_GUID_KEY = "didGuid"
    private let AGENT_DID_GUID_KEY = "agentDidGuid"

    private (set) var identityDidGuid: String?
    private (set) var agentDidGuid: String?
    private (set) var identityECPubKeyBase58: String?
    private (set) var agentECPubKeyBase58: String?
    private (set) var rsaVerifPubKeyPem: String?
    
    private var identityECPrivateKeyHandle: SecKey?
    private var agentECPrivateKeyHandle: SecKey?
    private var rsaVerifPrivateKeyHandle: SecKey?
    private var identityECPublicKeyRaw: SecKey?
    private var agentECPublicKeyRaw: SecKey?
    private var rsaPublicKeyRaw: SecKey?
    
    init() {
        // try to load from key ring
        getIdentityDidGuidFromKeyRing()
        getAgentDidGuidFromKeyRing()
        getIdentityECPubKeyBase58FromSecureEnclave()
        getAgentECPubKeyBase58FromSecureEnclave()
        getRsaVerifPubKeyPemFromKeyRing()
        
        if (agentDidGuid == nil) || (identityDidGuid == nil) || (identityECPubKeyBase58 == nil) ||
            (rsaVerifPubKeyPem == nil) || identityECPubKeyBase58 == nil {  // all is lost so rekey!
            rekey()
        }
    }
    
    public func zeroize() {
        // remove identity did guid
        NSLog("removing identity did from keychain")
        let removeIdentityDidStatus: Bool = KeychainWrapper.standard.removeObject(forKey: IDENTITY_DID_GUID_KEY)
        if (!removeIdentityDidStatus) {
            NSLog("Unable to remove DID Guid from keychain")
        }

        // remove agent did guid
        NSLog("removing agent did from keychain")
        let removeAgentDidStatus: Bool = KeychainWrapper.standard.removeObject(forKey: AGENT_DID_GUID_KEY)
        if (!removeAgentDidStatus) {
            NSLog("Unable to remove DID Guid from keychain")
        }

        // remove the keys
        let identityECPrivKeyStatus =   deleteKey(keyTag: IDENTITY_EC_PRIVATE_KEY_TAG, keyType: kSecAttrKeyTypeEC as String)
        if (!identityECPrivKeyStatus) {
            NSLog ("unable to remove key - ec priv indentity")
        }
        let identityECPubKeyStatus =    deleteKey(keyTag: IDENTITY_EC_PUBLIC_KEY_TAG, keyType: kSecAttrKeyTypeEC as String)
        if (!identityECPubKeyStatus) {
            NSLog ("unable to remove key - ec pub indentity")
        }
        let agentECPrivKeyStatus =      deleteKey(keyTag: AGENT_EC_PRIVATE_KEY_TAG, keyType: kSecAttrKeyTypeEC as String)
        if (!agentECPrivKeyStatus) {
            NSLog ("unable to remove key - ec priv agent")
        }
        let agentECPubKeyStatus =       deleteKey(keyTag: AGENT_EC_PUBLIC_KEY_TAG, keyType: kSecAttrKeyTypeEC as String)
        if (!agentECPrivKeyStatus) {
            NSLog ("unable to remove key - ec pub agent")
        }
        let rsaVerifPrivKeyStatus =     deleteKey(keyTag: RSA_VERIF_PRIVATE_KEY_TAG, keyType: kSecAttrKeyTypeRSA as String)
        if (!rsaVerifPrivKeyStatus) {
            NSLog ("unable to remove key - rsa priv agent")
        }
        let rsaVerifPubKeyStatus =      deleteKey(keyTag: RSA_VERIF_PUBLIC_KEY_TAG, keyType: kSecAttrKeyTypeRSA as String)
        if (!rsaVerifPubKeyStatus) {
            NSLog ("unable to remove key - rsa pub agent")
        }
        
        identityECPrivateKeyHandle = nil
        agentECPrivateKeyHandle = nil
        rsaVerifPrivateKeyHandle = nil
        identityECPublicKeyRaw = nil
        agentECPublicKeyRaw = nil
        rsaPublicKeyRaw = nil
        
        NSLog("TODO - remove list of rsa keys for digi signing")
        
    }

    /*
     Signs the message string and returns a signature element
     */
    public func sign (message: String, whichDid: DIDSelector) -> String? {
        var key: SecKey?
        if whichDid == DIDSelector.useAgentDid {
            key = agentECPrivateKeyHandle
        } else {
            key = identityECPrivateKeyHandle
        }
        let signedData = signMessageForData(privateKey: key!, message: message)
        let encodedStrg = signedData?.base64EncodedString()
        if (encodedStrg==nil) {
            NSLog("Signing ceremony produced nil")
            return nil
        } else {
            let finalAnswer = base64ToBase64url(base64: encodedStrg!)
            return finalAnswer
        }
    }
    
    private func deleteKey(keyTag: String, keyType: String) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: keyType,
            kSecReturnRef as String: true,
            kSecAttrCanSign as String: true
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { return false }
        return true
    }
    
    private func signMessageForData(privateKey: SecKey, message: String) -> Data? {
        let algorithm = SecKeyAlgorithm.ecdsaSignatureMessageX962SHA256;
        let canSign = SecKeyIsAlgorithmSupported(privateKey, SecKeyOperationType.sign, algorithm)
        if(canSign) {
            let data = message.data(using: String.Encoding.utf8)!
            var error: Unmanaged<CFError>?
            guard let signedData = SecKeyCreateSignature(privateKey, algorithm, data as CFData, &error) as Data? else {
                NSLog("this key type cannot sign messages")
                return nil
            }
         return signedData
       } else {
            return nil
       }
     }
    
    private func getIdentityDidGuidFromKeyRing()  {
        self.identityDidGuid = KeychainWrapper.standard.string(forKey: IDENTITY_DID_GUID_KEY)
        if (self.identityDidGuid == nil) {
            NSLog("DID Guid not found")
        } else {
            NSLog("Identity DID Guid recovered from keychain")
        }
    }
    
    private func getAgentDidGuidFromKeyRing()  {
        self.agentDidGuid = KeychainWrapper.standard.string(forKey: AGENT_DID_GUID_KEY)
        if (self.agentDidGuid == nil) {
            NSLog("Agent DID Guid not found")
        } else {
            NSLog("Agent DID Guid recovered from keyschain")
        }
    }
    
    
    private func getIdentityECPubKeyBase58FromSecureEnclave() {
        identityECPrivateKeyHandle = getPrivKeyHandle(keyTag: IDENTITY_EC_PRIVATE_KEY_TAG, canDecrypt: false, keyType: kSecAttrKeyTypeEC)
        if (identityECPrivateKeyHandle != nil) {
            // get the pub key from the priv key
            identityECPublicKeyRaw = SecKeyCopyPublicKey(identityECPrivateKeyHandle!)
            if (identityECPublicKeyRaw != nil) {
                identityECPubKeyBase58 = keyToDERBase58Encoded(key: identityECPublicKeyRaw!)
                NSLog("Identity Key Recovered from Keychain")
            }
        }
    }
    
    private func getAgentECPubKeyBase58FromSecureEnclave() {
          agentECPrivateKeyHandle = getPrivKeyHandle(keyTag: AGENT_EC_PRIVATE_KEY_TAG, canDecrypt: false, keyType: kSecAttrKeyTypeEC)
          if (agentECPrivateKeyHandle != nil) {
              // get the pub key from the priv key
              agentECPublicKeyRaw = SecKeyCopyPublicKey(agentECPrivateKeyHandle!)
              if (agentECPublicKeyRaw != nil) {
                  agentECPubKeyBase58 = keyToDERBase58Encoded(key: agentECPublicKeyRaw!)
                  NSLog("Agent Key Recovered from Keychain")
              }
          }
      }
      
    
    private func getRsaVerifPubKeyPemFromKeyRing() {
        rsaVerifPrivateKeyHandle = getPrivKeyHandle(keyTag: RSA_VERIF_PRIVATE_KEY_TAG, canDecrypt: false, keyType: kSecAttrKeyTypeRSA)
        if (rsaVerifPrivateKeyHandle != nil) {
            // get the pub key from the priv key
            rsaPublicKeyRaw = SecKeyCopyPublicKey(rsaVerifPrivateKeyHandle!)
            if (rsaVerifPrivateKeyHandle != nil) {
                rsaVerifPubKeyPem = convertRSAKeyToPemBase64(key: rsaPublicKeyRaw!)
                rsaVerifPubKeyPem = rsaVerifPubKeyPem!.replacingOccurrences(of: "\n", with: "")
                NSLog("RSA Verification Key recovered from Keychain")
            }
        }
    }
    
    private func rekey() {
        makeAgentDidGuid()
        makeIdentityDidGuid()
        makeIdentityEcKey()
        makeAgentEcKey()
        makeRsaVerifKey()
    }

    private func makeAgentDidGuid() {
        self.agentDidGuid = "did:fb:"+UUID().uuidString
        let saveSuccessful: Bool = KeychainWrapper.standard.set(self.agentDidGuid!, forKey: AGENT_DID_GUID_KEY)
        if (saveSuccessful) {
            NSLog("DID GUID save successful")
        } else {
            NSLog("ERROR - unable to save DID guid")
            self.agentDidGuid = nil
        }
    }

    
    private func makeIdentityDidGuid() {
        self.identityDidGuid = "did:fb:"+UUID().uuidString
        let saveSuccessful: Bool = KeychainWrapper.standard.set(identityDidGuid!, forKey: IDENTITY_DID_GUID_KEY)
        if (saveSuccessful) {
            NSLog("DID GUID save successful")
        } else {
            NSLog("ERROR - unable to save DID guid")
            self.identityDidGuid = nil
        }
    }
 

    
    private struct Platform {
        static let isSimulator: Bool = {
            var isSim = false
            #if arch(i386) || arch(x86_64)
                isSim = true
            #endif
            return isSim
        }()
    }
    
    private func makeIdentityEcKey() {
        // set up parms
        // private key parameters
        let privateKeyParams  = [
            kSecAttrLabel as String: "identityDidPriv",
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: IDENTITY_EC_PRIVATE_KEY_TAG,
        ] as [String : Any]
               
        // public key parameters
        let publicKeyParams: [String: AnyObject] = [
            kSecAttrLabel as String: "identityDidPub",
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: IDENTITY_EC_PUBLIC_KEY_TAG
        ] as [String : Any] as [String : AnyObject]

        // global parameters
        var parameters: CFDictionary
        if (Platform.isSimulator) {
            parameters = [
                kSecAttrKeyType as String: kSecAttrKeyTypeEC,
                kSecAttrKeySizeInBits as String: EC_KEY_SIZE,
                    //kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
                kSecPublicKeyAttrs as String: publicKeyParams,
                kSecPrivateKeyAttrs as String: privateKeyParams
            ] as CFDictionary
        } else {
            parameters = [
                kSecAttrKeyType as String: kSecAttrKeyTypeEC,
                kSecAttrKeySizeInBits as String: EC_KEY_SIZE,
                kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
                kSecPublicKeyAttrs as String: publicKeyParams,
                kSecPrivateKeyAttrs as String: privateKeyParams
            ] as CFDictionary
        }
               
        // now make the keys!
        let status = SecKeyGeneratePair(parameters, &identityECPublicKeyRaw, &identityECPrivateKeyHandle)
        NSLog("EC keygen status = \(status)")
        let errorMsg = SecCopyErrorMessageString(status,nil)
        NSLog ("msg decode: \(errorMsg!)")
        
        identityECPubKeyBase58 = keyToDERBase58Encoded(key: identityECPublicKeyRaw!)
        
        NSLog ("Done with Identity ECkey creation")
    }
    
    private func makeAgentEcKey() {
           // set up parms
           // private key parameters
           let privateKeyParams  = [
               kSecAttrLabel as String: "agentDidPriv",
               kSecAttrIsPermanent as String: true,
               kSecAttrApplicationTag as String: AGENT_EC_PRIVATE_KEY_TAG,
           ] as [String : Any]
                  
           // public key parameters
           let publicKeyParams: [String: AnyObject] = [
               kSecAttrLabel as String: "agentDidPub",
               kSecAttrIsPermanent as String: true,
               kSecAttrApplicationTag as String: AGENT_EC_PUBLIC_KEY_TAG
           ] as [String : Any] as [String : AnyObject]

           // global parameters
           var parameters: CFDictionary
           if (Platform.isSimulator) {
               parameters = [
                   kSecAttrKeyType as String: kSecAttrKeyTypeEC,
                   kSecAttrKeySizeInBits as String: EC_KEY_SIZE,
                       //kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
                   kSecPublicKeyAttrs as String: publicKeyParams,
                   kSecPrivateKeyAttrs as String: privateKeyParams
               ] as CFDictionary
           } else {
               parameters = [
                   kSecAttrKeyType as String: kSecAttrKeyTypeEC,
                   kSecAttrKeySizeInBits as String: EC_KEY_SIZE,
                   kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
                   kSecPublicKeyAttrs as String: publicKeyParams,
                   kSecPrivateKeyAttrs as String: privateKeyParams
               ] as CFDictionary
           }
                  
           // now make the keys!
           let status = SecKeyGeneratePair(parameters, &agentECPublicKeyRaw, &agentECPrivateKeyHandle)
           NSLog("EC keygen status = \(status)")
           let errorMsg = SecCopyErrorMessageString(status,nil)
           NSLog ("msg decode: \(errorMsg!)")
        
           agentECPubKeyBase58 = keyToDERBase58Encoded(key: agentECPublicKeyRaw!)
    
           NSLog ("Done with Agent ECkey creation")
       }
    
    private func makeRsaVerifKey() {
        (rsaVerifPrivateKeyHandle, rsaPublicKeyRaw) = createRSAKey(privateTag: RSA_VERIF_PRIVATE_KEY_TAG, publicTag: RSA_VERIF_PUBLIC_KEY_TAG)
        rsaVerifPubKeyPem = convertRSAKeyToPemBase64(key: rsaPublicKeyRaw!)
        rsaVerifPubKeyPem = rsaVerifPubKeyPem?.replacingOccurrences(of: "\n", with: "")
    }
    
    private func createRSAKey(privateTag: String, publicTag: String) -> (SecKey?, SecKey?) {
        let publicKeyAttr = [
          kSecAttrIsPermanent:true as NSObject,
          kSecAttrApplicationTag: publicTag,
          kSecClass: kSecClassKey,
          kSecReturnData: kCFBooleanTrue ?? true
        ] as CFDictionary
        
        let privateKeyAttr  = [
          kSecAttrIsPermanent:true as NSObject,
          kSecAttrApplicationTag: privateTag ,
          kSecClass: kSecClassKey,
          kSecReturnData: kCFBooleanTrue ?? true
        ] as CFDictionary
        
        let parms =  [
          kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
          kSecAttrKeySizeInBits as String: 2048,
          kSecPrivateKeyAttrs as String: privateKeyAttr,
          kSecPublicKeyAttrs as String: publicKeyAttr
        ] as CFDictionary
        var privateKey: SecKey?
        var publicKey: SecKey?
        let status = SecKeyGeneratePair (parms, &publicKey, &privateKey)
        let errorMsg = SecCopyErrorMessageString(status, nil)!
        NSLog ("Error msg from RSA key creation: \(errorMsg)   private tag type: \(privateTag)")
        return (privateKey, publicKey)
    }
    
    private func getPrivKeyHandle(keyTag: String, canDecrypt: Bool, keyType: CFString ) -> SecKey! {
          var item: CFTypeRef?
          var query: [String: Any] = [
              kSecClass as String: kSecClassKey,
              kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
              kSecAttrKeyType as String: keyType,
              kSecReturnRef as String: true,
              kSecAttrCanSign as String: true,
              //kSecAttrCanDecrypt as String: canDecrypt
          ]
          
          if (canDecrypt) {
              query[kSecAttrCanDecrypt as String] = true
          }
          
          let status = SecItemCopyMatching(query  as CFDictionary, &item)
          let errorMsg  = SecCopyErrorMessageString(status,nil)
          if (status == errSecSuccess) {
              let privateKey = item as! SecKey
              return privateKey;
          } else {
              NSLog("ERROR - unable to get private key \(String(describing: errorMsg))")
              return nil;
          }
      }

    private func keyToDERBase58Encoded(key: SecKey) -> String {
        var error: Unmanaged<CFError>?
        let publicKeyDataAPI = SecKeyCopyExternalRepresentation(key, &error)! as Data
        let exportImportManager = CryptoExportImportManager.init()
        let exportableDERKey = exportImportManager.exportPublicKeyToDER((publicKeyDataAPI as NSData) as Data, keyType: kSecAttrKeyTypeEC as String, keySize: EC_KEY_SIZE)
        let publicKeyDerKeyString = String(base58Encoding: exportableDERKey!)
        //let publicKeyDerKeyString = ""
        NSLog("Base58 Encoded string: \(publicKeyDerKeyString)")
        return publicKeyDerKeyString
      }

  

    // go back to that old way since we saw a defect in key names!
    
    /*
    private func convertRSAKeyToPemBase64(key: SecKey) -> String {
      // converting public key to DER format
      var error: Unmanaged<CFError>?
      let publicKeyDataAPI = SecKeyCopyExternalRepresentation(key, &error)! as Data
      let exportImportManager = CryptoExportImportManager.init()
      let exportableDERKey = exportImportManager.exportPublicKeyToPEM((publicKeyDataAPI as NSData) as Data, keyType: kSecAttrKeyTypeRSA as String, keySize: 2048)
      return exportableDERKey!
    }
 */

   
    private func convertRSAKeyToPemBase64 (key: SecKey) -> String? {
        do {
            let pubKey = try PublicKey (reference: key)
            let pem: String = try pubKey.pemString()
            return pem
        } catch {
            print("error occurred")
            return ""
        }
    }
   
    
    private func base64ToBase64url(base64: String) -> String {
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64url
    }
}

public extension String {

    init(base58Encoding bytes: Data, alphabet: [UInt8] = Base58String.btcAlphabet) {
        var x = BigUInt(bytes)
        let radix = BigUInt(alphabet.count)

        var answer = [UInt8]()
        answer.reserveCapacity(bytes.count)

        while x > 0 {
            let (quotient, modulus) = x.quotientAndRemainder(dividingBy: radix)
            answer.append(alphabet[Int(modulus)])
            x = quotient
        }

        let prefix = Array(bytes.prefix(while: {$0 == 0})).map { _ in alphabet[0] }
        answer.append(contentsOf: prefix)
        answer.reverse()

        self = String(bytes: answer, encoding: String.Encoding.utf8)!
    }

}
