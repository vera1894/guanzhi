<template>
  <div class="app-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>贴纸定义管理</span>
          <el-button type="primary" @click="handleAdd">新增贴纸</el-button>
        </div>
      </template>

      <el-table :data="tableData" v-loading="loading" border stripe>
        <el-table-column prop="tagCode" label="贴纸键" width="120">
          <template #default="scope">
            <el-tag type="info" effect="plain">{{ scope.row.tagCode }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="tagName" label="名称" width="100" />
        <el-table-column prop="stickerGroup" label="分组" width="80">
          <template #default="scope">
            <el-tag :type="getGroupType(scope.row.stickerGroup)">
              {{ getGroupLabel(scope.row.stickerGroup) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="tagType" label="类型" width="80">
          <template #default="scope">
            <el-tag :type="scope.row.tagType === 'POSITIVE' ? 'success' : 'danger'" size="small">
              {{ scope.row.tagType === 'POSITIVE' ? '正面' : '负面' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="minLevelCode" label="解锁等级" width="100">
          <template #default="scope">
            <el-tag v-if="scope.row.minLevelCode" type="warning" size="small">
              {{ getLevelName(scope.row.minLevelCode) }}
            </el-tag>
            <span v-else class="text-muted">全员</span>
          </template>
        </el-table-column>
        <el-table-column prop="baseDailyLimit" label="基础限额" width="90">
          <template #default="scope">
            <span v-if="scope.row.baseDailyLimit !== null">{{ scope.row.baseDailyLimit }}</span>
            <span v-else class="text-muted">不限</span>
          </template>
        </el-table-column>
        <el-table-column label="待生效配置" width="160">
          <template #default="scope">
            <div v-if="scope.row.pendingDailyLimit !== null">
              <span class="pending-value">{{ scope.row.pendingDailyLimit }}</span>
              <span class="pending-date">@ {{ scope.row.pendingEffectiveDay }}</span>
            </div>
            <span v-else class="text-muted">-</span>
          </template>
        </el-table-column>
        <el-table-column prop="sortOrder" label="排序" width="70" />
        <el-table-column prop="isActive" label="状态" width="70">
          <template #default="scope">
            <el-tag :type="scope.row.isActive ? 'success' : 'info'" size="small">
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
    <el-dialog :title="dialogTitle" v-model="dialogVisible" width="600px">
      <el-form :model="form" :rules="rules" ref="formRef" label-width="120px">
        <el-form-item label="贴纸键" prop="tagCode">
          <el-input
            v-model="form.tagCode"
            placeholder="如: MIJING (拼音大写)"
            :disabled="!!form.id"
          />
          <div class="form-tip" v-if="!form.id">贴纸键创建后不可修改，请使用拼音大写形式</div>
        </el-form-item>
        <el-form-item label="贴纸名称" prop="tagName">
          <el-input v-model="form.tagName" placeholder="如: 秘境" />
        </el-form-item>
        <el-form-item label="分组" prop="stickerGroup">
          <el-select v-model="form.stickerGroup" placeholder="请选择">
            <el-option label="投票 (vote)" value="vote" />
            <el-option label="标签 (tag)" value="tag" />
            <el-option label="趣味 (fun)" value="fun" />
          </el-select>
          <div class="form-tip">vote = 赞同/无感，互斥；tag = 普通标签</div>
        </el-form-item>
        <el-form-item label="类型" prop="tagType">
          <el-select v-model="form.tagType" placeholder="请选择">
            <el-option label="正面 (POSITIVE)" value="POSITIVE" />
            <el-option label="负面 (NEGATIVE)" value="NEGATIVE" />
          </el-select>
        </el-form-item>
        <el-form-item label="解锁等级" prop="minLevelCode">
          <el-select v-model="form.minLevelCode" placeholder="全员可用" clearable>
            <el-option
              v-for="level in levelOptions"
              :key="level.levelCode"
              :label="level.levelName"
              :value="level.levelCode"
            />
          </el-select>
          <div class="form-tip">留空表示所有等级都可使用此贴纸</div>
        </el-form-item>
        <el-form-item label="基础每日限额" prop="baseDailyLimit">
          <el-input-number v-model="form.baseDailyLimit" :min="0" :max="9999" placeholder="不限" />
          <div class="form-tip">用户每日限额 = 基础限额 × 用户等级的配额倍率</div>
        </el-form-item>
        <el-divider content-position="left">待生效配置（次日04:00生效）</el-divider>
        <el-form-item label="待生效限额">
          <el-input-number v-model="form.pendingDailyLimit" :min="0" :max="9999" placeholder="不设置" />
        </el-form-item>
        <el-form-item label="生效日期">
          <el-date-picker
            v-model="form.pendingEffectiveDay"
            type="date"
            placeholder="选择日期"
            value-format="YYYY-MM-DD"
          />
        </el-form-item>
        <el-divider />
        <el-form-item label="排序" prop="sortOrder">
          <el-input-number v-model="form.sortOrder" :min="-999" :max="999" />
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

const levelOptions = ref([])

const form = reactive({
  id: null,
  tagCode: '',
  tagName: '',
  tagType: 'NEGATIVE',
  stickerGroup: 'tag',
  minLevelCode: null,
  baseDailyLimit: null,
  pendingDailyLimit: null,
  pendingEffectiveDay: null,
  sortOrder: 0,
  isActive: true
})

const rules = {
  tagCode: [
    { required: true, message: '请输入贴纸键', trigger: 'blur' },
    { pattern: /^[A-Z][A-Z0-9_]*$/, message: '贴纸键需为大写字母开头，只能包含大写字母、数字和下划线', trigger: 'blur' }
  ],
  tagName: [{ required: true, message: '请输入贴纸名称', trigger: 'blur' }],
  tagType: [{ required: true, message: '请选择类型', trigger: 'change' }],
  stickerGroup: [{ required: true, message: '请选择分组', trigger: 'change' }]
}

const getGroupType = (group) => {
  const types = { vote: 'warning', tag: 'success', fun: 'info' }
  return types[group] || 'info'
}

const getGroupLabel = (group) => {
  const labels = { vote: '投票', tag: '标签', fun: '趣味' }
  return labels[group] || group
}

const getLevelName = (levelCode) => {
  const level = levelOptions.value.find(l => l.levelCode === levelCode)
  return level ? level.levelName : levelCode
}

const fetchLevels = async () => {
  try {
    const res = await request.get('/admin/config/levels')
    levelOptions.value = res.datas || []
  } catch (error) {
    console.error(error)
  }
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
  dialogTitle.value = '新增贴纸'
  Object.assign(form, {
    id: null,
    tagCode: '',
    tagName: '',
    tagType: 'NEGATIVE',
    stickerGroup: 'tag',
    minLevelCode: null,
    baseDailyLimit: null,
    pendingDailyLimit: null,
    pendingEffectiveDay: null,
    sortOrder: 0,
    isActive: true
  })
  dialogVisible.value = true
}

const handleEdit = (row) => {
  dialogTitle.value = '编辑贴纸'
  Object.assign(form, {
    ...row,
    minLevelCode: row.minLevelCode ?? null,
    baseDailyLimit: row.baseDailyLimit ?? null,
    pendingDailyLimit: row.pendingDailyLimit ?? null,
    pendingEffectiveDay: row.pendingEffectiveDay ?? null
  })
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
  fetchLevels()
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
.pending-value {
  color: #e6a23c;
  font-weight: bold;
}
.pending-date {
  font-size: 12px;
  color: #909399;
  margin-left: 4px;
}
</style>