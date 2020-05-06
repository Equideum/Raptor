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
    
    private let EC_PRIVATE_KEY_TAG = "org.fhirblocks.ecMaster"
    private let EC_KEY_SIZE = 256
    
    private (set) var didGuid: String?
    private (set)  var ecPubKeyBase58: String?
    private (set)  var rsaVerifPubKeyPem: String?
    
    private let DID_GUID_KEY = "didGuid"
    

    
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
        let removeSuccessful: Bool = KeychainWrapper.standard.removeObject(forKey: DID_GUID_KEY)
        if (!removeSuccessful) {
            NSLog("unable to remove DID Guid from keychain")
        }
           
        NSLog("TODO - zeroize")
    }
    
    private func getDidGuidFromKeyRing()  {
        self.didGuid = KeychainWrapper.standard.string(forKey: DID_GUID_KEY)
        if (self.didGuid == nil) {
            NSLog("DID GUID not found")
        }
    }
    
    private func getEcPubKeybase58FromSecureEnclave() {
        let ecPrivateKeyHandle = getPrivKeyHandle(keyTag: EC_PRIVATE_KEY_TAG, canDecrypt: false, keyType: kSecAttrKeyTypeEC)
        if (ecPrivateKeyHandle != nil) {
            // get the pub key from the priv key
            let ecPublicKeyRaw = SecKeyCopyPublicKey(ecPrivateKeyHandle!)
            if (ecPublicKeyRaw != nil) {
                ecPubKeyBase58 = keyToDERBase58Encoded(key: ecPublicKeyRaw!)
            }
        }
    }
    
    private func getRsaVerifPubKeyPemFromKeyRing() {
        
    }
    
    private func rekey() {
        makeDidGuid()
        NSLog("TODO - rekey")
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
