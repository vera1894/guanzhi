//
//  NetworkDiagnosticView.swift
//  guanzhi
//
//  Created by Claude on 2026/2/14.
//

import SwiftUI

// MARK: - 诊断项模型

struct DiagnosticItem: Identifiable {
    let id = UUID()
    let name: String
    var status: DiagnosticStatus = .pending
    var detail: String = ""
    var elapsed: TimeInterval = 0
}

enum DiagnosticStatus {
    case pending, running, success, failure

    var icon: String {
        switch self {
        case .pending: return "⏳"
        case .running: return "⏳"
        case .success: return "✅"
        case .failure: return "❌"
        }
    }
}

// MARK: - ViewModel

@MainActor
class NetworkDiagnosticViewModel: ObservableObject {
    @Published var items: [DiagnosticItem] = []
    @Published var isRunning = false

    func runAll() {
        guard !isRunning else { return }
        isRunning = true

        items = [
            DiagnosticItem(name: String(localized: "设备信息")),
            DiagnosticItem(name: String(localized: "Token 状态")),
            DiagnosticItem(name: String(localized: "基础连通性")),
            DiagnosticItem(name: String(localized: "用户信息 API")),
            DiagnosticItem(name: String(localized: "分享列表 API")),
        ]

        Task {
            await runDeviceInfo(index: 0)
            await runTokenCheck(index: 1)
            await runConnectivity(index: 2)
            await runUserInfoAPI(index: 3)
            await runShareListAPI(index: 4)
            isRunning = false
        }
    }

    // MARK: - 设备信息

    private func runDeviceInfo(index: Int) async {
        items[index].status = .running
        let start = Date()

        let device = UIDevice.current
        let appVersion = AppVersionManager.fullVersionInfo
        let systemVersion = "\(device.systemName) \(device.systemVersion)"
        let modelName = device.model

        let detail = "App: \(appVersion) | iOS: \(systemVersion) | 设备: \(modelName)"
        items[index].detail = detail
        items[index].elapsed = Date().timeIntervalSince(start)
        items[index].status = .success
    }

    // MARK: - Token 状态

    private func runTokenCheck(index: Int) async {
        items[index].status = .running
        let start = Date()

        let manager = OTOLoginStatusManager.shared
        guard let token = manager.getToken() else {
            items[index].detail = "Token 不存在（未登录）"
            items[index].elapsed = Date().timeIntervalSince(start)
            items[index].status = .failure
            return
        }

        // 脱敏显示
        let masked: String
        if token.count > 16 {
            let prefix = String(token.prefix(8))
            let suffix = String(token.suffix(8))
            masked = "\(prefix)...\(suffix)"
        } else {
            masked = "***"
        }

        // JWT exp 检测
        let isExpired = manager.isTokenExpired()
        let expStr = isExpired ? "已过期" : "有效"

        // 解析 JWT exp 时间
        var expTimeStr = ""
        let parts = token.components(separatedBy: ".")
        if parts.count == 3 {
            var payload = parts[1]
            let remainder = payload.count % 4
            if remainder > 0 {
                payload = payload.padding(toLength: payload.count + 4 - remainder, withPad: "=", startingAt: 0)
            }
            if let data = Data(base64Encoded: payload),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let exp = json["exp"] as? TimeInterval {
                let date = Date(timeIntervalSince1970: exp)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
                expTimeStr = " | 过期时间: \(formatter.string(from: date))"
            }
        }

        items[index].detail = "Token: \(masked) | 状态: \(expStr)\(expTimeStr)"
        items[index].elapsed = Date().timeIntervalSince(start)
        items[index].status = isExpired ? .failure : .success
    }

    // MARK: - 基础连通性 (HEAD 请求)

    private func runConnectivity(index: Int) async {
        items[index].status = .running
        let start = Date()

        guard let url = URL(string: Constants.BASE_HOST) else {
            items[index].detail = "无效的服务器地址"
            items[index].elapsed = Date().timeIntervalSince(start)
            items[index].status = .failure
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            items[index].detail = "HTTP \(statusCode) | 服务器: \(Constants.BASE_HOST)"
            items[index].elapsed = Date().timeIntervalSince(start)
            items[index].status = (200...399).contains(statusCode) ? .success : .failure
        } catch {
            items[index].detail = "连接失败: \(error.localizedDescription)"
            items[index].elapsed = Date().timeIntervalSince(start)
            items[index].status = .failure
        }
    }

