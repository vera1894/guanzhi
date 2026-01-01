<template>
  <div class="app-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>系统通知</span>
        </div>
      </template>

      <el-form :model="form" :rules="rules" ref="formRef" label-width="120px" class="notification-form">
        <el-form-item label="通知标题" prop="title">
          <el-input v-model="form.title" placeholder="请输入通知标题" maxlength="50" show-word-limit />
        </el-form-item>

        <el-form-item label="通知内容" prop="content">
          <el-input
            v-model="form.content"
            type="textarea"
            :rows="4"
            placeholder="请输入通知内容"
            maxlength="200"
            show-word-limit
          />
        </el-form-item>

        <el-form-item label="推送目标" prop="targetType">
          <el-radio-group v-model="form.targetType">
            <el-radio value="all">全体用户</el-radio>
            <el-radio value="specific">指定用户</el-radio>
          </el-radio-group>
        </el-form-item>

        <el-form-item label="用户ID列表" v-if="form.targetType === 'specific'" prop="userIdsText">
          <el-input
            v-model="form.userIdsText"
            type="textarea"
            :rows="2"
            placeholder="请输入用户ID，多个ID用逗号分隔，如: 1, 2, 3"
          />
          <div class="form-tip">输入要推送的用户ID，用逗号或换行分隔</div>
        </el-form-item>

        <el-form-item label="Deep Link">
          <el-input v-model="form.deepLink" placeholder="可选，如: guanzhi://share/123" />
          <div class="form-tip">点击通知后跳转的应用内链接（可选）</div>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" @click="handleSend" :loading="sending" size="large">
            发送通知
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 发送历史 -->
    <el-card class="history-card">
      <template #header>
        <span>最近发送记录</span>
      </template>
      <el-table :data="history" border stripe>
        <el-table-column prop="time" label="发送时间" width="180" />
        <el-table-column prop="title" label="标题" width="150" />
        <el-table-column prop="content" label="内容" show-overflow-tooltip />
        <el-table-column prop="targetType" label="目标" width="100">
          <template #default="scope">
            <el-tag :type="scope.row.targetType === 'all' ? 'success' : 'warning'" size="small">
              {{ scope.row.targetType === 'all' ? '全体用户' : '指定用户' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="sentCount" label="发送数量" width="100" align="center" />
      </el-table>
    </el-card>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import request from '../utils/request'

const formRef = ref(null)
const sending = ref(false)
const history = ref([])

const form = reactive({
  title: '',
  content: '',
  targetType: 'all',
  userIdsText: '',
  deepLink: ''
})

const rules = {
  title: [
    { required: true, message: '请输入通知标题', trigger: 'blur' },
    { min: 1, max: 50, message: '标题长度在 1 到 50 个字符', trigger: 'blur' }
  ],
  content: [
    { required: true, message: '请输入通知内容', trigger: 'blur' },
    { min: 1, max: 200, message: '内容长度在 1 到 200 个字符', trigger: 'blur' }
  ]
}

const parseUserIds = (text) => {
  if (!text || !text.trim()) return null
  const ids = text
    .split(/[,，\n\s]+/)
    .map(s => s.trim())
    .filter(s => s)
    .map(s => parseInt(s, 10))
    .filter(n => !isNaN(n) && n > 0)
  return ids.length > 0 ? ids : null
}

const handleSend = async () => {
  if (!formRef.value) return

  await formRef.value.validate(async (valid) => {
    if (!valid) return

    // 如果选择指定用户但没有输入有效ID
    if (form.targetType === 'specific') {
      const userIds = parseUserIds(form.userIdsText)
      if (!userIds || userIds.length === 0) {
        ElMessage.error('请输入有效的用户ID')
        return
      }
    }

    // 确认发送
    const targetDesc = form.targetType === 'all' ? '全体用户' : `指定的 ${parseUserIds(form.userIdsText)?.length || 0} 个用户`

    try {
      await ElMessageBox.confirm(
        `确认向 ${targetDesc} 发送此通知？\n\n标题: ${form.title}\n内容: ${form.content}`,
        '确认发送',
        {
          confirmButtonText: '发送',
          cancelButtonText: '取消',
          type: 'warning'
        }
      )
    } catch {
      return // 用户取消
    }

    sending.value = true
    try {
      const payload = {
        title: form.title,
        content: form.content,
        userIds: form.targetType === 'specific' ? parseUserIds(form.userIdsText) : null,
        deepLink: form.deepLink || null
      }

      const res = await request.post('/admin/notification/send', payload)

      ElMessage.success(`通知已发送给 ${res.datas?.sentCount || 0} 个用户`)

      // 添加到历史记录
      history.value.unshift({
        time: new Date().toLocaleString('zh-CN'),
        title: form.title,
        content: form.content,
        targetType: res.datas?.targetType || form.targetType,
        sentCount: res.datas?.sentCount || 0
      })

      // 只保留最近10条
      if (history.value.length > 10) {
        history.value = history.value.slice(0, 10)
      }

      // 清空表单
      form.title = ''
      form.content = ''
      form.userIdsText = ''
      form.deepLink = ''

    } catch (error) {
      console.error('发送失败:', error)
    } finally {
      sending.value = false
    }
  })
}
</script>

<style scoped>
.app-container {
  padding: 20px;
}
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.notification-form {
  max-width: 600px;
}
.form-tip {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
}
.history-card {
  margin-top: 20px;
}
</style>
