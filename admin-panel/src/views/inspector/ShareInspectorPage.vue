<script setup lang="ts">
import { ref } from 'vue'
import { ElMessage } from 'element-plus'
import { fetchShareInspectorDetail, type ShareInspectorDetail } from '../../api/inspector'

const shareIdInput = ref('')
const loading = ref(false)
const shareDetail = ref<ShareInspectorDetail | null>(null)
const errorMessage = ref('')

const handleQuery = async () => {
  // 前端校验
  if (!shareIdInput.value || !shareIdInput.value.trim()) {
    ElMessage.warning('请输入分享ID')
    return
  }

  loading.value = true
  errorMessage.value = ''
  shareDetail.value = null

  try {
    const response = await fetchShareInspectorDetail(shareIdInput.value.trim())
    shareDetail.value = response.datas
    ElMessage.success('查询成功')
  } catch (error: any) {
    console.error('[ShareInspectorPage] Query failed:', error)

    // 处理不同的错误情况
    if (error.message && error.message.includes('后端接口尚未实现')) {
      errorMessage.value = '⚠️ 后端接口尚未实现，请等待后端开发完成'
      ElMessage.warning('后端接口尚未实现')
    } else if (error.response?.status === 404) {
      errorMessage.value = `未找到分享ID为 ${shareIdInput.value} 的数据`
      ElMessage.error('未找到该分享')
    } else {
      errorMessage.value = error.message || '查询失败，请稍后重试'
    }
  } finally {
    loading.value = false
  }
}

// 后端使用数字存储状态：0=NORMAL, 1=FADED, 2=HIDDEN, 3=ILLEGAL
const getStatusText = (status?: number) => {
  const statusMap: Record<number, string> = {
    0: '正常',
    1: '已褪色',
    2: '已隐藏',
    3: '违法内容'
  }
  return status !== undefined ? (statusMap[status] || `未知状态(${status})`) : '-'
}

const getStatusType = (status?: number) => {
  const typeMap: Record<number, string> = {
    0: 'success',
    1: 'warning',
    2: 'info',
    3: 'danger'
  }
  return status !== undefined ? (typeMap[status] || 'info') : 'info'
}

// 后端使用数字存储官方标记：0=None, 1=Good, 2=Bad
const getOfficialMarkText = (mark?: number) => {
  const markMap: Record<number, string> = {
    0: '无标记',
    1: '官方推荐',
    2: '官方警告'
  }
  return mark !== undefined ? (markMap[mark] || `未知标记(${mark})`) : '-'
}

const getOfficialMarkType = (mark?: number) => {
  const typeMap: Record<number, string> = {
    0: 'info',
    1: 'success',
    2: 'danger'
  }
  return mark !== undefined ? (typeMap[mark] || 'info') : 'info'
}
</script>