    // MARK: - 用户信息 API

    private func runUserInfoAPI(index: Int) async {
        items[index].status = .running
        let start = Date()

        do {
            let data = try await OTONetwork.request(.userInfo)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let respCode = json["respCode"] as? Int ?? -1
                let respMsg = json["respMsg"] as? String ?? ""
                if respCode == 0, let datas = json["datas"] as? [String: Any] {
                    let userId = datas["id"] as? Int ?? -1
                    let nickname = datas["nickname"] as? String ?? "无"
                    items[index].detail = "respCode: \(respCode) | userId: \(userId) | 昵称: \(nickname)"
                    items[index].status = .success
                } else {
                    items[index].detail = "respCode: \(respCode) | msg: \(respMsg)"
                    items[index].status = .failure
                }
            } else {
                items[index].detail = "响应解析失败 | 数据长度: \(data.count) bytes"
                items[index].status = .failure
            }
            items[index].elapsed = Date().timeIntervalSince(start)
        } catch {
            items[index].detail = "请求失败: \(error.localizedDescription)"
            items[index].elapsed = Date().timeIntervalSince(start)
            items[index].status = .failure
        }
    }

    // MARK: - 分享列表 API

    private func runShareListAPI(index: Int) async {
        items[index].status = .running
        let start = Date()

        do {
            // 使用默认坐标（北京）测试
            let data = try await OTONetwork.request(
                .fetchNearbyShareList(latitude: 39.9042, longitude: 116.4074, radius: 50000, size: 5)
            )
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let respCode = json["respCode"] as? Int ?? -1
                let respMsg = json["respMsg"] as? String ?? ""
                if respCode == 0 {
                    // 尝试获取列表数量
                    var count = 0
                    if let datas = json["datas"] as? [[String: Any]] {
                        count = datas.count
                    }
                    items[index].detail = "respCode: \(respCode) | 返回 \(count) 条数据"
                    items[index].status = .success
                } else {
                    items[index].detail = "respCode: \(respCode) | msg: \(respMsg)"
                    items[index].status = .failure
                }
            } else {
                items[index].detail = "响应解析失败 | 数据长度: \(data.count) bytes"
                items[index].status = .failure
            }
            items[index].elapsed = Date().timeIntervalSince(start)
        } catch {
            items[index].detail = "请求失败: \(error.localizedDescription)"
            items[index].elapsed = Date().timeIntervalSince(start)
            items[index].status = .failure
        }
    }

    // MARK: - 复制诊断结果

    func copyReport() -> String {
        var lines: [String] = []
        lines.append("=== 观之网络诊断报告 ===")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        lines.append("时间: \(formatter.string(from: Date()))")
        lines.append("")

        for item in items {
            let elapsed = String(format: "%.0fms", item.elapsed * 1000)
            lines.append("\(item.status.icon) \(item.name) [\(elapsed)]")
            if !item.detail.isEmpty {
                lines.append("   \(item.detail)")
            }
        }

        lines.append("")
        lines.append("=== 报告结束 ===")
        return lines.joined(separator: "\n")
    }
}

// MARK: - View

struct NetworkDiagnosticView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var viewModel = NetworkDiagnosticViewModel()
    @State private var showCopied = false

    var body: some View {
        List {
            ForEach(viewModel.items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.status.icon)
                        Text(item.name)
                            .fontWeight(.medium)
                        Spacer()
                        if item.status != .pending {
                            Text(String(format: "%.0fms", item.elapsed * 1000))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                .padding(.vertical, 4)
            }

            // 复制按钮
            if !viewModel.isRunning && !viewModel.items.isEmpty {
                Section {
                    Button {
                        let report = viewModel.copyReport()
                        UIPasteboard.general.string = report
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopied = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            Text(showCopied ? "已复制" : "复制诊断结果")
                            Spacer()
                        }
                    }

                    Button {
                        viewModel.runAll()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.clockwise")
                            Text("重新检测")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("网络诊断")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        navigationCoordinator.path.removeLast()
                    }) {
                        Image("icon-back")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        navigationCoordinator.path.removeLast()
                    }) {
                        Image("icon-back")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.runAll()
        }
    }
}
