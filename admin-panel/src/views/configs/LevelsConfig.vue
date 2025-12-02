<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getLevelDefinitions, saveLevelDefinition, deleteLevelDefinition, type LevelDefinition } from '../../api/admin'

const loading = ref(false)
const levels = ref<LevelDefinition[]>([])
const dialogVisible = ref(false)
const editForm = ref<LevelDefinition>({
  id: undefined,
  levelCode: '',
  levelName: '',
  minPoints: 0,
  minCheckins: 0,
  minComments: 0,
  taggingAllowance: 0,
  extraConditions: ''
})

const loadLevels = async () => {
  loading.value = true
  try {
    const response = await getLevelDefinitions()
    levels.value = response.datas || []
  } catch (error: any) {
    ElMessage.error(error.message || '加载等级定义失败')
  } finally {
    loading.value = false
  }
}

const handleAdd = () => {
  editForm.value = {
    id: undefined,
    levelCode: '',
    levelName: '',
    minPoints: 0,
    minCheckins: 0,
    minComments: 0,
    taggingAllowance: 0,
    extraConditions: ''
  }
  dialogVisible.value = true
}

const handleEdit = (level: LevelDefinition) => {
  editForm.value = { ...level }
  dialogVisible.value = true
}

const handleSave = async () => {
  // 空值保护
  const levelCode = editForm.value.levelCode || ''
  const levelName = editForm.value.levelName || ''

  if (!levelCode.trim()) {
    ElMessage.warning('请输入等级代码')
    return
  }

  if (!levelName.trim()) {
    ElMessage.warning('请输入等级名称')
    return
  }

  if (editForm.value.minPoints < 0) {
    ElMessage.warning('最小积分不能为负数')
    return
  }

  try {
    // 只发送后端认识的字段
    const payload: LevelDefinition = {
      id: editForm.value.id,
      levelCode: editForm.value.levelCode,
      levelName: editForm.value.levelName,
      minPoints: editForm.value.minPoints,
      minCheckins: editForm.value.minCheckins || 0,
      minComments: editForm.value.minComments || 0,
      taggingAllowance: editForm.value.taggingAllowance || 0,
      extraConditions: editForm.value.extraConditions || ''
    }

    await saveLevelDefinition(payload)
    ElMessage.success('保存成功')
    dialogVisible.value = false
    await loadLevels()
  } catch (error: any) {
    ElMessage.error(error.message || '保存失败')
  }
}

const handleDelete = (level: LevelDefinition) => {
  ElMessageBox.confirm(`确定要删除等级 "${level.levelName}" 吗？`, '提示', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  })
    .then(async () => {
      try {
        await deleteLevelDefinition(level.id!)
        ElMessage.success('删除成功')
        await loadLevels()
      } catch (error: any) {
        ElMessage.error(error.message || '删除失败')
      }
    })
    .catch(() => {})
}

onMounted(() => {
  loadLevels()
})
</script>

<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span class="card-title">等级定义管理</span>
          <div>
            <el-button type="primary" @click="handleAdd">新增等级</el-button>
            <el-button @click="loadLevels" :loading="loading">刷新</el-button>
          </div>
        </div>
      </template>

      <el-table :data="levels" v-loading="loading" border stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="levelCode" label="等级代码" width="120">
          <template #default="{ row }">
            <el-tag type="info">{{ row.levelCode }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="levelName" label="等级名称" width="150">
          <template #default="{ row }">
            <span style="font-weight: 600; color: #409eff;">{{ row.levelName }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="minPoints" label="最小积分" width="120">
          <template #default="{ row }">
            <span style="color: #67c23a; font-weight: 600;">{{ row.minPoints }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="minCheckins" label="最小打卡" width="100">
          <template #default="{ row }">
            <span>{{ row.minCheckins || 0 }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="minComments" label="最小评论" width="100">
          <template #default="{ row }">
            <span>{{ row.minComments || 0 }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="taggingAllowance" label="标签配额" width="100">
          <template #default="{ row }">
            <el-tag size="small" type="success">{{ row.taggingAllowance || 0 }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="extraConditions" label="额外条件" width="150" show-overflow-tooltip />
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link @click="handleEdit(row)">编辑</el-button>
            <el-button type="danger" link @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div style="margin-top: 20px; padding: 16px; background-color: #f0f9ff; border-left: 4px solid #409eff;">
        <h4 style="margin: 0 0 8px 0; color: #303133;">等级设置说明</h4>
        <ul style="margin: 0; padding-left: 20px; color: #606266; line-height: 1.8;">
          <li>等级按最小积分从高到低排序，用户积分达到即可升级</li>
          <li>最小打卡数/评论数：升级到此等级需完成的打卡或评论次数</li>
          <li>标签配额：该等级用户每日可贴标签的次数</li>
          <li>额外条件：JSON格式的其他升级条件（可选）</li>
        </ul>
      </div>
    </el-card>

    <el-dialog
      v-model="dialogVisible"
      :title="editForm.id ? '编辑等级定义' : '新增等级定义'"
      width="600px"
    >
      <el-form :model="editForm" label-width="120px">
        <el-form-item label="等级代码">
          <el-input v-model="editForm.levelCode" placeholder="例如: LV1, VIP1" />
          <div style="color: #909399; font-size: 12px; margin-top: 4px;">
            建议使用大写字母和数字组合
          </div>
        </el-form-item>
        <el-form-item label="等级名称">
          <el-input v-model="editForm.levelName" placeholder="例如: 初级会员" />
        </el-form-item>
        <el-form-item label="最小积分">
          <el-input-number v-model="editForm.minPoints" :min="0" :max="999999" style="width: 100%" />
          <div style="color: #909399; font-size: 12px; margin-top: 4px;">
            用户积分达到此值即可获得该等级
          </div>
        </el-form-item>
        <el-form-item label="最小打卡数">
          <el-input-number v-model="editForm.minCheckins" :min="0" :max="9999" style="width: 100%" />
          <div style="color: #909399; font-size: 12px; margin-top: 4px;">
            升级到此等级需完成的打卡次数（0表示无要求）
          </div>
        </el-form-item>
        <el-form-item label="最小评论数">
          <el-input-number v-model="editForm.minComments" :min="0" :max="9999" style="width: 100%" />
          <div style="color: #909399; font-size: 12px; margin-top: 4px;">
            升级到此等级需完成的评论次数（0表示无要求）
          </div>
        </el-form-item>
        <el-form-item label="标签配额">
          <el-input-number v-model="editForm.taggingAllowance" :min="0" :max="100" style="width: 100%" />
          <div style="color: #909399; font-size: 12px; margin-top: 4px;">
            该等级用户每日可贴标签的次数
          </div>
        </el-form-item>
        <el-form-item label="额外条件">
          <el-input v-model="editForm.extraConditions" type="textarea" :rows="3" placeholder='JSON格式，如: {"inviteCount": 5}' />
          <div style="color: #909399; font-size: 12px; margin-top: 4px;">
            可选，用于设置其他升级条件（JSON格式）
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
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.card-title {
  font-size: 18px;
  font-weight: 600;
}
</style>
