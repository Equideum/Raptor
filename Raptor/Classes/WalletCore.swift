//
//  WalletCore.swift
//  Raptor
//
//  Created by tom danner on 5/8/20.
//

import Foundation
import SwiftyJSON

public class WalletCore {
    
    private var wallet: [String : [String : WalletItem]] = [ : ]
    
    public init() {}
    
    public func  addBase64EncodedJWC(base64JWC: String) {
        do {
            let walletItem = try WalletItem (jwc: base64JWC)
            let iss = walletItem.getIss()
            let id = walletItem.getId()
            var credDict: [String: WalletItem]? = wallet[iss]
            if credDict == nil { credDict = [ : ] }
            credDict![id]=walletItem
            wallet[iss]=credDict
            saveWallet()
        } catch  {
            NSLog("TODO - Unable to create a wallet item")
        }
    }
    
    public func saveWallet () {
        var flatDict: [String: String] = [:]
        // unwind the wallet into a flat dict of JSON strings
        for (issuerId, credList) in wallet {
            for (credId, walletItem) in credList {
                flatDict[issuerId+"|"+credId]=walletItem.getRawCredential()
            }
        }
        let def: UserDefaults = UserDefaults.standard
        def.set(flatDict, forKey: "fhirblocksWallet")
    }
       
       
    public func clearWallet () {
        NSLog("Initializing wallet clear")
        wallet = [ : ]
        let flatDict: [String: String] = [:]
        let def: UserDefaults = UserDefaults.standard
        def.set(flatDict, forKey: "fhirblocksWallet")
        NSLog("Wallet cleared")
    }
       
       
    public func loadWallet () {
        // using IOS tooling, read the flattened wallet  (flatDict) back into the Wallet Engine
        var flatDict: [String: String] = [:]
        let def:UserDefaults = UserDefaults.standard
        let ur:NSDictionary? = def.object(forKey: "fhirblocksWallet") as? NSDictionary;
        if(ur == nil) {
            flatDict = [:]
        } else {
            flatDict = NSMutableDictionary(dictionary: ur!) as! [String : String]
        }
           
        // with the flatDict in hand recreate the data structure we need for a proper wallet
        wallet = [ : ]
        for (_, rawCredential) in flatDict {
            addBase64EncodedJWC(base64JWC: rawCredential)
        }  // end of for loop
    }
    
  
    
}
