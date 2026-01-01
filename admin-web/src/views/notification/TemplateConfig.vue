<template>
  <div class="app-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>通知模板管理</span>
          <el-button type="primary" @click="handleAdd">新增模板</el-button>
        </div>
      </template>

      <el-table :data="tableData" v-loading="loading" border stripe>
        <el-table-column prop="eventCode" label="事件代码" width="140">
          <template #default="scope">
            <el-tag type="info" effect="plain">{{ scope.row.eventCode }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="channel" label="渠道" width="100">
          <template #default="scope">
            <el-tag :type="getChannelType(scope.row.channel)">
              {{ getChannelLabel(scope.row.channel) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="locale" label="语言" width="80">
          <template #default="scope">
            {{ getLocaleLabel(scope.row.locale) }}
          </template>
        </el-table-column>
        <el-table-column prop="titleTemplate" label="标题模板" min-width="150" show-overflow-tooltip />
        <el-table-column prop="bodyTemplate" label="内容模板" min-width="200" show-overflow-tooltip />
        <el-table-column prop="deepLinkPattern" label="Deep Link" min-width="180" show-overflow-tooltip />
        <el-table-column prop="isActive" label="状态" width="80">
          <template #default="scope">
            <el-switch
              v-model="scope.row.isActive"
              @change="handleToggleActive(scope.row)"
            />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150" align="center" fixed="right">
          <template #default="scope">
            <el-button size="small" @click="handleEdit(scope.row)">编辑</el-button>
            <el-button size="small" type="danger" @click="handleDelete(scope.row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 编辑对话框 -->
    <el-dialog :title="dialogTitle" v-model="dialogVisible" width="700px">
      <el-form :model="form" :rules="rules" ref="formRef" label-width="120px">
        <el-form-item label="事件代码" prop="eventCode">
          <el-select
            v-model="form.eventCode"
            placeholder="选择事件"
            filterable
            :disabled="!!form.id"
          >
            <el-option
              v-for="event in eventOptions"
              :key="event.eventCode"
              :label="`${event.eventName} (${event.eventCode})`"
              :value="event.eventCode"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="渠道" prop="channel">
          <el-select v-model="form.channel" placeholder="选择渠道" :disabled="!!form.id">
            <el-option label="APNs 推送" value="apns" />
            <el-option label="站内通知" value="in_app" />
            <el-option label="短信" value="sms" />
            <el-option label="邮件" value="email" />
          </el-select>
        </el-form-item>
        <el-form-item label="语言" prop="locale">
          <el-select v-model="form.locale" placeholder="选择语言">
            <el-option label="简体中文" value="zh_CN" />
            <el-option label="English" value="en_US" />
          </el-select>
        </el-form-item>
        <el-form-item label="标题模板" prop="titleTemplate">
          <el-input v-model="form.titleTemplate" placeholder="如: 有人回复了你" />
          <div class="form-tip">支持变量: {{fromUserName}}, {{shareId}}, {{commentId}}</div>
        </el-form-item>
        <el-form-item label="内容模板" prop="bodyTemplate">
          <el-input
            v-model="form.bodyTemplate"
            type="textarea"
            :rows="3"
            placeholder="如: {{fromUserName}} 回复了你的评论: {{replyContent}}"
          />
        </el-form-item>
        <el-form-item label="Deep Link">
          <el-input v-model="form.deepLinkPattern" placeholder="如: guanzhi://share/{{shareId}}/comment/{{commentId}}" />
        </el-form-item>
        <el-form-item label="是否激活" prop="isActive">
          <el-switch v-model="form.isActive" active-text="激活" inactive-text="禁用" />
        </el-form-item>

        <el-divider content-position="left">模板预览</el-divider>

        <el-form-item label="预览">
          <div class="preview-box">
            <div class="preview-title">{{ previewTitle }}</div>
            <div class="preview-body">{{ previewBody }}</div>
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible = false">取消</el-button>
          <el-button type="primary" @click="submitForm" :loading="submitting">确定</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import request from '../../utils/request'

const loading = ref(false)
const tableData = ref([])
const eventOptions = ref([])
const dialogVisible = ref(false)
const submitting = ref(false)
const dialogTitle = ref('')
const formRef = ref(null)

const form = reactive({
  id: null,
  eventCode: '',
  channel: 'apns',
  locale: 'zh_CN',
  titleTemplate: '',
  bodyTemplate: '',
  deepLinkPattern: '',
  isActive: true
})

const rules = {
  eventCode: [{ required: true, message: '请选择事件', trigger: 'change' }],
  channel: [{ required: true, message: '请选择渠道', trigger: 'change' }],
  locale: [{ required: true, message: '请选择语言', trigger: 'change' }],
  titleTemplate: [{ required: true, message: '请输入标题模板', trigger: 'blur' }],
  bodyTemplate: [{ required: true, message: '请输入内容模板', trigger: 'blur' }]
}

// 预览变量
const previewVariables = {
  fromUserName: '张三',
  shareId: '12345',
  commentId: '67890',
  replyContent: '这个地方太美了！'
}

// 渲染模板预览
const renderTemplate = (template) => {
  if (!template) return ''
  return template.replace(/\{\{(\w+)\}\}/g, (match, key) => {
    return previewVariables[key] || match
  })
}

const previewTitle = computed(() => renderTemplate(form.titleTemplate))
const previewBody = computed(() => renderTemplate(form.bodyTemplate))

const getChannelType = (channel) => {
  const types = { apns: 'success', in_app: 'primary', sms: 'warning', email: 'info' }
  return types[channel] || 'info'
}

const getChannelLabel = (channel) => {
  const labels = { apns: 'APNs', in_app: '站内', sms: '短信', email: '邮件' }
  return labels[channel] || channel
}

const getLocaleLabel = (locale) => {
  const labels = { zh_CN: '中文', en_US: 'English' }
  return labels[locale] || locale
}

const fetchEvents = async () => {
  try {
    const res = await request.get('/admin/config/notification-events')
    eventOptions.value = res.datas || []
  } catch (error) {
    console.error(error)
  }
}

const fetchData = async () => {
  loading.value = true
  try {
    const res = await request.get('/admin/config/notification-templates')
    tableData.value = res.datas || []
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
}

const handleAdd = () => {
  dialogTitle.value = '新增模板'
  Object.assign(form, {
    id: null,
    eventCode: '',
    channel: 'apns',
    locale: 'zh_CN',
    titleTemplate: '',
    bodyTemplate: '',
    deepLinkPattern: '',
    isActive: true
  })
  dialogVisible.value = true
}

const handleEdit = (row) => {
  dialogTitle.value = '编辑模板'
  Object.assign(form, { ...row })
  dialogVisible.value = true
}

const handleToggleActive = async (row) => {
  try {
    await request.post('/admin/config/notification-template', row)
    ElMessage.success(row.isActive ? '已激活' : '已禁用')
  } catch (error) {
    console.error(error)
    row.isActive = !row.isActive // 回滚状态
  }
}

const handleDelete = (row) => {
  ElMessageBox.confirm('确认删除该模板吗？', '警告', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(async () => {
    try {
      await request.delete(`/admin/config/notification-template/${row.id}`)
      ElMessage.success('删除成功')
      fetchData()
    } catch (error) {
      console.error(error)
    }
  })
}

const submitForm = async () => {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (valid) {
      submitting.value = true
      try {
        await request.post('/admin/config/notification-template', form)
        ElMessage.success('保存成功')
        dialogVisible.value = false
        fetchData()
      } catch (error) {
        console.error(error)
      } finally {
        submitting.value = false
      }
    }
  })
}

onMounted(() => {
  fetchEvents()
  fetchData()
})
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
.form-tip {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
}
.preview-box {
  background: #f5f7fa;
  border-radius: 8px;
  padding: 12px 16px;
  border: 1px solid #e4e7ed;
}
.preview-title {
  font-weight: bold;
  font-size: 14px;
  color: #303133;
  margin-bottom: 6px;
}
.preview-body {
  font-size: 13px;
  color: #606266;
}
</style>
