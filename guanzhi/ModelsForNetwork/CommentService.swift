//
//  CommentService.swift
//  guanzhi
//
//  Created by Claude Code on 2024/12/23.
//  评论系统 API 服务
//

import Foundation

class CommentService {
    static let shared = CommentService()

    private init() {}

    // MARK: - 获取评论列表

    func fetchComments(
        shareId: Int64,
        order: CommentSortOrder,
        offset: Int,
        limit: Int
    ) async throws -> [CommentViewData] {
        print("📝 CommentService: 获取评论列表 shareId=\(shareId), order=\(order.rawValue)")

        let data = try await OTONetwork.request(
            .fetchComments(shareId: shareId, order: order.rawValue, offset: offset, limit: limit)
        )

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<[CommentViewData]>.self, from: data)

        if response.respCode == 0 {
            print("✅ 获取评论列表成功，共 \(response.datas?.count ?? 0) 条")
            return response.datas ?? []
        } else {
            print("❌ 获取评论列表失败: \(response.respMsg ?? "")")
            throw OTONetworkError.customError(response.respMsg ?? "获取评论失败")
        }
    }

    // MARK: - 获取回复列表

    func fetchReplies(
        commentId: Int64,
        offset: Int,
        limit: Int
    ) async throws -> [ReplyViewData] {
        print("📝 CommentService: 获取回复列表 commentId=\(commentId)")

        let data = try await OTONetwork.request(
            .fetchReplies(commentId: commentId, offset: offset, limit: limit)
        )

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<[ReplyViewData]>.self, from: data)

        if response.respCode == 0 {
            print("✅ 获取回复列表成功，共 \(response.datas?.count ?? 0) 条")
            return response.datas ?? []
        } else {
            print("❌ 获取回复列表失败: \(response.respMsg ?? "")")
            throw OTONetworkError.customError(response.respMsg ?? "获取回复失败")
        }
    }

    // MARK: - 发表评论/回复

    func createComment(
        shareId: Int64,
        content: String,
        parentId: Int64?,
        replyToUserId: Int64?
    ) async throws -> CommentViewData {
        print("📝 CommentService: 发表评论 shareId=\(shareId), parentId=\(String(describing: parentId))")

        let data = try await OTONetwork.request(
            .createComment(shareId: shareId, content: content, parentId: parentId, replyToUserId: replyToUserId)
        )

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<CommentViewData>.self, from: data)

        if response.respCode == 0, let comment = response.datas {
            print("✅ 发表评论成功，评论ID: \(comment.id)")
            return comment
        } else {
            print("❌ 发表评论失败: \(response.respMsg ?? "")")
            throw OTONetworkError.customError(response.respMsg ?? "发表评论失败")
        }
    }

    // MARK: - 删除评论

    func deleteComment(commentId: Int64) async throws {
        print("📝 CommentService: 删除评论 commentId=\(commentId)")

        let data = try await OTONetwork.request(.deleteComment(commentId: commentId))

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<EmptyData>.self, from: data)

        if response.respCode == 0 {
            print("✅ 删除评论成功")
        } else {
            print("❌ 删除评论失败: \(response.respMsg ?? "")")
            throw OTONetworkError.customError(response.respMsg ?? "删除评论失败")
        }
    }

    // MARK: - 点赞评论

    func likeComment(commentId: Int64) async throws {
        print("📝 CommentService: 点赞评论 commentId=\(commentId)")

        let data = try await OTONetwork.request(.likeComment(commentId: commentId))

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<EmptyData>.self, from: data)

        if response.respCode == 0 {
            print("✅ 点赞成功")
        } else {
            print("❌ 点赞失败: \(response.respMsg ?? "")")
            throw OTONetworkError.customError(response.respMsg ?? "点赞失败")
        }
    }

    // MARK: - 取消点赞

    func unlikeComment(commentId: Int64) async throws {
        print("📝 CommentService: 取消点赞 commentId=\(commentId)")

        let data = try await OTONetwork.request(.unlikeComment(commentId: commentId))

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<EmptyData>.self, from: data)

        if response.respCode == 0 {
            print("✅ 取消点赞成功")
        } else {
            print("❌ 取消点赞失败: \(response.respMsg ?? "")")
            throw OTONetworkError.customError(response.respMsg ?? "取消点赞失败")
        }
    }

    // MARK: - 获取评论上下文（精准定位）

    func getCommentContext(commentId: Int64) async throws -> CommentContextResponse {
        print("📝 CommentService: 获取评论上下文 commentId=\(commentId)")

        let data = try await OTONetwork.request(.getCommentContext(commentId: commentId))

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<CommentContextResponse>.self, from: data)

        if response.respCode == 0, let context = response.datas {
            print("✅ 获取评论上下文成功")
            return context
        } else {
            print("❌ 获取评论上下文失败: \(response.respMsg ?? "")")
            throw OTONetworkError.customError(response.respMsg ?? "获取评论上下文失败")
        }
    }
}
