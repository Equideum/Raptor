//
//  Proof.swift
//  Alamofire
//
//  Created by tom danner on 5/7/20.
//

import Foundation

public struct Proof {
    var type: String?
    var created: String?
    var capability: String?
    var capabilityAction: String?
    var jws: String?
    var proofPurpose: String?
    var creator: String?
    
    public func toJSONString() -> String {
        var x = "\"type\": \""+type!+"\", "
        x = x + "\"created\": \""+created!+"\", "
        x = x + "\"capability\": \""+capability!+"\", "
        x = x + "\"capabilityAction\": \""+capabilityAction!+"\", "
        x = x + "\"jws\": \""+jws!+"\", "
        x = x + "\"proofPurpose\": \""+proofPurpose!+"\", "
        x = x + "\"type\": \""+type!+"\", "
        x = x + "\"creator\": \""+creator!+"\""
        
        x = "{"+x+"}"
        return x
    }
}

