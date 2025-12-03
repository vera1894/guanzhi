import request from './request'

// ==================== TypeScript 接口定义 ====================

/**
 * 分享查询详情接口
 * TODO: 等待后端实现 GET /api/admin/inspector/share/{shareId}
 *
 * 数据类型说明（已对齐后端 GuanzhiDO）:
 * - status: 0=NORMAL, 1=FADED, 2=HIDDEN, 3=ILLEGAL
 * - officialMark: 0=None, 1=Good, 2=Bad
 * - tagType: "POSITIVE" | "NEGATIVE" (字符串)
 */
export interface ShareInspectorDetail {
  shareId: string
  userId: string
  createdAt: string
  status: 0 | 1 | 2 | 3  // 0=NORMAL, 1=FADED, 2=HIDDEN, 3=ILLEGAL
  location?: {
    lat: number
    lng: number
    address?: string
  }

  // 互动统计（字段名对齐后端数据库）
  viewUserCount?: number
  recentViewUserCount?: number
  agreeCount?: number      // 赞同数（后端字段名）
  neutralCount?: number    // 无感数（后端字段名）
  commentCount?: number
  checkinCount?: number

  // 标签
  tags?: Array<{
    tagCode: string
    tagName: string
    tagType: 'POSITIVE' | 'NEGATIVE'  // 字符串类型
    operatorUserId?: string
  }>

  // 褪色相关
  fadeScore?: number
  isFaded?: boolean
  officialMark?: 0 | 1 | 2  // 0=None, 1=Good, 2=Bad

  // 违法/举报信息
  illegalFlag?: boolean
  reportCount?: number
}

/**
 * 用户查询详情接口
 * TODO: 等待后端实现 GET /api/admin/inspector/user/{userId}
 *
 * 数据类型说明（已对齐后端 UserDO）:
 * - status: 0=NORMAL, 1=WARNED, 2=FROZEN
 * - levelCode: "YOMIN" | "CHONGLANG" | "QIANSHUI" | "LANDONG" | "SHUIMU" | "DENGTA" (字符串)
 * - pointsTotal: 累计总积分（后端字段名）
 */
export interface UserInspectorDetail {
  userId: string
  nickname?: string
  createdAt?: string
  status: 0 | 1 | 2  // 0=NORMAL, 1=WARNED, 2=FROZEN

  // 积分 & 等级（字段名对齐后端数据库）
  pointsTotal?: number  // 后端字段名为 points_total
  levelCode?: string    // YOMIN, CHONGLANG, QIANSHUI, LANDONG, SHUIMU, DENGTA
  levelName?: string

  // 行为统计
  shareCount?: number
  viewCount?: number
  likeCount?: number
  dislikeCount?: number
  checkinCount?: number
  commentCount?: number
  taggedShareCount?: number   // 被贴标签的分享数

  // 奖章（如果有）
  medals?: Array<{
    medalCode: string
    medalName: string
    obtainedAt: string
  }>
}

// ==================== API 请求函数 ====================

/**
 * 查询分享详情
 * @param shareId 分享ID
 * @returns 分享详细信息
 *
 * TODO: 等待后端实现此接口
 * 接口地址: GET /api/admin/inspector/share/{shareId}
 *
 * 当前状态: 前端已实现，后端接口待开发
 */
export function fetchShareInspectorDetail(shareId: string) {
  return request.get<any, { datas: ShareInspectorDetail }>(`/admin/inspector/share/${shareId}`)
    .catch(error => {
      console.error('[ShareInspector] fetch failed', shareId, error)

      // TODO: 后端实现后，需要区分两种404情况：
      // 1. 接口未实现（路由不存在） → 提示"功能开发中"
      // 2. 业务数据不存在（shareId无效） → 提示"未找到该分享"
      // 建议：后端返回统一错误码，如 code=404 表示接口未实现，code=1001 表示数据不存在
      if (error.response?.status === 404) {
        throw new Error('后端接口尚未实现：/api/admin/inspector/share/{shareId}')
      }

      throw error
    })
}

/**
 * 查询用户详情
 * @param userId 用户ID
 * @returns 用户详细信息
 *
 * TODO: 等待后端实现此接口
 * 接口地址: GET /api/admin/inspector/user/{userId}
 *
 * 当前状态: 前端已实现，后端接口待开发
 */
export function fetchUserInspectorDetail(userId: string) {
  return request.get<any, { datas: UserInspectorDetail }>(`/admin/inspector/user/${userId}`)
    .catch(error => {
      console.error('[UserInspector] fetch failed', userId, error)

      // TODO: 后端实现后，需要区分两种404情况：
      // 1. 接口未实现（路由不存在） → 提示"功能开发中"
      // 2. 业务数据不存在（userId无效） → 提示"未找到该用户"
      // 建议：后端返回统一错误码，如 code=404 表示接口未实现，code=1001 表示数据不存在
      if (error.response?.status === 404) {
        throw new Error('后端接口尚未实现：/api/admin/inspector/user/{userId}')
      }

      throw error
    })
}
