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
import CryptoSwift
import CommonCrypto


public enum Base58String {
    public static let btcAlphabet = [UInt8]("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    public static let flickrAlphabet = [UInt8]("123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ".utf8)
}


public class CryptoCore {

    public enum DIDSelector {
        case useIdentityDid
        case useAgentDid
    }
    
    public enum AESError: Error {
        case keyGeneration(status: Int)
        case cryptoFailed(status: CCCryptorStatus)
        case badKeyLength
        case badInputVectorLength
    }
    
    private let IDENTITY_EC_PRIVATE_KEY_TAG = "org.fhirblocks.identityECMaster.priv"
    private let IDENTITY_EC_PUBLIC_KEY_TAG = "org.fhirblocks.identityECMaster.pub"
    private let AGENT_EC_PRIVATE_KEY_TAG = "org.fhirblocks.agentECMaster.priv"
    private let AGENT_EC_PUBLIC_KEY_TAG = "org.fhirblocks.agentECMaster.pub"
    private let IDENTITY_RSA_VERIF_PRIVATE_KEY_TAG = "org.fhirblocks.identityRSAVerif.priv"
    private let IDENTITY_RSA_VERIF_PUBLIC_KEY_TAG = "org.fhirblocks.identityRSAVerif.pub"
    private let AGENT_RSA_VERIF_PRIVATE_KEY_TAG = "org.fhirblocks.identityRSAVerif.priv"
    private let AGENT_RSA_VERIF_PUBLIC_KEY_TAG = "org.fhirblocks.identityRSAVerif.pub"
    
    private let EC_KEY_SIZE = 256
    private let RSA_KEY_SIZE = 2048
    
    private let IDENTITY_DID_GUID_KEY = "didGuid"
    private let AGENT_DID_GUID_KEY = "agentDidGuid"

    private (set) var identityDidGuid: String?
    private (set) var agentDidGuid: String?
    private (set) var identityECPubKeyBase58: String?
    private (set) var agentECPubKeyBase58: String?
    private (set) var identityRSAVerifPubKeyPem: String?
    private (set) var agentRSAVerifPubKeyPem: String?
    
    private var identityECPrivateKeyHandle: SecKey?
    private var agentECPrivateKeyHandle: SecKey?
  
    private var identityECPublicKeyRaw: SecKey?
    private var agentECPublicKeyRaw: SecKey?
    
    private var identityRSAVerifPrivateKeyHandle: SecKey?
    private var identityRSAPublicKeyRaw: SecKey?
    private var agentRSAVerifPrivateKeyHandle: SecKey?
    private var agentRSAPublicKeyRaw: SecKey?
    
