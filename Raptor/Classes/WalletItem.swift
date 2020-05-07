//
//  WalletItem.swift
//  Alamofire
//
//  Created by tom danner on 5/7/20.
//

import Foundation
import SwiftyJSON


public class WalletItem {
    
    private var jsonCredential: JSON
    private var rawCredential: String
    
    
    public init() {
        jsonCredential = JSON()
        rawCredential = ""
    }
    
    public func getJsonCredential() -> JSON {
        return self.getJsonCredential()
    }
}
