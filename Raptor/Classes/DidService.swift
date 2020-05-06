//
//  DidService.swift
//  Whistler
//
//  Created by tom danner on 4/8/20.
//  Copyright © 2020 tom danner. All rights reserved.
//



public struct DidService{

    var id:String=""
    var type: String=""
    var serviceEndpoint: String=""
    
    
   
    
    public func toJSONString () -> String {
        let x = "{\"id\": \""+id+"\",\"type\": \""+type+"\",\"serviceEndpoint\": \""+serviceEndpoint+"\"}"
        return x
    }
}

