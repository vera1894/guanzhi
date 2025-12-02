<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getFadeConfigs, saveFadeConfig, type FadeConfig } from '../../api/admin'

const loading = ref(false)
const configs = ref<FadeConfig[]>([])
const dialogVisible = ref(false)
const editForm = ref<FadeConfig>({
  id: 0,
  configKey: '',
  configValue: '',
  description: ''
})

const loadConfigs = async () => {
  loading.value = true
  try {
    const response = await getFadeConfigs()
    // 后端现在返回完整的 List<FadeConfigDO>，包含 id 字段
    configs.value = response.datas || []
  } catch (error: any) {
    ElMessage.error(error.message || '加载配置失败')
  } finally {
    loading.value = false
  }
}

const handleEdit = (config: FadeConfig) => {
  editForm.value = { ...config }
  dialogVisible.value = true
}

const handleSave = async () => {
  if (!editForm.value.configValue.trim()) {
    ElMessage.warning('请输入配置值')
    return
  }

  try {
    await saveFadeConfig(editForm.value)
    ElMessage.success('保存成功')
    dialogVisible.value = false
    await loadConfigs()
  } catch (error: any) {
    ElMessage.error(error.message || '保存失败')
  }
}

onMounted(() => {
  loadConfigs()
})
</script>

<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span class="card-title">褪色规则配置</span>
          <el-button type="primary" @click="loadConfigs" :loading="loading">
            刷新
          </el-button>
        </div>
      </template>

      <el-table :data="configs" v-loading="loading" border stripe>
        <el-table-column prop="configKey" label="配置键" width="280">
          <template #default="{ row }">
            <el-tag>{{ row.configKey }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="configValue" label="配置值" width="150">
          <template #default="{ row }">
            <span style="font-weight: 600; color: #409eff;">{{ row.configValue }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="说明" />
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link @click="handleEdit(row)">
              编辑
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <div style="margin-top: 20px; padding: 16px; background-color: #f0f9ff; border-left: 4px solid #409eff;">
        <h4 style="margin: 0 0 8px 0; color: #303133;">配置说明</h4>
        <ul style="margin: 0; padding-left: 20px; color: #606266; line-height: 1.8;">
          <li>格式为 "阈值:褪色值"，例如 "5:2" 表示浏览人数≤5时，每日褪色+2分</li>
          <li>负面标签、赞同等为负值时，表示减缓褪色速度</li>
          <li>修改配置后，新规则将立即生效</li>
          <li>所有修改都会记录审计日志，可用于回溯</li>
        </ul>
      </div>
    </el-card>

    <el-dialog
      v-model="dialogVisible"
      title="编辑配置"
      width="500px"
    >
      <el-form :model="editForm" label-width="100px">
        <el-form-item label="配置键">
          <el-input v-model="editForm.configKey" disabled />
        </el-form-item>
        <el-form-item label="配置值">
          <el-input v-model="editForm.configValue" />
        </el-form-item>
        <el-form-item label="说明">
          <el-input v-model="editForm.description" type="textarea" :rows="3" />
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
