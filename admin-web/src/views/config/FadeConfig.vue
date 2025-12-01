<template>
  <div class="app-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>褪色规则配置</span>
          <el-button type="primary" @click="handleAdd">新增配置</el-button>
        </div>
      </template>
      
      <el-table :data="tableData" v-loading="loading" border stripe>
        <el-table-column prop="configKey" label="配置键 (Key)" width="250" />
        <el-table-column prop="configValue" label="配置值 (Value)" width="150" />
        <el-table-column prop="description" label="描述" />
        <el-table-column prop="updateTime" label="最后更新" width="180" />
        <el-table-column label="操作" width="180" align="center">
          <template #default="scope">
            <el-button size="small" @click="handleEdit(scope.row)">编辑</el-button>
            <el-button size="small" type="danger" @click="handleDelete(scope.row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 编辑对话框 -->
    <el-dialog :title="dialogTitle" v-model="dialogVisible" width="500px">
      <el-form :model="form" :rules="rules" ref="formRef" label-width="100px">
        <el-form-item label="配置键" prop="configKey">
          <el-input v-model="form.configKey" :disabled="!!form.id" placeholder="例如: VIEW_COUNT_FADE_TIER_1" />
        </el-form-item>
        <el-form-item label="配置值" prop="configValue">
          <el-input v-model="form.configValue" placeholder="例如: 5:2" />
        </el-form-item>
        <el-form-item label="描述" prop="description">
          <el-input v-model="form.description" type="textarea" />
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
  configKey: '',
  configValue: '',
  description: ''
})

const rules = {
  configKey: [{ required: true, message: '请输入配置键', trigger: 'blur' }],
  configValue: [{ required: true, message: '请输入配置值', trigger: 'blur' }]
}

const fetchData = async () => {
  loading.value = true
  try {
    const res = await request.get('/admin/config/fade-configs')
    tableData.value = res.datas || []
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
}

const handleAdd = () => {
  dialogTitle.value = '新增配置'
  form.id = null
  form.configKey = ''
  form.configValue = ''
  form.description = ''
  dialogVisible.value = true
}

const handleEdit = (row) => {
  dialogTitle.value = '编辑配置'
  form.id = row.id
  form.configKey = row.configKey
  form.configValue = row.configValue
  form.description = row.description
  dialogVisible.value = true
}

const handleDelete = (row) => {
  ElMessageBox.confirm('确认删除该配置吗？', '警告', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(async () => {
    try {
      await request.delete(`/admin/config/fade-config/${row.id}`)
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
        await request.post('/admin/config/fade-config', form)
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
</style>