<template>
  <div class="inspector-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <h3>用户详情查询</h3>
        </div>
      </template>

      <el-form :model="queryForm" inline>
        <el-form-item label="用户ID">
          <el-input
            v-model="queryForm.userId"
            placeholder="请输入用户ID"
            clearable
            @keyup.enter="queryUser"
          />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="loading" @click="queryUser">
            查询
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card v-if="userDetail" class="result-card" style="margin-top: 20px">
      <template #header>
        <div class="card-header">
          <h3>用户信息</h3>
          <el-tag type="success">ID: {{ userDetail.userId }}</el-tag>
        </div>
      </template>

      <el-descriptions :column="2" border>
        <el-descriptions-item label="用户ID">
          {{ userDetail.userId }}
        </el-descriptions-item>
        <el-descriptions-item label="昵称">
          {{ userDetail.nickname || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="手机号">
          {{ userDetail.phone || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="等级代码">
          {{ userDetail.levelCode || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="总积分">
          {{ userDetail.pointsTotal ?? '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="分享数量">
          {{ userDetail.shareCount ?? '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="角色">
          {{ userDetail.role || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="权限">
          {{ userDetail.auth || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="注册时间" :span="2">
          {{ userDetail.createTime || '-' }}
        </el-descriptions-item>
      </el-descriptions>

      <el-divider content-position="left">OneCode 信息</el-divider>
      <el-descriptions :column="2" border>
        <el-descriptions-item label="OneCode">
          {{ userDetail.oneCode || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="OneCode 创建时间">
          {{ userDetail.oneCodeCreateTime || '-' }}
        </el-descriptions-item>
      </el-descriptions>

      <el-divider content-position="left">原始数据</el-divider>
      <el-input
        v-model="rawDataText"
        type="textarea"
        :rows="10"
        readonly
        placeholder="原始JSON数据"
      />
    </el-card>

    <el-empty v-else-if="queried && !userDetail" description="未查询到用户信息" />
  </div>
</template>

<script setup>
import { ref, reactive, computed } from 'vue'
import { ElMessage } from 'element-plus'
import inspectorRequest from '@/utils/inspectorRequest'

const loading = ref(false)
const queried = ref(false)
const userDetail = ref(null)

const queryForm = reactive({
  userId: ''
})

const rawDataText = computed(() => {
  if (!userDetail.value) return ''
  return JSON.stringify(userDetail.value, null, 2)
})

const queryUser = async () => {
  if (!queryForm.userId) {
    ElMessage.warning('请输入用户ID')
    return
  }

  loading.value = true
  queried.value = false
  userDetail.value = null

  try {
    const res = await inspectorRequest.get(`/inspector/user/${queryForm.userId}`)

    queried.value = true

    if (res.respCode === 0 && res.datas) {
      userDetail.value = res.datas
      ElMessage.success('查询成功')
    } else {
      ElMessage.warning(res.respMsg || '未查询到用户')
    }
  } catch (error) {
    queried.value = true
    console.error('查询失败', error)
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
