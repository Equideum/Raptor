//
//  DidService.swift
//  Whistler
//
//  Created by tom danner on 4/8/20.
//  Copyright © 2020 tom danner. All rights reserved.
//

public struct DidService{

    public var id:String=""
    public var type: String=""
    public var serviceEndpoint: String=""
    
    public func toJSONString () -> String {
        let x = "{\"id\": \""+id+"\",\"type\": \""+type+"\",\"serviceEndpoint\": \""+serviceEndpoint+"\"}"
        return x
    }
}

