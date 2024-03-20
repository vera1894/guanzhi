//
//  MessageInputViewModel.swift
//  guanzhi
//
//  Created by Vera on 2024/3/20.
//

import Foundation
//输入框
class MessageinputViewModel: ObservableObject{
    
    struct codeModel: Identifiable,Hashable{
        let id = UUID()
        var code : String = ""
    }
    
    @Published var firstCode = codeModel()
    @Published var secondCode = codeModel()
    @Published var thirdCode = codeModel()
    @Published var fourthCode = codeModel()
    @Published var text = "" {
        didSet {
            firstCode.code = getStr(text: text, offset: 0)
            secondCode.code = getStr(text: text, offset: 1)
            thirdCode.code = getStr(text: text, offset: 2)
            fourthCode.code = getStr(text: text, offset: 3)
            if text.count > 4 {
                text.removeLast()
            }
            print("text值:",text)
        }
    }
    
    func getStr(text: String, offset: Int) -> String {
        guard text.count > offset else { return "" }
        return String(Array(text)[offset])
    }
}
