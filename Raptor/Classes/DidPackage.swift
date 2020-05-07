//
//  DidPackage.swift
//  Alamofire
//
//  Created by tom danner on 5/7/20.
//

import Foundation

public struct DidPackage {
    var context: String? = ""
    var type: String? = ""
    var record: DidDocument? = nil
    var proof: Proof? = nil

    

    public func toJSONString () -> String {
        var x = "\"@context\": \""+context!+"\", "
        x = x + "\"type\": \"" + type! + "\", "
        x = x + "\"record\": " + record!.toJSONString() + ", "
        x = x + "\"proof\": " + proof!.toJSONString()
        x = "{"+x+"}"
        return x
    }
}
