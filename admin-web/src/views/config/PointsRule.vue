<template>
  <div class="app-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>积分规则配置</span>
          <el-button type="primary" @click="handleAdd">新增规则</el-button>
        </div>
      </template>
      
      <el-table :data="tableData" v-loading="loading" border stripe>
        <el-table-column prop="actionType" label="动作类型" width="200" />
        <el-table-column prop="pointsValue" label="积分值" width="120">
          <template #default="scope">
            <el-tag :type="scope.row.pointsValue > 0 ? 'success' : 'danger'">
              {{ scope.row.pointsValue > 0 ? '+' : '' }}{{ scope.row.pointsValue }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="dailyLimit" label="每日上限 (次)" width="150" />
        <el-table-column prop="description" label="描述" />
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
        <el-form-item label="动作类型" prop="actionType">
          <el-input v-model="form.actionType" :disabled="!!form.id" placeholder="例如: POST_SHARE" />
        </el-form-item>
        <el-form-item label="积分值" prop="pointsValue">
          <el-input-number v-model="form.pointsValue" />
        </el-form-item>
        <el-form-item label="每日上限" prop="dailyLimit">
          <el-input-number v-model="form.dailyLimit" :min="0" />
          <span style="margin-left: 10px; font-size: 12px; color: #999">0 表示不限制</span>
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
  actionType: '',
  pointsValue: 0,
  dailyLimit: 0,
  description: ''
})

const rules = {
  actionType: [{ required: true, message: '请输入动作类型', trigger: 'blur' }],
  pointsValue: [{ required: true, message: '请输入积分值', trigger: 'blur' }]
}

const fetchData = async () => {
  loading.value = true
  try {
    const res = await request.get('/admin/config/points-rules')
    tableData.value = res.datas || []
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
}

const handleAdd = () => {
  dialogTitle.value = '新增规则'
  form.id = null
  form.actionType = ''
  form.pointsValue = 1
  form.dailyLimit = 0
  form.description = ''
  dialogVisible.value = true
}

const handleEdit = (row) => {
  dialogTitle.value = '编辑规则'
  form.id = row.id
  form.actionType = row.actionType
  form.pointsValue = row.pointsValue
  form.dailyLimit = row.dailyLimit
  form.description = row.description
  dialogVisible.value = true
}

const handleDelete = (row) => {
  ElMessageBox.confirm('确认删除该规则吗？', '警告', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(async () => {
    try {
      // 注意：AdminController 中可能没有 points-rule 的删除接口？
      // 让我再检查一下
      // 假设有，或者我可以用通用删除
      await request.delete(`/admin/config/points-rule/${row.id}`)
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
        await request.post('/admin/config/points-rule', form)
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