<template>
  <div class="report-container">
    <!-- 统计卡片 -->
    <el-row :gutter="20" class="stats-row">
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card pending" @click="filterByStatus(0)">
          <el-statistic title="待处理" :value="stats.pending" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card processed" @click="filterByStatus(1)">
          <el-statistic title="已处理" :value="stats.processed" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card rejected" @click="filterByStatus(2)">
          <el-statistic title="已拒绝" :value="stats.rejected" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card total" @click="filterByStatus(null)">
          <el-statistic title="全部" :value="stats.total" />
        </el-card>
      </el-col>
    </el-row>

    <!-- 举报列表 -->
    <el-card>
      <template #header>
        <div class="card-header">
          <h3>举报管理</h3>
          <el-radio-group v-model="currentStatus" @change="fetchReports">
            <el-radio-button :value="null">全部</el-radio-button>
            <el-radio-button :value="0">待处理</el-radio-button>
            <el-radio-button :value="1">已处理</el-radio-button>
            <el-radio-button :value="2">已拒绝</el-radio-button>
          </el-radio-group>
        </div>
      </template>

      <el-table :data="reports" stripe v-loading="loading">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column label="分享ID" width="100">
          <template #default="{ row }">
            <el-link type="primary" @click="goToShare(row.shareId)">
              {{ row.shareId }}
            </el-link>
          </template>
        </el-table-column>
        <el-table-column prop="reporterUserId" label="举报者ID" width="100" />
        <el-table-column prop="reporterNickname" label="举报者" width="120" />
        <el-table-column prop="reason" label="原因" min-width="200" show-overflow-tooltip />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="getStatusType(row.status)" size="small">
              {{ getStatusText(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="举报时间" width="180" />
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <template v-if="row.status === 0">
              <el-button type="success" size="small" @click="handleReport(row, 'valid')">
                有效
              </el-button>
              <el-button type="info" size="small" @click="handleReport(row, 'invalid')">
                无效
              </el-button>
            </template>
            <el-tag v-else type="info" size="small">已处理</el-tag>
          </template>
        </el-table-column>
      </el-table>

      <el-empty v-if="!loading && reports.length === 0" description="暂无举报记录" />

      <!-- 分页 -->
      <div class="pagination-wrapper" v-if="total > pageSize">
        <el-pagination
          v-model:current-page="currentPage"
          :page-size="pageSize"
          :total="total"
          layout="prev, pager, next"
          @current-change="fetchReports"
        />
      </div>
    </el-card>

    <!-- 处理对话框 -->
    <el-dialog
      v-model="dialogVisible"
      :title="dialogAction === 'valid' ? '标记举报有效' : '标记举报无效'"
      width="400px"
    >
      <el-form :model="handleForm">
        <el-form-item label="处理说明">
          <el-input
            v-model="handleForm.note"
            type="textarea"
            :rows="3"
            placeholder="可选填写处理说明"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button
          :type="dialogAction === 'valid' ? 'success' : 'info'"
          @click="confirmHandle"
          :loading="submitting"
        >
          确认
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import inspectorRequest from '@/utils/inspectorRequest'

const router = useRouter()

const loading = ref(false)
const submitting = ref(false)
const reports = ref([])
const currentStatus = ref(0) // 默认显示待处理
const currentPage = ref(1)
const pageSize = ref(20)
const total = ref(0)

const stats = reactive({
  pending: 0,
  processed: 0,
  rejected: 0,
  total: 0
})

const dialogVisible = ref(false)
const dialogAction = ref('')
const currentReport = ref(null)
const handleForm = reactive({
  note: ''
})

const getStatusType = (status) => {
  switch (status) {
    case 0: return 'warning'
    case 1: return 'success'
    case 2: return 'info'
    default: return 'info'
  }
}

const getStatusText = (status) => {
  switch (status) {
    case 0: return '待处理'
    case 1: return '已处理'
    case 2: return '已拒绝'
    default: return '未知'
  }
}

const fetchStats = async () => {
  try {
    const res = await inspectorRequest.get('/inspector/reports/stats')
    if (res.respCode === 0 && res.datas) {
      stats.pending = res.datas.pending || 0
      stats.processed = res.datas.processed || 0
      stats.rejected = res.datas.rejected || 0
      stats.total = res.datas.total || 0
    }
  } catch (error) {
    console.error('获取统计失败', error)
  }
}

const fetchReports = async () => {
  loading.value = true
  try {
    const params = {
      page: currentPage.value,
      size: pageSize.value
    }
    if (currentStatus.value !== null) {
      params.status = currentStatus.value
    }

    const res = await inspectorRequest.get('/inspector/reports', { params })
    if (res.respCode === 0 && res.datas) {
      reports.value = res.datas.records || []
      total.value = res.datas.total || 0
    }
  } catch (error) {
    console.error('获取举报列表失败', error)
  } finally {
    loading.value = false
  }
}

const filterByStatus = (status) => {
  currentStatus.value = status
  currentPage.value = 1
  fetchReports()
}

const goToShare = (shareId) => {
  router.push({
    path: '/inspector/query',
    query: { type: 'share', id: shareId }
  })
}

const handleReport = (report, action) => {
  currentReport.value = report
  dialogAction.value = action
  handleForm.note = ''
  dialogVisible.value = true
}

const confirmHandle = async () => {
  if (!currentReport.value) return

  submitting.value = true
  try {
    const params = new URLSearchParams()
    params.append('action', dialogAction.value)
    if (handleForm.note) {
      params.append('note', handleForm.note)
    }

    const res = await inspectorRequest.post(
      `/inspector/reports/${currentReport.value.id}/handle`,
      params
    )

    if (res.respCode === 0) {
      ElMessage.success(dialogAction.value === 'valid' ? '已标记举报有效' : '已标记举报无效')
      dialogVisible.value = false
      fetchReports()
      fetchStats()
    }
  } catch (error) {
    console.error('处理失败', error)
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  fetchStats()
  fetchReports()
})
</script>

<style scoped>
.report-container {
  padding: 20px;
}

.stats-row {
  margin-bottom: 20px;
}

.stat-card {
  cursor: pointer;
  transition: all 0.3s;
}

.stat-card:hover {
  transform: translateY(-4px);
}

.stat-card.pending {
  border-left: 4px solid #E6A23C;
}

.stat-card.processed {
  border-left: 4px solid #67C23A;
}

.stat-card.rejected {
  border-left: 4px solid #909399;
}

.stat-card.total {
  border-left: 4px solid #409EFF;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.card-header h3 {
  margin: 0;
}

.pagination-wrapper {
  margin-top: 20px;
  display: flex;
  justify-content: center;
}
</style>
