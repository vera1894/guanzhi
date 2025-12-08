<template>
  <div class="inspector-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <h3>分享详情查询</h3>
        </div>
      </template>

      <el-form :model="queryForm" inline>
        <el-form-item label="分享ID">
          <el-input
            v-model="queryForm.shareId"
            placeholder="请输入分享ID"
            clearable
            @keyup.enter="queryShare"
          />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="loading" @click="queryShare">
            查询
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card v-if="shareDetail" class="result-card" style="margin-top: 20px">
      <template #header>
        <div class="card-header">
          <h3>分享信息</h3>
          <el-tag type="success">ID: {{ shareDetail.shareId }}</el-tag>
        </div>
      </template>

      <el-descriptions :column="2" border>
        <el-descriptions-item label="分享ID">
          {{ shareDetail.shareId }}
        </el-descriptions-item>
        <el-descriptions-item label="用户ID">
          {{ shareDetail.userId }}
        </el-descriptions-item>
        <el-descriptions-item label="标题">
          {{ shareDetail.title || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="内容">
          {{ shareDetail.content || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="位置信息" :span="2">
          {{ shareDetail.location || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="经度">
          {{ shareDetail.longitude ?? '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="纬度">
          {{ shareDetail.latitude ?? '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="点赞数">
          {{ shareDetail.likeCount ?? 0 }}
        </el-descriptions-item>
        <el-descriptions-item label="打卡数">
          {{ shareDetail.checkinCount ?? 0 }}
        </el-descriptions-item>
        <el-descriptions-item label="评论数">
          {{ shareDetail.commentCount ?? 0 }}
        </el-descriptions-item>
        <el-descriptions-item label="状态">
          <el-tag :type="shareDetail.status === 'ACTIVE' ? 'success' : 'warning'">
            {{ shareDetail.status || '-' }}
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="创建时间" :span="2">
          {{ shareDetail.createTime || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="更新时间" :span="2">
          {{ shareDetail.updateTime || '-' }}
        </el-descriptions-item>
      </el-descriptions>

      <el-divider content-position="left">媒体文件</el-divider>
      <div v-if="shareDetail.mediaUrls && shareDetail.mediaUrls.length > 0">
        <el-image
          v-for="(url, index) in shareDetail.mediaUrls"
          :key="index"
          :src="url"
          :preview-src-list="shareDetail.mediaUrls"
          fit="cover"
          style="width: 100px; height: 100px; margin-right: 10px; margin-bottom: 10px"
        />
      </div>
      <el-empty v-else description="无媒体文件" :image-size="50" />

      <el-divider content-position="left">标签</el-divider>
      <div v-if="shareDetail.tags && shareDetail.tags.length > 0">
        <el-tag
          v-for="tag in shareDetail.tags"
          :key="tag"
          style="margin-right: 10px"
          type="info"
        >
          {{ tag }}
        </el-tag>
      </div>
      <el-empty v-else description="无标签" :image-size="50" />

      <el-divider content-position="left">原始数据</el-divider>
      <el-input
        v-model="rawDataText"
        type="textarea"
        :rows="15"
        readonly
        placeholder="原始JSON数据"
      />
    </el-card>

    <el-empty v-else-if="queried && !shareDetail" description="未查询到分享信息" />
  </div>
</template>

<script setup>
import { ref, reactive, computed } from 'vue'
import { ElMessage } from 'element-plus'
import inspectorRequest from '@/utils/inspectorRequest'

const loading = ref(false)
const queried = ref(false)
const shareDetail = ref(null)

const queryForm = reactive({
  shareId: ''
})

const rawDataText = computed(() => {
  if (!shareDetail.value) return ''
  return JSON.stringify(shareDetail.value, null, 2)
})

const queryShare = async () => {
  if (!queryForm.shareId) {
    ElMessage.warning('请输入分享ID')
    return
  }

  loading.value = true
  queried.value = false
  shareDetail.value = null

  try {
    const res = await inspectorRequest.get(`/inspector/share/${queryForm.shareId}`)

    queried.value = true

    if (res.respCode === 0 && res.datas) {
      shareDetail.value = res.datas
      ElMessage.success('查询成功')
    } else if (res.respCode === 1001) {
      ElMessage.warning(res.respMsg || '分享不存在')
    } else {
      ElMessage.warning(res.respMsg || '未查询到分享')
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
