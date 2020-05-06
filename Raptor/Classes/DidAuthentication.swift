//  FBAuthentication
//
//  Created by tom danner on 4/8/20.
//  Copyright © 2020 tom danner. All rights reserved.
//

struct DidAuthentication {

    var id: String? = ""
    var type: String? = ""
    var controller:  String? = ""
    var publicKeyPem: String? = ""

    
    public func toJSONString() -> String {
        var x = "\"id\": \""+id!+"\", "
        x = x + "\"type\": \""+type!+"\", "
        x = x + "\"controller\": \""+controller!+"\", "
        x = x + "\"publicKeyPem\": \""+publicKeyPem!+"\""
        x = "{"+x+"}"
        return x
    }
}

