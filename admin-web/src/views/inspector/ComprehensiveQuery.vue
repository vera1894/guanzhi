<template>
  <div class="inspector-container">
    <!-- 查询表单 -->
    <el-card>
      <template #header>
        <div class="card-header">
          <h3>综合查询</h3>
        </div>
      </template>

      <el-form :model="queryForm" inline>
        <el-form-item label="查询类型">
          <el-radio-group v-model="queryForm.type">
            <el-radio-button value="share">分享</el-radio-button>
            <el-radio-button value="user">用户</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item :label="queryForm.type === 'share' ? '分享ID' : '用户ID'">
          <el-input
            v-model="queryForm.id"
            :placeholder="queryForm.type === 'share' ? '请输入分享ID' : '请输入用户ID'"
            clearable
            @keyup.enter="doQuery"
            style="width: 200px"
          />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="loading" @click="doQuery">
            查询
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 分享查询结果 -->
    <template v-if="queryForm.type === 'share' && shareDetail">
      <el-card class="result-card" style="margin-top: 20px">
        <template #header>
          <div class="card-header">
            <h3>分享基本信息</h3>
            <el-tag type="success">ID: {{ shareDetail.shareId }}</el-tag>
          </div>
        </template>

        <el-descriptions :column="2" border>
          <el-descriptions-item label="分享ID">{{ shareDetail.shareId }}</el-descriptions-item>
          <el-descriptions-item label="发布者ID">{{ shareDetail.userId }}</el-descriptions-item>
          <el-descriptions-item label="发布者昵称">{{ shareDetail.userNickname || '-' }}</el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="getStatusType(shareDetail.status)">{{ getStatusText(shareDetail.status) }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="内容" :span="2">{{ shareDetail.content || '-' }}</el-descriptions-item>
          <el-descriptions-item label="地址" :span="2">{{ shareDetail.address || '-' }}</el-descriptions-item>
          <el-descriptions-item label="经度">{{ shareDetail.longitude ?? '-' }}</el-descriptions-item>
          <el-descriptions-item label="纬度">{{ shareDetail.latitude ?? '-' }}</el-descriptions-item>
          <el-descriptions-item label="褪色分数">{{ shareDetail.fadeScore ?? 0 }}</el-descriptions-item>
          <el-descriptions-item label="官方标记">{{ getOfficialMarkText(shareDetail.officialMark) }}</el-descriptions-item>
          <el-descriptions-item label="创建时间" :span="2">{{ shareDetail.createdAt || '-' }}</el-descriptions-item>
        </el-descriptions>

        <!-- 统计概览 -->
        <el-divider content-position="left">统计概览</el-divider>
        <el-row :gutter="20">
          <el-col :span="4"><el-statistic title="浏览人数" :value="shareDetail.viewUserCount || 0" /></el-col>
          <el-col :span="4"><el-statistic title="评论数" :value="shareDetail.commentCount || 0" /></el-col>
          <el-col :span="4"><el-statistic title="贴纸数" :value="shareDetail.stickerCount || 0" /></el-col>
          <el-col :span="4"><el-statistic title="打卡数" :value="shareDetail.checkinCount || 0" /></el-col>
          <el-col :span="4"><el-statistic title="举报数" :value="shareDetail.reportCount || 0" /></el-col>
        </el-row>
      </el-card>

      <!-- 评论列表 -->
      <el-card class="result-card" style="margin-top: 20px">
        <template #header>
          <h3>评论列表 ({{ shareDetail.comments?.length || 0 }})</h3>
        </template>
        <el-table :data="shareDetail.comments" stripe max-height="400">
          <el-table-column prop="commentId" label="评论ID" width="100" />
          <el-table-column prop="userId" label="用户ID" width="100" />
          <el-table-column prop="userNickname" label="昵称" width="120" />
          <el-table-column prop="content" label="内容" min-width="200" show-overflow-tooltip />
          <el-table-column prop="likeCount" label="点赞" width="80" />
          <el-table-column label="状态" width="80">
            <template #default="{ row }">
              <el-tag :type="row.status === 0 ? 'success' : 'danger'" size="small">
                {{ row.status === 0 ? '正常' : row.status === 1 ? '删除' : '屏蔽' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="createdAt" label="时间" width="180" />
        </el-table>
        <el-empty v-if="!shareDetail.comments?.length" description="暂无评论" :image-size="50" />
      </el-card>

      <!-- 贴纸使用记录 -->
      <el-card class="result-card" style="margin-top: 20px">
        <template #header>
          <h3>贴纸使用记录 ({{ shareDetail.stickerActions?.length || 0 }})</h3>
        </template>
        <el-table :data="shareDetail.stickerActions" stripe max-height="300">
          <el-table-column prop="id" label="ID" width="80" />
          <el-table-column prop="userId" label="用户ID" width="100" />
          <el-table-column prop="userNickname" label="昵称" width="120" />
          <el-table-column prop="tagCode" label="贴纸代码" width="120" />
          <el-table-column prop="tagName" label="贴纸名称" width="120" />
          <el-table-column prop="stickerGroup" label="分组" width="80" />
          <el-table-column prop="createdAt" label="时间" width="180" />
        </el-table>
        <el-empty v-if="!shareDetail.stickerActions?.length" description="暂无贴纸使用记录" :image-size="50" />
      </el-card>

      <!-- 打卡记录 -->
      <el-card class="result-card" style="margin-top: 20px">
        <template #header>
          <h3>打卡记录 ({{ shareDetail.checkins?.length || 0 }})</h3>
        </template>
        <el-table :data="shareDetail.checkins" stripe max-height="300">
          <el-table-column prop="id" label="ID" width="80" />
          <el-table-column prop="userId" label="用户ID" width="100" />
          <el-table-column prop="userNickname" label="昵称" width="120" />
          <el-table-column prop="latitude" label="纬度" width="150" />
          <el-table-column prop="longitude" label="经度" width="150" />
          <el-table-column prop="createdAt" label="时间" width="180" />
        </el-table>
        <el-empty v-if="!shareDetail.checkins?.length" description="暂无打卡记录" :image-size="50" />
      </el-card>

      <!-- 浏览记录 -->
      <el-card class="result-card" style="margin-top: 20px">
        <template #header>
          <h3>浏览记录 (最近100条)</h3>
        </template>
        <el-table :data="shareDetail.viewLogs" stripe max-height="300">
          <el-table-column prop="id" label="ID" width="80" />
          <el-table-column prop="userId" label="用户ID" width="100" />
          <el-table-column prop="userNickname" label="昵称" width="120" />
          <el-table-column prop="createdAt" label="时间" width="180" />
        </el-table>
        <el-empty v-if="!shareDetail.viewLogs?.length" description="暂无浏览记录" :image-size="50" />
      </el-card>

      <!-- 举报记录 -->
      <el-card class="result-card" style="margin-top: 20px">
        <template #header>
          <h3>举报记录 ({{ shareDetail.reports?.length || 0 }})</h3>
        </template>
        <el-table :data="shareDetail.reports" stripe max-height="300">
          <el-table-column prop="id" label="ID" width="80" />
          <el-table-column prop="reporterUserId" label="举报者ID" width="100" />
          <el-table-column prop="reporterNickname" label="昵称" width="120" />
          <el-table-column prop="reason" label="原因" min-width="200" show-overflow-tooltip />
          <el-table-column label="状态" width="80">
            <template #default="{ row }">
              <el-tag :type="row.status === 1 ? 'success' : row.status === 2 ? 'info' : 'warning'" size="small">
                {{ row.status === 0 ? '待处理' : row.status === 1 ? '已处理' : '已拒绝' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="createdAt" label="时间" width="180" />
        </el-table>
        <el-empty v-if="!shareDetail.reports?.length" description="暂无举报记录" :image-size="50" />
      </el-card>
    </template>

    <!-- 用户查询结果 -->
    <template v-if="queryForm.type === 'user' && userDetail">
      <el-card class="result-card" style="margin-top: 20px">
        <template #header>
          <div class="card-header">
            <h3>用户基本信息</h3>
            <el-tag type="success">ID: {{ userDetail.userId }}</el-tag>
          </div>
        </template>

        <el-descriptions :column="2" border>
          <el-descriptions-item label="用户ID">{{ userDetail.userId }}</el-descriptions-item>
          <el-descriptions-item label="昵称">{{ userDetail.nickname || '-' }}</el-descriptions-item>
          <el-descriptions-item label="手机号">{{ userDetail.phone || '-' }}</el-descriptions-item>
          <el-descriptions-item label="角色">{{ userDetail.role || '-' }}</el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="userDetail.status === 0 ? 'success' : userDetail.status === 1 ? 'warning' : 'danger'">
              {{ userDetail.status === 0 ? '正常' : userDetail.status === 1 ? '警告' : '冻结' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="等级">{{ userDetail.levelName || userDetail.levelCode || '-' }}</el-descriptions-item>
          <el-descriptions-item label="总积分">{{ userDetail.pointsTotal ?? 0 }}</el-descriptions-item>
          <el-descriptions-item label="注册时间">{{ userDetail.createdAt || '-' }}</el-descriptions-item>
          <el-descriptions-item label="最后登录" :span="2">{{ userDetail.lastLoginTime || '-' }}</el-descriptions-item>
        </el-descriptions>

        <!-- 统计概览 -->
        <el-divider content-position="left">统计概览</el-divider>
        <el-row :gutter="20">
          <el-col :span="4"><el-statistic title="分享数" :value="userDetail.shareCount || 0" /></el-col>
          <el-col :span="4"><el-statistic title="评论数" :value="userDetail.commentCount || 0" /></el-col>
          <el-col :span="4"><el-statistic title="贴纸使用" :value="userDetail.stickerActionCount || 0" /></el-col>
          <el-col :span="4"><el-statistic title="打卡数" :value="userDetail.checkinCount || 0" /></el-col>
          <el-col :span="4"><el-statistic title="奖章数" :value="userDetail.medalCount || 0" /></el-col>
        </el-row>

        <!-- 奖章展示 -->
        <el-divider content-position="left">奖章</el-divider>
        <div v-if="userDetail.medals?.length">
          <el-tag v-for="medal in userDetail.medals" :key="medal.medalCode" style="margin-right: 10px; margin-bottom: 10px" type="warning">
            {{ medal.medalName }} ({{ medal.obtainedAt }})
          </el-tag>
        </div>
        <el-empty v-else description="暂无奖章" :image-size="50" />
      </el-card>

      <!-- 发布的分享 -->
      <el-card class="result-card" style="margin-top: 20px">
        <template #header>
          <h3>发布的分享 ({{ userDetail.shares?.length || 0 }})</h3>
        </template>
        <el-table :data="userDetail.shares" stripe max-height="400">
          <el-table-column prop="shareId" label="分享ID" width="100" />
          <el-table-column prop="content" label="内容" min-width="200" show-overflow-tooltip />
          <el-table-column prop="address" label="地址" width="150" show-overflow-tooltip />
          <el-table-column label="状态" width="80">
            <template #default="{ row }">
              <el-tag :type="getStatusType(row.status)" size="small">{{ getStatusText(row.status) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="fadeScore" label="褪色分" width="80" />
          <el-table-column prop="viewUserCount" label="浏览" width="80" />
          <el-table-column prop="commentCount" label="评论" width="80" />
          <el-table-column prop="createdAt" label="时间" width="180" />
        </el-table>
        <el-empty v-if="!userDetail.shares?.length" description="暂无分享" :image-size="50" />
      </el-card>

      <!-- 评论列表 -->
      <el-card class="result-card" style="margin-top: 20px">
        <template #header>
          <h3>评论记录 ({{ userDetail.comments?.length || 0 }})</h3>
        </template>
        <el-table :data="userDetail.comments" stripe max-height="300">
          <el-table-column prop="commentId" label="评论ID" width="100" />
          <el-table-column prop="shareId" label="分享ID" width="100" />
          <el-table-column prop="content" label="内容" min-width="200" show-overflow-tooltip />
          <el-table-column prop="likeCount" label="点赞" width="80" />
          <el-table-column label="状态" width="80">
            <template #default="{ row }">
              <el-tag :type="row.status === 0 ? 'success' : 'danger'" size="small">
                {{ row.status === 0 ? '正常' : row.status === 1 ? '删除' : '屏蔽' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="createdAt" label="时间" width="180" />
        </el-table>
        <el-empty v-if="!userDetail.comments?.length" description="暂无评论" :image-size="50" />
      </el-card>

      <!-- 贴纸使用记录 -->
      <el-card class="result-card" style="margin-top: 20px">
        <template #header>
          <h3>贴纸使用记录 ({{ userDetail.stickerActions?.length || 0 }})</h3>
        </template>
        <el-table :data="userDetail.stickerActions" stripe max-height="300">
          <el-table-column prop="id" label="ID" width="80" />
          <el-table-column prop="shareId" label="分享ID" width="100" />
          <el-table-column prop="tagCode" label="贴纸代码" width="120" />
          <el-table-column prop="tagName" label="贴纸名称" width="120" />
          <el-table-column prop="stickerGroup" label="分组" width="80" />
          <el-table-column prop="createdAt" label="时间" width="180" />
        </el-table>
        <el-empty v-if="!userDetail.stickerActions?.length" description="暂无贴纸使用记录" :image-size="50" />
      </el-card>

      <!-- 打卡记录 -->
      <el-card class="result-card" style="margin-top: 20px">
        <template #header>
          <h3>打卡记录 ({{ userDetail.checkins?.length || 0 }})</h3>
        </template>
        <el-table :data="userDetail.checkins" stripe max-height="300">
          <el-table-column prop="id" label="ID" width="80" />
          <el-table-column prop="shareId" label="分享ID" width="100" />
          <el-table-column prop="latitude" label="纬度" width="150" />
          <el-table-column prop="longitude" label="经度" width="150" />
          <el-table-column prop="createdAt" label="时间" width="180" />
        </el-table>
        <el-empty v-if="!userDetail.checkins?.length" description="暂无打卡记录" :image-size="50" />
      </el-card>
    </template>

    <!-- 无结果提示 -->
    <el-empty v-if="queried && !shareDetail && !userDetail" description="未查询到数据" />
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { ElMessage } from 'element-plus'
import inspectorRequest from '@/utils/inspectorRequest'

const loading = ref(false)
const queried = ref(false)
const shareDetail = ref(null)
const userDetail = ref(null)

const queryForm = reactive({
  type: 'share',
  id: ''
})

const getStatusType = (status) => {
  switch (status) {
    case 0: return 'success'
    case 1: return 'warning'
    case 2: return 'info'
    case 3: return 'danger'
    default: return 'info'
  }
}

const getStatusText = (status) => {
  switch (status) {
    case 0: return '正常'
    case 1: return '褪色'
    case 2: return '隐藏'
    case 3: return '违规'
    default: return '未知'
  }
}

const getOfficialMarkText = (mark) => {
  switch (mark) {
    case 0: return '无'
    case 1: return '优质'
    case 2: return '劣质'
    default: return '-'
  }
}

const doQuery = async () => {
  if (!queryForm.id) {
    ElMessage.warning('请输入ID')
    return
  }

  loading.value = true
  queried.value = false
  shareDetail.value = null
  userDetail.value = null

  try {
    const url = queryForm.type === 'share'
      ? `/inspector/share/${queryForm.id}/detail`
      : `/inspector/user/${queryForm.id}/detail`

    const res = await inspectorRequest.get(url)

    queried.value = true

    if (res.respCode === 0 && res.datas) {
      if (queryForm.type === 'share') {
        shareDetail.value = res.datas
      } else {
        userDetail.value = res.datas
      }
      ElMessage.success('查询成功')
    } else if (res.respCode === 1001) {
      ElMessage.warning(res.respMsg || '数据不存在')
    } else {
      ElMessage.warning(res.respMsg || '查询失败')
    }
  } catch (error) {
    queried.value = true
    console.error('查询失败', error)
    ElMessage.error('查询失败')
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.inspector-container {
  padding: 20px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.card-header h3 {
  margin: 0;
}

.result-card {
  animation: fadeIn 0.3s;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
