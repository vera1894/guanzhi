//
//  DataLoadingState.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/2.
//  数据加载状态 - 网络重试机制核心组件
//

import Foundation

/// 数据加载状态枚举
/// - 规范 1：状态机必须存在，每个主数据加载必须有 state
enum DataLoadingState<T> {
    /// 初始状态，未开始加载
    case idle
    /// 加载中
    case loading
    /// 加载成功
    case loaded(T)
    /// 加载失败
    case error(Error)

    // MARK: - 便捷属性

    /// 是否正在加载
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    /// 是否有错误
    var hasError: Bool {
        if case .error = self { return true }
        return false
    }

    /// 是否已加载成功
    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    /// 是否为初始状态
    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    /// 获取已加载的数据（如果有）
    var data: T? {
        if case .loaded(let data) = self {
            return data
        }
        return nil
    }

    /// 获取错误（如果有）
    var error: Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }

    /// 错误描述
    var errorMessage: String? {
        if case .error(let error) = self {
            return error.localizedDescription
        }
        return nil
    }
}

// MARK: - Equatable（用于比较状态类型，不比较关联值）
extension DataLoadingState {
    /// 检查两个状态是否是同一类型（不比较关联值）
    func isSameCase(as other: DataLoadingState) -> Bool {
        switch (self, other) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.loaded, .loaded): return true
        case (.error, .error): return true
        default: return false
        }
    }
}
