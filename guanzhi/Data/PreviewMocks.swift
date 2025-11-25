//
//  PreviewMocks.swift
//  guanzhi
//
//  Created by Gemini on 2025/11/25.
//

import Foundation
import SwiftData

#if DEBUG

// MARK: - Share Convenience Initializer

extension Share {
    /// A convenience initializer for creating Share instances in previews with minimal data.
    convenience init(
        id: Int64,
        createDate: Date,
        userId: Int64,
        data: String,
        longitude: Double,
        latitude: Double,
        address: String,
        title: String
    ) {
        // Call the memberwise initializer, providing default values for missing parameters.
        self.init(
            id: id,
            createDate: createDate,
            userId: userId,
            data: data,
            longitude: longitude,
            latitude: latitude,
            provinceCode: "310000", // Default
            cityCode: "310100", // Default
            districtCode: "310115", // Default
            address: address,
            imagePaths: [], // Default
            title: title,
            deleted: false // Default
        )
    }
}

// MARK: - UserFullInfoModel Convenience Initializer

extension UserFullInfoModel {
    /// A convenience initializer for creating UserFullInfoModel instances in previews.
    init(
        id: Int,
        nickname: String
    ) {
        // Call the memberwise initializer, providing nil for all optional fields.
        self.init(
            id: id,
            createDate: nil,
            code: "MOCK123",
            phone: "13800138000",
            name: nickname,
            nickname: nickname,
            password: nil,
            registerdate: nil,
            lastLoginTime: nil,
            jpushId: nil,
            platform: "iOS",
            photo: nil,
            titleDOS: []
        )
    }
}

#endif
