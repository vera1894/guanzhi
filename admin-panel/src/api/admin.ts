import request from './request'

export interface FadeSimulationRequest {
  viewCount: number
  tagCount: number
  simulateDays?: number
}

export interface FadeSimulationResponse {
  currentFadeScore: number
  estimatedFadeDays: number
  timeline: number[]
  fadeScores: number[]
  dailyFadeIncrement: number
  configInfo: string
}

export interface FadeConfig {
  id: number
  configKey: string
  configValue: string
  description: string
}

export interface LevelDefinition {
  id?: number
  levelCode: string
  levelName: string
  minPoints: number
  minCheckins?: number      // 最小打卡数
  minComments?: number      // 最小评论数
  taggingAllowance?: number // 打标签权限
  extraConditions?: string  // 额外条件
}

export interface PointsRule {
  id?: number
  actionType: string
  pointsValue: number
  dailyLimit?: number
}

export interface TagDefinition {
  id?: number
  tagCode: string      // 标签键（拼音形式，如 MIJING）
  tagName: string      // 标签名称（中文，如"秘境"）
  tagType: string      // 标签类型：POSITIVE（正面）或 NEGATIVE（负面）
  minLevelCode?: string // 最低等级要求
  isActive?: boolean    // 是否激活
  sortOrder?: number    // 排序顺序
}

export function simulateFadeScore(data: FadeSimulationRequest) {
  return request.post<any, { datas: FadeSimulationResponse }>('/admin/fade/simulate', data)
}

export function getFadeConfigs() {
  return request.get<any, { datas: Record<string, string> }>('/admin/config/fade-configs')
}

export function saveFadeConfig(data: FadeConfig) {
  return request.post('/admin/config/fade-config', data)
}

export function getLevelDefinitions() {
  return request.get<any, { datas: LevelDefinition[] }>('/admin/config/levels')
}

export function saveLevelDefinition(data: LevelDefinition) {
  return request.post('/admin/config/level', data)
}

export function deleteLevelDefinition(id: number) {
  return request.delete(`/admin/config/level/${id}`)
}

export function getPointsRules() {
  return request.get<any, { datas: PointsRule[] }>('/admin/config/points-rules')
}

export function savePointsRule(data: PointsRule) {
  return request.post('/admin/config/points-rule', data)
}

export function deletePointsRule(id: number) {
  return request.delete(`/admin/config/points-rule/${id}`)
}

export function getTagDefinitions() {
  return request.get<any, { datas: TagDefinition[] }>('/admin/config/tags')
}

export function saveTagDefinition(data: TagDefinition) {
  return request.post('/admin/config/tag', data)
}

export function deleteTagDefinition(id: number) {
  return request.delete(`/admin/config/tag/${id}`)
}
