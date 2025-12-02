<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getPointsRules, savePointsRule, deletePointsRule, type PointsRule } from '../../api/admin'

const loading = ref(false)
const rules = ref<PointsRule[]>([])
const dialogVisible = ref(false)
const editForm = ref<PointsRule>({
  id: undefined,
  actionType: '',
  pointsValue: 0,
  dailyLimit: undefined
})

const actionTypes = [
  { value: 'POST_SHARE', label: '发布分享' },
  { value: 'RECEIVE_AGREE', label: '获得赞同' },
  { value: 'RECEIVE_TAG', label: '被打标签' },
  { value: 'CHECKIN_SHARE', label: '打卡分享' },
  { value: 'POST_COMMENT', label: '发表评论' }
]

const loadRules = async () => {
  loading.value = true
  try {
    const response = await getPointsRules()
    rules.value = response.datas || []
  } catch (error: any) {
    ElMessage.error(error.message || '加载积分规则失败')
  } finally {
    loading.value = false
  }
}

const handleAdd = () => {
  editForm.value = {
    id: undefined,
    actionType: '',
    pointsValue: 0,
    dailyLimit: undefined
  }
  dialogVisible.value = true
}

const handleEdit = (rule: PointsRule) => {
  editForm.value = { ...rule }
  dialogVisible.value = true
}

const handleSave = async () => {
  if (!editForm.value.actionType) {
    ElMessage.warning('请选择行为类型')
    return
  }

  if (editForm.value.pointsValue === 0) {
    ElMessage.warning('请输入积分值（不能为0）')
    return
  }

  try {
    await savePointsRule(editForm.value)
    ElMessage.success('保存成功')
    dialogVisible.value = false
    await loadRules()
  } catch (error: any) {
    ElMessage.error(error.message || '保存失败')
  }
}

const handleDelete = (rule: PointsRule) => {
  ElMessageBox.confirm('确定要删除这条积分规则吗？', '提示', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  })
    .then(async () => {
      try {
        await deletePointsRule(rule.id!)
        ElMessage.success('删除成功')
        await loadRules()
      } catch (error: any) {
        ElMessage.error(error.message || '删除失败')
      }
    })
    .catch(() => {})
}

const getActionTypeLabel = (actionType: string) => {
  return actionTypes.find(t => t.value === actionType)?.label || actionType
}

onMounted(() => {
  loadRules()
})
</script>

<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span class="card-title">积分规则配置</span>
          <div>
            <el-button type="primary" @click="handleAdd">新增规则</el-button>
            <el-button @click="loadRules" :loading="loading">刷新</el-button>
          </div>
        </div>
      </template>

      <el-table :data="rules" v-loading="loading" border stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="actionType" label="行为类型" width="200">
          <template #default="{ row }">
            <el-tag type="success">{{ getActionTypeLabel(row.actionType) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="pointsValue" label="积分值" width="120">
          <template #default="{ row }">
            <span :style="{ color: row.pointsValue > 0 ? '#67c23a' : '#f56c6c', fontWeight: 600 }">
              {{ row.pointsValue > 0 ? '+' : '' }}{{ row.pointsValue }}
            </span>
          </template>
        </el-table-column>
        <el-table-column prop="dailyLimit" label="每日上限" width="120">
          <template #default="{ row }">
            <span>{{ row.dailyLimit || '无限制' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link @click="handleEdit(row)">编辑</el-button>
            <el-button type="danger" link @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog
      v-model="dialogVisible"
      :title="editForm.id ? '编辑积分规则' : '新增积分规则'"
      width="500px"
    >
      <el-form :model="editForm" label-width="100px">
        <el-form-item label="行为类型">
          <el-select v-model="editForm.actionType" placeholder="请选择行为类型" style="width: 100%">
            <el-option
              v-for="item in actionTypes"
              :key="item.value"
              :label="item.label"
              :value="item.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="积分值">
          <el-input-number v-model="editForm.pointsValue" :min="-1000" :max="1000" style="width: 100%" />
          <div style="color: #909399; font-size: 12px; margin-top: 4px;">
            正值表示增加积分，负值表示扣除积分
          </div>
        </el-form-item>
        <el-form-item label="每日上限">
          <el-input-number v-model="editForm.dailyLimit" :min="0" :max="1000" style="width: 100%" />
          <div style="color: #909399; font-size: 12px; margin-top: 4px;">
            0表示无限制
          </div>
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
</style>
