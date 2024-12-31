//
//  GeneralFunctions.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/12/31.
//

import SwiftUI
import UIKit


extension UIApplication {  //收起键盘的方法
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
