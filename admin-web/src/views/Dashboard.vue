<template>
  <div>
    <h1>欢迎使用观之管理后台</h1>
    <el-row :gutter="20">
      <el-col :span="6">
        <el-card shadow="hover">
          <template #header>系统状态</template>
          <div class="status-normal">运行正常</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" @click="goToReports" style="cursor: pointer;">
          <template #header>待处理举报</template>
          <div :class="pendingReports > 0 ? 'status-warning' : 'status-normal'">
            {{ pendingReports }} 条
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import inspectorRequest from '../utils/inspectorRequest'

const router = useRouter()
const pendingReports = ref(0)

const fetchReportStats = async () => {
  try {
    const res = await inspectorRequest.get('/inspector/reports/stats')
    if (res.respCode === 0 && res.datas) {
      pendingReports.value = res.datas.pending || 0
    }
  } catch (e) {
    console.error('获取举报统计失败', e)
  }
}

const goToReports = () => {
  router.push('/reports')
}

onMounted(() => {
  fetchReportStats()
})
</script>

<style scoped>
.status-normal {
  color: #67C23A;
  font-weight: bold;
  font-size: 24px;
}
.status-warning {
  color: #E6A23C;
  font-weight: bold;
  font-size: 24px;
}
</style>