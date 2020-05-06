//
//  CryptoCore.swift
//  Raptor
//
//  Created by tom danner on 5/5/20.
//

import Foundation
import SwiftKeychainWrapper
import BigInt

public enum Base58String {
    public static let btcAlphabet = [UInt8]("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    public static let flickrAlphabet = [UInt8]("123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ".utf8)
}

public class CryptoCore {
    
    private let EC_PRIVATE_KEY_TAG = "org.fhirblocks.ecMaster.priv"
    private let EC_PUBLIC_KEY_TAG = "org.fhirblocks.ecMaster.pub"
    private let RSA_VERIF_PRIVATE_KEY_TAG = "org.fhirblocks.rsaVerif.priv"
    private let RSA_VERIF_PUBLIC_KEY_TAG = "org.fhirblocks.rsaVerif.pub"
    private let EC_KEY_SIZE = 256
    private let DID_GUID_KEY = "didGuid"
    
    private (set) var didGuid: String?
    private (set)  var ecPubKeyBase58: String?
    private (set)  var rsaVerifPubKeyPem: String?
    
    private var ecPrivateKeyHandle: SecKey?
    private var rsaVerifPrivateKeyHandle: SecKey?
    private var ecPublicKeyRaw: SecKey?
    private var rsaPublicKeyRaw: SecKey?
    
    init() {
        // try to load from key ring
        getDidGuidFromKeyRing()
        getEcPubKeybase58FromSecureEnclave()
        getRsaVerifPubKeyPemFromKeyRing()
        
        if (didGuid == nil) || (ecPubKeyBase58 == nil) || (rsaVerifPubKeyPem == nil)  {  // all is lost so rekey!
            rekey()
        }
    }
    
    public func zeroize() {
        // remove did guid
        NSLog("removing did from keychain")
        let removeDidStatus: Bool = KeychainWrapper.standard.removeObject(forKey: DID_GUID_KEY)
        if (!removeDidStatus) {
            NSLog("Unable to remove DID Guid from keychain")
        }
        // remove the keys
        let removeKeysStatus: Bool = KeychainWrapper.standard.removeAllKeys()
        if (!removeKeysStatus) {
            NSLog("Unable to remove keys from key chain")
        }
    }
    
    private func getDidGuidFromKeyRing()  {
        self.didGuid = KeychainWrapper.standard.string(forKey: DID_GUID_KEY)
        if (self.didGuid == nil) {
            NSLog("DID GUID not found")
        }
    }
    
    private func getEcPubKeybase58FromSecureEnclave() {
        ecPrivateKeyHandle = getPrivKeyHandle(keyTag: EC_PRIVATE_KEY_TAG, canDecrypt: false, keyType: kSecAttrKeyTypeEC)
        if (ecPrivateKeyHandle != nil) {
            // get the pub key from the priv key
            ecPublicKeyRaw = SecKeyCopyPublicKey(ecPrivateKeyHandle!)
            if (ecPublicKeyRaw != nil) {
                ecPubKeyBase58 = keyToDERBase58Encoded(key: ecPublicKeyRaw!)
            }
        }
    }
    
    private func getRsaVerifPubKeyPemFromKeyRing() {
        rsaVerifPrivateKeyHandle = getPrivKeyHandle(keyTag: RSA_VERIF_PRIVATE_KEY_TAG, canDecrypt: false, keyType: kSecAttrKeyTypeEC)
        if (rsaVerifPrivateKeyHandle != nil) {
            // get the pub key from the priv key
            rsaPublicKeyRaw = SecKeyCopyPublicKey(ecPrivateKeyHandle!)
            if (rsaVerifPrivateKeyHandle != nil) {
                rsaVerifPubKeyPem = convertRSAKeyToPemBase64(key: rsaPublicKeyRaw!)
                rsaVerifPubKeyPem = rsaVerifPubKeyPem!.replacingOccurrences(of: "\n", with: "")
            }
        }
    }
    
    private func rekey() {
        makeDidGuid()
        makeEcKey()
        makeRsaVerifKey()
    }
    
    private func makeDidGuid() {
        self.didGuid = "did:fb:"+UUID().uuidString
        let saveSuccessful: Bool = KeychainWrapper.standard.set(didGuid!, forKey: DID_GUID_KEY)
        if (saveSuccessful) {
            NSLog("DID GUID save successful")
        } else {
            NSLog("ERROR - unable to save DID guid")
            didGuid = nil
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
    
    private func makeEcKey() {
        // set up parms
        // private key parameters
        let privateKeyParams  = [
            kSecAttrLabel as String: "didPriv",
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: EC_PRIVATE_KEY_TAG,
        ] as [String : Any]
               
        // public key parameters
        let publicKeyParams: [String: AnyObject] = [
            kSecAttrLabel as String: "didPub",
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: EC_PUBLIC_KEY_TAG
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
        let status = SecKeyGeneratePair(parameters, &ecPublicKeyRaw, &ecPrivateKeyHandle)
        NSLog("EC keygen status = \(status)")
        let errorMsg = SecCopyErrorMessageString(status,nil)
        NSLog ("msg decode: \(errorMsg!)")
        NSLog ("Done with ECkey creation")
    }
    
    private func makeRsaVerifKey() {
        (rsaVerifPrivateKeyHandle, rsaPublicKeyRaw) = createRSAKey(privateTag: RSA_VERIF_PRIVATE_KEY_TAG, publicTag: RSA_VERIF_PUBLIC_KEY_TAG)
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

    private func convertRSAKeyToPemBase64(key: SecKey) -> String {
      // converting public key to DER format
      var error: Unmanaged<CFError>?
      let publicKeyDataAPI = SecKeyCopyExternalRepresentation(key, &error)! as Data
      let exportImportManager = CryptoExportImportManager.init()
      let exportableDERKey = exportImportManager.exportPublicKeyToPEM((publicKeyDataAPI as NSData) as Data, keyType: kSecAttrKeyTypeRSA as String, keySize: 2048)
      return exportableDERKey!
    }
}

public extension String {

    public init(base58Encoding bytes: Data, alphabet: [UInt8] = Base58String.btcAlphabet) {
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
