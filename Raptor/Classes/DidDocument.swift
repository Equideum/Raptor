//
//  FBDidDocument.swift
//  Whistler
//
//  Created by tom danner on 4/8/20.
//  Copyright © 2020 tom danner. All rights reserved.
//

import Foundation
import SwiftyJSON

struct DidDocument  {

    var did: String = ""
    var service: [String: DidService] = [:]
    var authentication: [String: DidAuthentication] = [:]
    var name: String = ""
    var active: Bool = false
    

    
    public init() {}
    
    public init(jsonRepresentation: JSON) {
        NSLog("creating did document from json")
        name = jsonRepresentation["name"].string!
        did = jsonRepresentation["did"].string!
        active=jsonRepresentation["active"].boolValue
        authentication = getAuthentications(authentications: jsonRepresentation["authentication"].array)
        service = getServices(services: jsonRepresentation["service"].array)
    }
    

    
    private func getAuthentications(authentications: [JSON]?) -> [String: DidAuthentication] {
        if (authentications == nil) {return [:]}
        var resp: [String: DidAuthentication] = [:]
        for authentication in authentications! {
            var x = DidAuthentication()
            x.id = authentication["id"].string
            x.controller = authentication["controller"].string
            x.publicKeyPem = authentication["publicKeyPem"].string
            x.type = authentication["type"].string
            if (x.id != nil) {
                resp[x.id!]=x
            }
        }
        return resp
    }
    
    private func getServices(services: [JSON]?) -> [String: DidService] {
        if (services == nil) { return [:] }
        var resp: [String: DidService] = [:]
        for service in services! {
            var x = DidService()
            x.id = service["id"].string!
            x.serviceEndpoint = service["serviceEndpoint"].string!
            x.type = service["type"].string!
         
            resp[x.id]=x
         
        }
        return resp
    }
    
    public func toJSONString() -> String {
        var first = true
        var auths = ""
        for auth in self.authentication {
            var x = auth.value.toJSONString()
            if (!first) {
                x = ", "+x
            } else {
                first = false
            }
            auths = auths+x
        }
        auths = "["+auths+"]"
        
        first = true
        var svc = ""
        for service in self.service {
            var x = service.value.toJSONString()
            if (!first) {
                x = ", "+x
            } else {
                first = false
            }
            svc = svc + x
        }
        svc = "["+svc+"]"

        var activeStrg = "false"
        if (self.active) {activeStrg = "true"}
        
        var theDoc: String = "\"did\": \"" + self.did + "\", "
        theDoc = theDoc + "\"active\": \"" + activeStrg + "\", "
        theDoc = theDoc + "\"name\": \"" + self.name + "\", "
        theDoc = theDoc + "\"service\": " + svc + ", "
        theDoc = theDoc + "\"authentication\": " + auths
        
        theDoc = "{"+theDoc+"}"
        return theDoc
    }
}
