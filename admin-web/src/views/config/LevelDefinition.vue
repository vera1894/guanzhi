<template>
  <div class="app-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>等级定义管理</span>
          <el-button type="primary" @click="handleAdd">新增等级</el-button>
        </div>
      </template>
      
      <el-table :data="tableData" v-loading="loading" border stripe>
        <el-table-column prop="levelCode" label="等级代码" width="120" />
        <el-table-column prop="levelName" label="等级名称" width="120" />
        <el-table-column prop="minPoints" label="所需积分" width="120" />
        <el-table-column label="升级条件" min-width="200">
          <template #default="scope">
            <el-tag size="small">签到: {{ scope.row.minCheckins }}</el-tag>
            <el-tag size="small" style="margin-left: 5px">评论: {{ scope.row.minComments }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="taggingAllowance" label="贴条权限 (次/日)" width="150" />
        <el-table-column label="操作" width="180" align="center">
          <template #default="scope">
            <el-button size="small" @click="handleEdit(scope.row)">编辑</el-button>
            <el-button size="small" type="danger" @click="handleDelete(scope.row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 编辑对话框 -->
    <el-dialog :title="dialogTitle" v-model="dialogVisible" width="600px">
      <el-form :model="form" :rules="rules" ref="formRef" label-width="120px">
        <el-row>
          <el-col :span="12">
            <el-form-item label="等级代码" prop="levelCode">
              <el-input v-model="form.levelCode" placeholder="如: LEVEL_1" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="等级名称" prop="levelName">
              <el-input v-model="form.levelName" placeholder="如: 新手" />
            </el-form-item>
          </el-col>
        </el-row>
        
        <el-divider content-position="left">升级要求</el-divider>
        
        <el-form-item label="所需积分" prop="minPoints">
          <el-input-number v-model="form.minPoints" :min="0" />
        </el-form-item>
        
        <el-row>
          <el-col :span="12">
            <el-form-item label="最少签到" prop="minCheckins">
              <el-input-number v-model="form.minCheckins" :min="0" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="最少评论" prop="minComments">
              <el-input-number v-model="form.minComments" :min="0" />
            </el-form-item>
          </el-col>
        </el-row>
        
        <el-divider content-position="left">等级权益</el-divider>
        
        <el-form-item label="每日贴条配额" prop="taggingAllowance">
          <el-input-number v-model="form.taggingAllowance" :min="0" />
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
  levelCode: '',
  levelName: '',
  minPoints: 0,
  minCheckins: 0,
  minComments: 0,
  taggingAllowance: 0
})

const rules = {
  levelCode: [{ required: true, message: '请输入等级代码', trigger: 'blur' }],
  levelName: [{ required: true, message: '请输入等级名称', trigger: 'blur' }]
}

const fetchData = async () => {
  loading.value = true
  try {
    const res = await request.get('/admin/config/levels')
    tableData.value = res.datas || []
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
}

const handleAdd = () => {
  dialogTitle.value = '新增等级'
  Object.assign(form, {
    id: null,
    levelCode: '',
    levelName: '',
    minPoints: 0,
    minCheckins: 0,
    minComments: 0,
    taggingAllowance: 5
  })
  dialogVisible.value = true
}

const handleEdit = (row) => {
  dialogTitle.value = '编辑等级'
  Object.assign(form, row)
  dialogVisible.value = true
}

const handleDelete = (row) => {
  ElMessageBox.confirm('确认删除该等级吗？', '警告', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(async () => {
    try {
      await request.delete(`/admin/config/level/${row.id}`)
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
        await request.post('/admin/config/level', form)
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