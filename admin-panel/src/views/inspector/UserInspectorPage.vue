<script setup lang="ts">
import { ref } from 'vue'
import { ElMessage } from 'element-plus'
import { fetchUserInspectorDetail, type UserInspectorDetail } from '../../api/inspector'

const userIdInput = ref('')
const loading = ref(false)
const userDetail = ref<UserInspectorDetail | null>(null)
const errorMessage = ref('')

const handleQuery = async () => {
  // 前端校验
  if (!userIdInput.value || !userIdInput.value.trim()) {
    ElMessage.warning('请输入用户ID')
    return
  }

  loading.value = true
  errorMessage.value = ''
  userDetail.value = null

  try {
    const response = await fetchUserInspectorDetail(userIdInput.value.trim())
    userDetail.value = response.datas
    ElMessage.success('查询成功')
  } catch (error: any) {
    console.error('[UserInspectorPage] Query failed:', error)

    // 处理不同的错误情况
    if (error.message && error.message.includes('后端接口尚未实现')) {
      errorMessage.value = '⚠️ 后端接口尚未实现，请等待后端开发完成'
      ElMessage.warning('后端接口尚未实现')
    } else if (error.response?.status === 404) {
      errorMessage.value = `未找到用户ID为 ${userIdInput.value} 的数据`
      ElMessage.error('未找到该用户')
    } else {
      errorMessage.value = error.message || '查询失败，请稍后重试'
    }
  } finally {
    loading.value = false
  }
}

// 后端使用数字存储状态：0=NORMAL, 1=WARNED, 2=FROZEN
const getStatusText = (status?: number) => {
  const statusMap: Record<number, string> = {
    0: '正常',
    1: '警告中',
    2: '已冻结'
  }
  return status !== undefined ? (statusMap[status] || `未知状态(${status})`) : '-'
}

const getStatusType = (status?: number) => {
  const typeMap: Record<number, string> = {
    0: 'success',
    1: 'warning',
    2: 'danger'
  }
  return status !== undefined ? (typeMap[status] || 'info') : 'info'
}

const getLevelName = (levelCode?: string, levelName?: string) => {
  if (levelName) return levelName

  const levelMap: Record<string, string> = {
    'YOMIN': '游民',
    'CHONGLANG': '冲浪',
    'QIANSHUI': '潜水',
    'LANDONG': '蓝洞',
    'SHUIMU': '水母',
    'DENGTA': '灯塔'
  }
  return levelMap[levelCode || ''] || levelCode || '-'
}
</script>

<template>
  <div class="page-container">
    <el-card class="search-card">
      <template #header>
        <div class="card-header">
          <span class="card-title">用户查询</span>
        </div>
      </template>

      <div class="search-form">
        <el-input
          v-model="userIdInput"
          placeholder="请输入用户ID"
          clearable
          @keyup.enter="handleQuery"
          style="width: 400px; margin-right: 16px;"
        >
          <template #prepend>用户ID</template>
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
    <div v-if="userDetail && !loading" class="result-container">
      <!-- 基本信息卡片 -->
      <el-card class="info-card">
        <template #header>
          <span class="card-title">基本信息</span>
        </template>

        <el-descriptions :column="2" border>
          <el-descriptions-item label="用户ID">
            {{ userDetail.userId }}
          </el-descriptions-item>
          <el-descriptions-item label="昵称">
            {{ userDetail.nickname || '-' }}
          </el-descriptions-item>
          <el-descriptions-item label="注册时间">
            {{ userDetail.createdAt || '-' }}
          </el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="getStatusType(userDetail.status)">
              {{ getStatusText(userDetail.status) }}
            </el-tag>
          </el-descriptions-item>
        </el-descriptions>
      </el-card>

      <!-- 积分与等级卡片 -->
      <el-card class="info-card">
        <template #header>
          <span class="card-title">积分 & 等级</span>
        </template>

        <el-row :gutter="20">
          <el-col :span="8">
            <div class="stat-item">
              <div class="stat-value text-primary">{{ userDetail.pointsTotal ?? '-' }}</div>
              <div class="stat-label">当前积分</div>
            </div>
          </el-col>
          <el-col :span="8">
            <div class="stat-item">
              <div class="stat-value">{{ getLevelName(userDetail.levelCode, userDetail.levelName) }}</div>
              <div class="stat-label">当前等级</div>
            </div>
          </el-col>
          <el-col :span="8">
            <div class="stat-item">
              <div class="stat-value text-info">{{ userDetail.levelCode || '-' }}</div>
              <div class="stat-label">等级代码</div>
            </div>
          </el-col>
        </el-row>
      </el-card>

      <!-- 行为统计卡片 -->
      <el-card class="info-card">
        <template #header>
          <span class="card-title">行为统计</span>
        </template>

        <el-row :gutter="20">
          <el-col :span="6">
            <div class="stat-item">
              <div class="stat-value">{{ userDetail.shareCount ?? '-' }}</div>
              <div class="stat-label">分享数</div>
            </div>
          </el-col>
          <el-col :span="6">
            <div class="stat-item">
              <div class="stat-value">{{ userDetail.viewCount ?? '-' }}</div>
              <div class="stat-label">浏览数</div>
            </div>
          </el-col>
          <el-col :span="6">
            <div class="stat-item">
              <div class="stat-value text-success">{{ userDetail.likeCount ?? '-' }}</div>
              <div class="stat-label">赞同数</div>
            </div>
          </el-col>
          <el-col :span="6">
            <div class="stat-item">
              <div class="stat-value text-info">{{ userDetail.dislikeCount ?? '-' }}</div>
              <div class="stat-label">无感数</div>
            </div>
          </el-col>
        </el-row>

        <el-row :gutter="20" style="margin-top: 20px;">
          <el-col :span="6">
            <div class="stat-item">
              <div class="stat-value">{{ userDetail.checkinCount ?? '-' }}</div>
              <div class="stat-label">打卡数</div>
            </div>
          </el-col>
          <el-col :span="6">
            <div class="stat-item">
              <div class="stat-value">{{ userDetail.commentCount ?? '-' }}</div>
              <div class="stat-label">评论数</div>
            </div>
          </el-col>
          <el-col :span="6">
            <div class="stat-item">
              <div class="stat-value">{{ userDetail.taggedShareCount ?? '-' }}</div>
              <div class="stat-label">被贴标签分享数</div>
            </div>
          </el-col>
        </el-row>
      </el-card>

      <!-- 奖章列表卡片 -->
      <el-card class="info-card">
        <template #header>
          <span class="card-title">奖章列表</span>
        </template>

        <div v-if="userDetail.medals && userDetail.medals.length > 0">
          <el-table :data="userDetail.medals" border stripe>
            <el-table-column prop="medalCode" label="奖章代码" width="150" />
            <el-table-column prop="medalName" label="奖章名称" />
            <el-table-column prop="obtainedAt" label="获得时间" width="180" />
          </el-table>
        </div>
        <el-empty v-else description="暂无奖章" :image-size="80" />
      </el-card>

      <!-- 原始JSON数据（调试用） -->
      <el-card class="info-card">
        <template #header>
          <span class="card-title">原始数据（调试）</span>
        </template>
        <pre style="background: #f5f7fa; padding: 16px; border-radius: 4px; font-size: 12px; overflow-x: auto;">{{ JSON.stringify(userDetail, null, 2) }}</pre>
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

.text-primary {
  color: #409eff;
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
