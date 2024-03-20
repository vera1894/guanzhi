//
//  OTOTypes.swift
//  guanzhi
//
//  Created by Vera on 2024/3/20.
//

import Foundation

enum ValidateEnum{
    case phoneNum(_: String)
    case codeName(_:String)
    case nickName(_:String)
 
    var isRight: Bool{
        var predicateStr:String!
        var currObject:String!
        switch self{
        case let .phoneNum(str):
            predicateStr = "^1([358][0-9]|4[579]|66|7[0135678]|9[89])[0-9]{8}$"
            currObject = str
        case let .codeName(str):
            predicateStr = "^(?=.*[a-zA-Z])(?=.*\\d)(?=.*[_-])[a-zA-Z\\d_-]{6,20}$"
            currObject = str
        case let .nickName(str):
            predicateStr = "^[\\u4e00-\\u9fa5a-zA-Z0-9\\W_]{1,32}$"
            currObject = str
        }
        
        let predicate = NSPredicate(format: "SELF MATCHES %@", predicateStr)
        return predicate.evaluate(with: currObject)
    }
    
}
