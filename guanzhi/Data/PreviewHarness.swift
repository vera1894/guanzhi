//
//  PreviewHarness.swift
//  guanzhi
//
//  Created by Gemini on 2025/11/25.
//

import Foundation

/// Provides a centralized switch to enable or disable mock data for previews and debugging.
/// This works for both Xcode Previews and on-device/simulator runs.
enum PreviewHarness {
    /// Checks if the "MOCK_DATA_ENABLED" launch argument is present.
    static var useMock: Bool {
        ProcessInfo.processInfo.arguments.contains("MOCK_DATA_ENABLED")
    }
}
