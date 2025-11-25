import Foundation

/// Provides a centralized switch to enable or disable mock data for previews and debugging.
enum PreviewHarness {
    /// Checks if the "MOCK_DATA_ENABLED" launch argument is present.
    static var useMock: Bool {
        ProcessInfo.processInfo.arguments.contains("MOCK_DATA_ENABLED")
    }

    /// Checks if running in an Xcode Preview canvas.
    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// Unified switch: returns true if either in Xcode Preview or the launch argument is set.
    static var enabled: Bool {
        return useMock || isPreview
    }
}
