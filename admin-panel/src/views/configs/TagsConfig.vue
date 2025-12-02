<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getTagDefinitions, saveTagDefinition, deleteTagDefinition, type TagDefinition } from '../../api/admin'
import { pinyin } from 'pinyin-pro'

const loading = ref(false)
const tags = ref<TagDefinition[]>([])
const dialogVisible = ref(false)
const editForm = ref<TagDefinition>({
  id: undefined,
  tagCode: '',
  tagName: '',
  tagType: 'NEGATIVE',
  minLevelCode: '',
  isActive: true,
  sortOrder: 0
})

const tagTypes = [
  { value: 'NEGATIVE', label: '负面标签', color: 'danger' },
  { value: 'POSITIVE', label: '正面标签', color: 'success' }
]

// 自动生成拼音标签键
watch(() => editForm.value.tagName, (newName) => {
  // 只有在新增时（无ID）且tagCode为空时才自动生成
  if (!editForm.value.id && newName && !editForm.value.tagCode) {
    const pinyinKey = pinyin(newName, {
      pattern: 'first',
      toneType: 'none',
      type: 'array'
    }).join('').toUpperCase()
    editForm.value.tagCode = pinyinKey
  }
})

const loadTags = async () => {
  loading.value = true
  try {
    const response = await getTagDefinitions()
    tags.value = response.datas || []
  } catch (error: any) {
    ElMessage.error(error.message || '加载标签定义失败')
  } finally {
    loading.value = false
  }
}

const handleAdd = () => {
  editForm.value = {
    id: undefined,
    tagCode: '',
    tagName: '',
    tagType: 'NEGATIVE',
    minLevelCode: '',
    isActive: true,
    sortOrder: 0
  }
  dialogVisible.value = true
}

const handleEdit = (tag: TagDefinition) => {
  editForm.value = { ...tag }
  dialogVisible.value = true
}

const handleSave = async () => {
  // 空值保护：先获取值，再trim
  const tagCode = editForm.value.tagCode || ''
  const tagName = editForm.value.tagName || ''

  if (!tagCode.trim()) {
    ElMessage.warning('请输入标签键')
    return
  }

  if (!tagName.trim()) {
    ElMessage.warning('请输入标签名称')
    return
  }

  try {
    // 只发送后端认识的字段
    const payload: TagDefinition = {
      id: editForm.value.id,
      tagCode: editForm.value.tagCode,
      tagName: editForm.value.tagName,
      tagType: editForm.value.tagType,
      minLevelCode: editForm.value.minLevelCode || undefined,
      isActive: editForm.value.isActive,
      sortOrder: editForm.value.sortOrder
    }

    await saveTagDefinition(payload)
    ElMessage.success('保存成功')
    dialogVisible.value = false
    await loadTags()
  } catch (error: any) {
    ElMessage.error(error.message || '保存失败')
  }
}

const handleDelete = (tag: TagDefinition) => {
  ElMessageBox.confirm(`确定要删除标签 "${tag.tagName}" 吗？`, '提示', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  })
    .then(async () => {
      try {
        await deleteTagDefinition(tag.id!)
        ElMessage.success('删除成功')
        await loadTags()
      } catch (error: any) {
        ElMessage.error(error.message || '删除失败')
      }
    })
    .catch(() => {})
}

const getTagTypeConfig = (tagType: string) => {
  return tagTypes.find(t => t.value === tagType) || tagTypes[0]
}

onMounted(() => {
  loadTags()
})
</script>

<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span class="card-title">标签定义管理</span>
          <div>
            <el-button type="primary" @click="handleAdd">新增标签</el-button>
            <el-button @click="loadTags" :loading="loading">刷新</el-button>
          </div>
        </div>
      </template>

      <el-table :data="tags" v-loading="loading" border stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="tagCode" label="标签键" width="150">
          <template #default="{ row }">
            <el-tag>{{ row.tagCode }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="tagName" label="标签名称" width="120">
          <template #default="{ row }">
            <span style="font-weight: 600;">{{ row.tagName }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="tagType" label="类型" width="120">
          <template #default="{ row }">
            <el-tag :type="getTagTypeConfig(row.tagType).color">
              {{ getTagTypeConfig(row.tagType).label }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="minLevelCode" label="最低等级" width="100" />
        <el-table-column prop="isActive" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.isActive ? 'success' : 'info'">
              {{ row.isActive ? '激活' : '停用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="sortOrder" label="排序" width="80" />
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link @click="handleEdit(row)">编辑</el-button>
            <el-button type="danger" link @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div style="margin-top: 20px; padding: 16px; background-color: #f0f9ff; border-left: 4px solid #409eff;">
        <h4 style="margin: 0 0 8px 0; color: #303133;">标签使用说明</h4>
        <ul style="margin: 0; padding-left: 20px; color: #606266; line-height: 1.8;">
          <li>标签键：自动根据中文名称生成拼音（大写），也可手动修改</li>
          <li>标签类型：正面标签 / 负面标签，影响褪色速度</li>
          <li>最低等级：设置后，只有达到该等级的用户才能使用此标签</li>
          <li>当前标签全部默认为负面标签，会减缓分享的褪色速度</li>
        </ul>
      </div>
    </el-card>

    <el-dialog
      v-model="dialogVisible"
      :title="editForm.id ? '编辑标签定义' : '新增标签定义'"
      width="500px"
    >
      <el-form :model="editForm" label-width="100px">
        <el-form-item label="标签名称">
          <el-input v-model="editForm.tagName" placeholder="例如: 秘境" />
          <div style="color: #909399; font-size: 12px; margin-top: 4px;">
            输入中文名称后，标签键会自动生成拼音
          </div>
        </el-form-item>
        <el-form-item label="标签键">
          <el-input v-model="editForm.tagCode" placeholder="例如: MIJING" />
          <div style="color: #909399; font-size: 12px; margin-top: 4px;">
            建议使用大写拼音，系统会根据标签名称自动生成
          </div>
        </el-form-item>
        <el-form-item label="标签类型">
          <el-select v-model="editForm.tagType" placeholder="请选择标签类型" style="width: 100%">
            <el-option
              v-for="item in tagTypes"
              :key="item.value"
              :label="item.label"
              :value="item.value"
            >
              <el-tag :type="item.color">{{ item.label }}</el-tag>
            </el-option>
          </el-select>
        </el-form-item>
        <el-form-item label="最低等级">
          <el-input v-model="editForm.minLevelCode" placeholder="例如: LV1" />
        </el-form-item>
        <el-form-item label="激活状态">
          <el-switch v-model="editForm.isActive" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="editForm.sortOrder" :min="0" :max="999" />
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
