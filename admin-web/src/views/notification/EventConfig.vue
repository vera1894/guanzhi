<template>
  <div class="app-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>通知事件配置</span>
          <el-button type="primary" @click="handleAdd">新增事件</el-button>
        </div>
      </template>

      <el-table :data="tableData" v-loading="loading" border stripe>
        <el-table-column prop="eventCode" label="事件代码" width="140">
          <template #default="scope">
            <el-tag type="info" effect="plain">{{ scope.row.eventCode }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="eventName" label="事件名称" width="120" />
        <el-table-column prop="eventGroup" label="分组" width="100">
          <template #default="scope">
            <el-tag :type="getGroupType(scope.row.eventGroup)">
              {{ getGroupLabel(scope.row.eventGroup) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="isEnabled" label="状态" width="80">
          <template #default="scope">
            <el-switch
              v-model="scope.row.isEnabled"
              @change="handleToggleEnabled(scope.row)"
            />
          </template>
        </el-table-column>
        <el-table-column prop="frequencyLimit" label="频率限制" width="100">
          <template #default="scope">
            <span v-if="scope.row.frequencyLimit">{{ scope.row.frequencyLimit }}/小时</span>
            <span v-else class="text-muted">不限制</span>
          </template>
        </el-table-column>
        <el-table-column prop="cooldownSeconds" label="冷却时间" width="100">
          <template #default="scope">
            <span v-if="scope.row.cooldownSeconds">{{ scope.row.cooldownSeconds }}秒</span>
            <span v-else class="text-muted">无</span>
          </template>
        </el-table-column>
        <el-table-column prop="defaultTitleTemplate" label="默认标题" min-width="150" show-overflow-tooltip />
        <el-table-column prop="defaultBodyTemplate" label="默认内容" min-width="200" show-overflow-tooltip />
        <el-table-column label="操作" width="150" align="center" fixed="right">
          <template #default="scope">
            <el-button size="small" @click="handleEdit(scope.row)">编辑</el-button>
            <el-button size="small" type="danger" @click="handleDelete(scope.row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 编辑对话框 -->
    <el-dialog :title="dialogTitle" v-model="dialogVisible" width="650px">
      <el-form :model="form" :rules="rules" ref="formRef" label-width="120px">
        <el-form-item label="事件代码" prop="eventCode">
          <el-input
            v-model="form.eventCode"
            placeholder="如: comment_reply"
            :disabled="!!form.id"
          />
          <div class="form-tip" v-if="!form.id">事件代码创建后不可修改，使用小写下划线格式</div>
        </el-form-item>
        <el-form-item label="事件名称" prop="eventName">
          <el-input v-model="form.eventName" placeholder="如: 评论回复" />
        </el-form-item>
        <el-form-item label="事件分组" prop="eventGroup">
          <el-select v-model="form.eventGroup" placeholder="请选择">
            <el-option label="互动 (interaction)" value="interaction" />
            <el-option label="系统 (system)" value="system" />
            <el-option label="社交 (social)" value="social" />
          </el-select>
        </el-form-item>
        <el-form-item label="是否启用" prop="isEnabled">
          <el-switch v-model="form.isEnabled" active-text="启用" inactive-text="禁用" />
        </el-form-item>

        <el-divider content-position="left">频率控制</el-divider>

        <el-form-item label="频率限制">
          <el-input-number v-model="form.frequencyLimit" :min="0" :max="1000" placeholder="0" />
          <span class="unit-text">次/小时 (0表示不限制)</span>
        </el-form-item>
        <el-form-item label="冷却时间">
          <el-input-number v-model="form.cooldownSeconds" :min="0" :max="3600" placeholder="0" />
          <span class="unit-text">秒 (0表示无冷却)</span>
        </el-form-item>

        <el-divider content-position="left">默认模板</el-divider>

        <el-form-item label="默认标题">
          <el-input v-model="form.defaultTitleTemplate" placeholder="如: 有人回复了你" />
          <div class="form-tip">支持变量: {{fromUserName}}, {{shareId}}, {{commentId}}</div>
        </el-form-item>
        <el-form-item label="默认内容">
          <el-input
            v-model="form.defaultBodyTemplate"
            type="textarea"
            :rows="2"
            placeholder="如: {{fromUserName}} 回复了你的评论"
          />
        </el-form-item>
        <el-form-item label="Deep Link">
          <el-input v-model="form.deepLinkPattern" placeholder="如: guanzhi://share/{{shareId}}/comment/{{commentId}}" />
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
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import request from '../../utils/request'

const loading = ref(false)
const tableData = ref([])
const dialogVisible = ref(false)
const submitting = ref(false)
const dialogTitle = ref('')
const formRef = ref(null)

const form = reactive({
  id: null,
  eventCode: '',
  eventName: '',
  eventGroup: 'interaction',
  isEnabled: true,
  frequencyLimit: 0,
  cooldownSeconds: 0,
  defaultTitleTemplate: '',
  defaultBodyTemplate: '',
  deepLinkPattern: ''
})

const rules = {
  eventCode: [
    { required: true, message: '请输入事件代码', trigger: 'blur' },
    { pattern: /^[a-z][a-z0-9_]*$/, message: '事件代码需为小写字母开头，只能包含小写字母、数字和下划线', trigger: 'blur' }
  ],
  eventName: [{ required: true, message: '请输入事件名称', trigger: 'blur' }],
  eventGroup: [{ required: true, message: '请选择事件分组', trigger: 'change' }]
}

const getGroupType = (group) => {
  const types = { interaction: 'primary', system: 'warning', social: 'success' }
  return types[group] || 'info'
}

const getGroupLabel = (group) => {
  const labels = { interaction: '互动', system: '系统', social: '社交' }
  return labels[group] || group
}

const fetchData = async () => {
  loading.value = true
  try {
    const res = await request.get('/admin/config/notification-events')
    tableData.value = res.datas || []
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
}

const handleAdd = () => {
  dialogTitle.value = '新增事件'
  Object.assign(form, {
    id: null,
    eventCode: '',
    eventName: '',
    eventGroup: 'interaction',
    isEnabled: true,
    frequencyLimit: 0,
    cooldownSeconds: 0,
    defaultTitleTemplate: '',
    defaultBodyTemplate: '',
    deepLinkPattern: ''
  })
  dialogVisible.value = true
}

const handleEdit = (row) => {
  dialogTitle.value = '编辑事件'
  Object.assign(form, {
    ...row,
    frequencyLimit: row.frequencyLimit ?? 0,
    cooldownSeconds: row.cooldownSeconds ?? 0
  })
  dialogVisible.value = true
}

const handleToggleEnabled = async (row) => {
  try {
    await request.post('/admin/config/notification-event', row)
    ElMessage.success(row.isEnabled ? '已启用' : '已禁用')
  } catch (error) {
    console.error(error)
    row.isEnabled = !row.isEnabled // 回滚状态
  }
}

const handleDelete = (row) => {
  ElMessageBox.confirm('确认删除该事件配置吗？', '警告', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(async () => {
    try {
      await request.delete(`/admin/config/notification-event/${row.id}`)
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
        await request.post('/admin/config/notification-event', form)
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
.text-muted {
  color: #909399;
}
.unit-text {
  margin-left: 10px;
  color: #909399;
  font-size: 12px;
}
</style>