    init() {
        // try to load from key ring
        getIdentityDidGuidFromKeyRing()
        getAgentDidGuidFromKeyRing()
        getIdentityECPubKeyBase58FromSecureEnclave()
        getAgentECPubKeyBase58FromSecureEnclave()
        getIdentityRsaVerifPubKeyPemFromKeyRing()
        getAgentRsaVerifPubKeyPemFromKeyRing()
        
        if  (agentDidGuid == nil) || (identityDidGuid == nil) ||
            (identityECPubKeyBase58 == nil) ||  (identityRSAVerifPrivateKeyHandle == nil) ||
            (agentECPubKeyBase58 == nil)  || (agentECPrivateKeyHandle == nil) ||
            (identityRSAPublicKeyRaw == nil) || (identityRSAVerifPrivateKeyHandle == nil) ||
            (agentRSAPublicKeyRaw == nil)  || (agentRSAVerifPrivateKeyHandle == nil) {  // all is lost so rekey!
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
        if (!agentECPubKeyStatus) {
            NSLog ("unable to remove key - ec pub agent")
        }
        
        // handle removal of rsa keys
        
        let identityRSAVerifPrivKeyStatus =     deleteKey(keyTag: IDENTITY_RSA_VERIF_PRIVATE_KEY_TAG, keyType: kSecAttrKeyTypeRSA as String)
        if (!identityRSAVerifPrivKeyStatus) {
            NSLog ("unable to remove key - identity rsa priv agent")
        }
        let identityRSAVerifPubKeyStatus =      deleteKey(keyTag: IDENTITY_RSA_VERIF_PUBLIC_KEY_TAG, keyType: kSecAttrKeyTypeRSA as String)
        if (!identityRSAVerifPubKeyStatus) {
            NSLog ("unable to remove key - identity rsa pub agent")
        }
        let agentRSAVerifPrivKeyStatus =     deleteKey(keyTag: AGENT_RSA_VERIF_PRIVATE_KEY_TAG, keyType: kSecAttrKeyTypeRSA as String)
        if (!agentRSAVerifPrivKeyStatus) {
            NSLog ("unable to remove key - agent rsa priv agent")
        }
        let agentRSAVerifPubKeyStatus =      deleteKey(keyTag: AGENT_RSA_VERIF_PUBLIC_KEY_TAG, keyType: kSecAttrKeyTypeRSA as String)
        if (!agentRSAVerifPubKeyStatus) {
            NSLog ("unable to remove key - agent rsa pub agent")
        }

        identityECPrivateKeyHandle = nil
        agentECPrivateKeyHandle = nil
        identityECPublicKeyRaw = nil
        agentECPublicKeyRaw = nil
        identityRSAVerifPrivateKeyHandle = nil
        identityRSAPublicKeyRaw = nil
        agentRSAVerifPrivateKeyHandle = nil
        agentRSAPublicKeyRaw = nil
        
        
        NSLog("TODO - remove list of rsa keys for digi signing - but only for identity side not agent as theres no such thing")
        
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
     
     
    public func decryptWithAgentPrivateKey (message: String) -> String?  {
        NSLog("decrypt calypso message w agent priv key for did \(agentDidGuid ?? "")")
        if let decodedMessageAsData = NSData(base64Encoded: message, options: .ignoreUnknownCharacters) {
            let cipherBytes = [UInt8](decodedMessageAsData as Data)
            var blockSize = Int(SecKeyGetBlockSize(agentRSAVerifPrivateKeyHandle!))
            var clearTextMessage = [UInt8](repeating:0, count:Int(blockSize))
            var status: OSStatus!
             
            status = SecKeyDecrypt(agentRSAVerifPrivateKeyHandle!, SecPadding.PKCS1,
                                cipherBytes,   blockSize,
                                &clearTextMessage,  &blockSize)
            
            if status != noErr {
                let msg = SecCopyErrorMessageString(status, nil)
                NSLog("unable to use private key to decrypt \(status ?? 999) - \(msg ?? "" as CFString)")
                return nil
            }
            let data = Data.init(bytes: clearTextMessage)
            var clearText = String(decoding: data, as: UTF8.self)
            clearText = clearText.replacingOccurrences(of: "\0", with: "")
            return clearText
        }
        return nil
    }
    
 

    
    public func encryptWithPublicKey (message: String?, rsaPublicKey: String) -> String? {
        let msg = message
        print("initial clear text \(msg ?? "")")
        var workingKeyStrg = rsaPublicKey
        workingKeyStrg = workingKeyStrg.replacingOccurrences(of: "-----BEGIN RSA PUBLIC KEY-----", with: "")
        workingKeyStrg = workingKeyStrg.replacingOccurrences(of: "-----END RSA PUBLIC KEY-----", with: "")
        let keyData = Data.init (base64Encoded: workingKeyStrg)?.bytes
        
        
        //let keyData = Data.init(base64Encoded: ECPublicKey)
        let keyDict: [String:Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: RSA_KEY_SIZE
        ]
        var error: Unmanaged<CFError>?
        let pubKey = SecKeyCreateWithData(Data.init (bytes: keyData!) as CFData, keyDict as CFDictionary, &error)
        let blockSize = SecKeyGetBlockSize(pubKey!)
        var status: OSStatus!
        var messageEncrypted = [UInt8](repeating: 0, count: blockSize)
        var messageEncryptedSize = blockSize

        status = SecKeyEncrypt( pubKey!,
                               SecPadding.PKCS1,
                               msg!,
                               msg!.count,
                               &messageEncrypted,
                               &messageEncryptedSize)

        if status != noErr {
            let msg = SecCopyErrorMessageString(status, nil)
            NSLog("unable to use public key to encrypt \(status ?? 999) - \(msg ?? "" as CFString)")
            return nil
        }

        let data = Data.init(bytes: messageEncrypted)
        let encryptedBase64 = data.base64EncodedString()
        print ("ciphered aes key \(encryptedBase64)")
        return encryptedBase64
    }
    
 
    public func decryptWithAes (key: String, iv: String, cipherText: String) -> String? {
        let dKey = Data.init(base64Encoded: key)!
        let dIv = Data.init(base64Encoded: iv)!
        let msg = Data.init(base64Encoded: cipherText)!
        let decryptedData = AESCrypt(message: msg, key: dKey, iv: dIv, operation: kCCDecrypt)
        
        var clearText = String(decoding: decryptedData, as: UTF8.self)
        clearText = clearText.replacingOccurrences(of: "\0", with: "")
        print ("final message in the clear \(clearText)")
        return clearText
    }
    
 
    
    public func encryptWithAES (message: String) throws -> (String?, String?, String?) {
        print ("encrypt \(message)")
        if let clearData = message.data(using: .utf8) {
            let key = randomData(length: 32)
            let iv = randomData(length: 16)
 
            
            let encryptedData = AESCrypt(message: clearData, key: key, iv: iv, operation: kCCEncrypt)
        
            // return the key, iv, and ciphertext all as b64 string
            let keyB64: String? = key.base64EncodedString()
            let ivb64: String? = iv.base64EncodedString()
            let cipherTextb64: String? = encryptedData.base64EncodedString()
            return (keyB64, ivb64, cipherTextb64)
        } else {
            NSLog("unable to convert message to data \(message)")
            return (nil, nil, nil)
        }
        
    }
    
    private func AESCrypt(message: Data, key:Data, iv:Data, operation:Int) -> Data {
        let cryptLength  = size_t(message.count + kCCBlockSizeAES128)
        var cryptData = Data(count:cryptLength)
        let keyLength = size_t(kCCKeySizeAES256)
        let options   = CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding)
      
      
        var numBytesEncrypted :size_t = 0
      
        let cryptStatus: CCCryptorStatus = cryptData.withUnsafeMutableBytes {cryptBytes in
            message.withUnsafeBytes {dataBytes in
                iv.withUnsafeBytes {ivBytes in
                    key.withUnsafeBytes {keyBytes in
                        CCCrypt(CCOperation(operation), CCAlgorithm(kCCAlgorithmAES), options, keyBytes, keyLength,
                                ivBytes, dataBytes, message.count, cryptBytes, cryptLength, &numBytesEncrypted)
                        }
                    }
            }
        }
        NSLog(cryptStatus.description)
        if (cryptStatus == kCCSuccess) {
        cryptData.removeSubrange(numBytesEncrypted..<cryptData.count)
      } else {
            NSLog("Error with AES: \(cryptStatus)")
            NSLog(SecCopyErrorMessageString( cryptStatus, nil) as! String)
      }
      return cryptData;
    }
    
    
    private func randomData(length: Int) -> Data {
        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes { mutableBytes in
            SecRandomCopyBytes(kSecRandomDefault, length, mutableBytes)
        }
        assert (status == Int32(0))
        return data
    }
    
    private func deleteKey(keyTag: String, keyType: String) -> Bool {
        let query: [String: Any] = [
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
      
    
    private func getIdentityRsaVerifPubKeyPemFromKeyRing() {
        identityRSAVerifPrivateKeyHandle = getPrivKeyHandle(keyTag: IDENTITY_RSA_VERIF_PRIVATE_KEY_TAG, canDecrypt: false, keyType: kSecAttrKeyTypeRSA)
        if (identityRSAVerifPrivateKeyHandle != nil) {
            // get the pub key from the priv key
            identityRSAPublicKeyRaw = SecKeyCopyPublicKey(identityRSAVerifPrivateKeyHandle!)
            if (identityRSAPublicKeyRaw != nil) {
                identityRSAVerifPubKeyPem = convertRSAKeyToPemBase64(key: identityRSAPublicKeyRaw!)
                identityRSAVerifPubKeyPem = identityRSAVerifPubKeyPem!.replacingOccurrences(of: "\n", with: "")
                NSLog("identity RSA Verification Key recovered from Keychain")
            }
        }
    }
    
    private func getAgentRsaVerifPubKeyPemFromKeyRing() {
        agentRSAVerifPrivateKeyHandle = getPrivKeyHandle(keyTag: AGENT_RSA_VERIF_PRIVATE_KEY_TAG, canDecrypt: false, keyType: kSecAttrKeyTypeRSA)
        if (agentRSAVerifPrivateKeyHandle != nil) {
            // get the pub key from the priv key
            agentRSAPublicKeyRaw = SecKeyCopyPublicKey(agentRSAVerifPrivateKeyHandle!)
            if (agentRSAPublicKeyRaw != nil) {
                agentRSAVerifPubKeyPem = convertRSAKeyToPemBase64(key: agentRSAPublicKeyRaw!)
                agentRSAVerifPubKeyPem = agentRSAVerifPubKeyPem!.replacingOccurrences(of: "\n", with: "")
                NSLog("agent RSA Verification Key recovered from Keychain")
            }
        }
    }
    
    private func rekey() {
        makeAgentDidGuid()
        makeIdentityDidGuid()
        makeIdentityEcKey()
        makeAgentEcKey()
        makeAgentRsaVerifKey()
        makeIdentityRsaVerifKey()
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
    
    private func makeAgentRsaVerifKey() {
        (agentRSAVerifPrivateKeyHandle, agentRSAPublicKeyRaw) = createRSAKey(privateTag: AGENT_RSA_VERIF_PRIVATE_KEY_TAG, publicTag: AGENT_RSA_VERIF_PUBLIC_KEY_TAG)
        agentRSAVerifPubKeyPem = convertRSAKeyToPemBase64(key: agentRSAPublicKeyRaw!)
        agentRSAVerifPubKeyPem = agentRSAVerifPubKeyPem?.replacingOccurrences(of: "\n", with: "")
    }

    private func makeIdentityRsaVerifKey() {
        (identityRSAVerifPrivateKeyHandle, identityRSAPublicKeyRaw) = createRSAKey(privateTag: IDENTITY_RSA_VERIF_PRIVATE_KEY_TAG, publicTag: IDENTITY_RSA_VERIF_PUBLIC_KEY_TAG)
        identityRSAVerifPubKeyPem = convertRSAKeyToPemBase64(key: identityRSAPublicKeyRaw!)
        identityRSAVerifPubKeyPem = identityRSAVerifPubKeyPem?.replacingOccurrences(of: "\n", with: "")
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
          kSecAttrKeySizeInBits as String: RSA_KEY_SIZE,
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

public extension Data {

    init?(base58Decoding string: String, alphabet: [UInt8] = Base58String.btcAlphabet) {
        var answer = BigUInt(0)
        var j = BigUInt(1)
        let radix = BigUInt(alphabet.count)
        let byteString = [UInt8](string.utf8)

        for ch in byteString.reversed() {
            if let index = alphabet.index(of: ch) {
                answer = answer + (j * BigUInt(index))
                j *= radix
            } else {
                return nil
            }
        }

        let bytes = answer.serialize()
        self = byteString.prefix(while: { i in i == alphabet[0]}) + bytes
    }

}