<template>
  <div class="page-container">
    <el-card class="search-card">
      <template #header>
        <div class="card-header">
          <span class="card-title">分享查询</span>
        </div>
      </template>

      <div class="search-form">
        <el-input
          v-model="shareIdInput"
          placeholder="请输入分享ID"
          clearable
          @keyup.enter="handleQuery"
          style="width: 400px; margin-right: 16px;"
        >
          <template #prepend>分享ID</template>
        </el-input>
        <el-button type="primary" @click="handleQuery" :loading="loading">
          查询
        </el-button>
      </div>

      <!-- 错误提示 -->
      <el-alert
        v-if="errorMessage && !loading"
        :title="errorMessage"
        type="warning"
        :closable="false"
        show-icon
        style="margin-top: 16px;"
      />
    </el-card>

    <!-- 加载状态 -->
    <div v-if="loading" v-loading="loading" style="min-height: 200px; margin-top: 20px;"></div>

    <!-- 查询结果 -->
    <div v-if="shareDetail && !loading" class="result-container">
      <!-- 基本信息卡片 -->
      <el-card class="info-card">
        <template #header>
          <span class="card-title">基本信息</span>
        </template>

        <el-descriptions :column="2" border>
          <el-descriptions-item label="分享ID">
            {{ shareDetail.shareId }}
          </el-descriptions-item>
          <el-descriptions-item label="用户ID">
            {{ shareDetail.userId }}
          </el-descriptions-item>
          <el-descriptions-item label="创建时间">
            {{ shareDetail.createdAt || '-' }}
          </el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="getStatusType(shareDetail.status)">
              {{ getStatusText(shareDetail.status) }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="经度" v-if="shareDetail.location">
            {{ shareDetail.location.lng }}
          </el-descriptions-item>
          <el-descriptions-item label="纬度" v-if="shareDetail.location">
            {{ shareDetail.location.lat }}
          </el-descriptions-item>
          <el-descriptions-item label="地址" :span="2" v-if="shareDetail.location?.address">
            {{ shareDetail.location.address }}
          </el-descriptions-item>
        </el-descriptions>
      </el-card>

      <!-- 互动统计卡片 -->
      <el-card class="info-card">
        <template #header>
          <span class="card-title">互动统计</span>
        </template>

        <el-row :gutter="20">
          <el-col :span="8">
            <div class="stat-item">
              <div class="stat-value">{{ shareDetail.viewUserCount ?? '-' }}</div>
              <div class="stat-label">浏览人数</div>
            </div>
          </el-col>
          <el-col :span="8">
            <div class="stat-item">
              <div class="stat-value">{{ shareDetail.recentViewUserCount ?? '-' }}</div>
              <div class="stat-label">最近浏览人数</div>
            </div>
          </el-col>
          <el-col :span="8">
            <div class="stat-item">
              <div class="stat-value text-success">{{ shareDetail.agreeCount ?? '-' }}</div>
              <div class="stat-label">赞同数</div>
            </div>
          </el-col>
        </el-row>

        <el-row :gutter="20" style="margin-top: 20px;">
          <el-col :span="8">
            <div class="stat-item">
              <div class="stat-value text-info">{{ shareDetail.neutralCount ?? '-' }}</div>
              <div class="stat-label">无感数</div>
            </div>
          </el-col>
          <el-col :span="8">
            <div class="stat-item">
              <div class="stat-value">{{ shareDetail.commentCount ?? '-' }}</div>
              <div class="stat-label">评论数</div>
            </div>
          </el-col>
          <el-col :span="8">
            <div class="stat-item">
              <div class="stat-value">{{ shareDetail.checkinCount ?? '-' }}</div>
              <div class="stat-label">打卡数</div>
            </div>
          </el-col>
        </el-row>
      </el-card>

      <!-- 标签与褪色卡片 -->
      <el-card class="info-card">
        <template #header>
          <span class="card-title">标签与褪色信息</span>
        </template>

        <el-descriptions :column="2" border>
          <el-descriptions-item label="褪色分数">
            <span :class="{ 'text-danger': (shareDetail.fadeScore ?? 0) > 80 }">
              {{ shareDetail.fadeScore ?? '-' }}
            </span>
          </el-descriptions-item>
          <el-descriptions-item label="是否已褪色">
            <el-tag :type="shareDetail.isFaded ? 'warning' : 'success'">
              {{ shareDetail.isFaded ? '是' : '否' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="官方标记">
            <el-tag :type="getOfficialMarkType(shareDetail.officialMark)">
              {{ getOfficialMarkText(shareDetail.officialMark) }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="违法标记">
            <el-tag :type="shareDetail.illegalFlag ? 'danger' : 'success'">
              {{ shareDetail.illegalFlag ? '是' : '否' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="举报次数">
            <span :class="{ 'text-danger': (shareDetail.reportCount ?? 0) > 0 }">
              {{ shareDetail.reportCount ?? 0 }}
            </span>
          </el-descriptions-item>
        </el-descriptions>

        <!-- 标签列表 -->
        <div style="margin-top: 20px;" v-if="shareDetail.tags && shareDetail.tags.length > 0">
          <div style="margin-bottom: 8px; font-weight: 600;">标签列表</div>
          <el-space wrap>
            <el-tag
              v-for="(tag, index) in shareDetail.tags"
              :key="index"
              :type="tag.tagType === 'POSITIVE' ? 'success' : 'warning'"
              size="large"
            >
              {{ tag.tagName }}
              <span style="font-size: 12px; opacity: 0.8;">
                ({{ tag.tagType === 'POSITIVE' ? '正面' : '负面' }})
              </span>
              <span v-if="tag.operatorUserId" style="font-size: 12px; opacity: 0.6;">
                - 操作人: {{ tag.operatorUserId }}
              </span>
            </el-tag>
          </el-space>
        </div>
        <el-empty v-else-if="shareDetail.tags" description="暂无标签" :image-size="60" />
      </el-card>

      <!-- 原始JSON数据（调试用） -->
      <el-card class="info-card">
        <template #header>
          <span class="card-title">原始数据（调试）</span>
        </template>
        <pre style="background: #f5f7fa; padding: 16px; border-radius: 4px; font-size: 12px; overflow-x: auto;">{{ JSON.stringify(shareDetail, null, 2) }}</pre>
      </el-card>
    </div>
  </div>
</template>

<style scoped>
.page-container {
  padding: 20px;
}

.search-card {
  margin-bottom: 20px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.card-title {
  font-size: 16px;
  font-weight: 600;
}

.search-form {
  display: flex;
  align-items: center;
}

.result-container {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.info-card {
  margin-bottom: 0;
}

.stat-item {
  text-align: center;
  padding: 16px;
  background: #f5f7fa;
  border-radius: 4px;
}

.stat-value {
  font-size: 28px;
  font-weight: 600;
  color: #303133;
}

.stat-label {
  margin-top: 8px;
  font-size: 14px;
  color: #606266;
}

.text-success {
  color: #67c23a;
}

.text-info {
  color: #909399;
}

.text-danger {
  color: #f56c6c;
}
</style>
