<template>
  <div class="app-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>标签定义管理</span>
          <el-button type="primary" @click="handleAdd">新增标签</el-button>
        </div>
      </template>
      
      <el-table :data="tableData" v-loading="loading" border stripe>
        <el-table-column prop="tagCode" label="标签键" width="150">
          <template #default="scope">
            <el-tag type="info" effect="plain">{{ scope.row.tagCode }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="tagName" label="标签名称" width="150" />
        <el-table-column prop="tagType" label="类型" width="120">
          <template #default="scope">
            <el-tag :type="scope.row.tagType === 'POSITIVE' ? 'success' : 'danger'">
              {{ scope.row.tagType === 'POSITIVE' ? '正面' : '负面' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="sortOrder" label="排序" width="80" />
        <el-table-column prop="isActive" label="状态" width="80">
          <template #default="scope">
            <el-tag :type="scope.row.isActive ? 'success' : 'info'">
              {{ scope.row.isActive ? '启用' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
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
        <el-form-item label="标签键" prop="tagCode">
          <el-input
            v-model="form.tagCode"
            placeholder="如: MIJING (拼音大写)"
            :disabled="!!form.id"
          />
          <div class="form-tip" v-if="!form.id">标签键创建后不可修改，请使用拼音大写形式</div>
        </el-form-item>
        <el-form-item label="标签名称" prop="tagName">
          <el-input v-model="form.tagName" placeholder="如: 秘境" />
        </el-form-item>
        <el-form-item label="类型" prop="tagType">
          <el-select v-model="form.tagType" placeholder="请选择">
            <el-option label="正面 (POSITIVE)" value="POSITIVE" />
            <el-option label="负面 (NEGATIVE)" value="NEGATIVE" />
          </el-select>
        </el-form-item>
        <el-form-item label="排序" prop="sortOrder">
          <el-input-number v-model="form.sortOrder" :min="0" :max="999" />
        </el-form-item>
        <el-form-item label="状态" prop="isActive">
          <el-switch v-model="form.isActive" active-text="启用" inactive-text="禁用" />
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
  tagCode: '',
  tagName: '',
  tagType: 'NEGATIVE',
  sortOrder: 0,
  isActive: true
})

const rules = {
  tagCode: [
    { required: true, message: '请输入标签键', trigger: 'blur' },
    { pattern: /^[A-Z][A-Z0-9_]*$/, message: '标签键需为大写字母开头，只能包含大写字母、数字和下划线', trigger: 'blur' }
  ],
  tagName: [{ required: true, message: '请输入标签名称', trigger: 'blur' }],
  tagType: [{ required: true, message: '请选择类型', trigger: 'change' }]
}

const fetchData = async () => {
  loading.value = true
  try {
    const res = await request.get('/admin/config/tags')
    tableData.value = res.datas || []
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
}

const handleAdd = () => {
  dialogTitle.value = '新增标签'
  Object.assign(form, {
    id: null,
    tagCode: '',
    tagName: '',
    tagType: 'NEGATIVE',
    sortOrder: 0,
    isActive: true
  })
  dialogVisible.value = true
}

const handleEdit = (row) => {
  dialogTitle.value = '编辑标签'
  Object.assign(form, row)
  dialogVisible.value = true
}

const handleDelete = (row) => {
  ElMessageBox.confirm('确认删除该标签吗？', '警告', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(async () => {
    try {
      // CORRECTED: Use template literal for URL
      await request.delete(`/admin/config/tag/${row.id}`)
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
        await request.post('/admin/config/tag', form)
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
</style>