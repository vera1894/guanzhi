<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { setToken } from '../../utils/auth'

const router = useRouter()
const token = ref('')
const loading = ref(false)

const handleLogin = () => {
  if (!token.value.trim()) {
    ElMessage.warning('请输入 Admin Token')
    return
  }

  loading.value = true
  try {
    setToken(token.value.trim())
    ElMessage.success('登录成功')
    router.push('/')
  } catch (error) {
    ElMessage.error('登录失败')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-container">
    <div class="login-box">
      <div class="login-header">
        <h1>观之管理后台</h1>
        <p>Admin Panel</p>
      </div>

      <el-form class="login-form" @submit.prevent="handleLogin">
        <el-form-item>
          <el-input
            v-model="token"
            type="textarea"
            :rows="8"
            placeholder="请输入 Admin Token&#10;&#10;测试 Token (ROLE_ADMIN):&#10;eyJhbGciOiJIUzUxMiJ9.eyJqdGkiOiI1ZTYwYzJlMjBlZTc0ZjMzOTk5MmRmZDFiNTVkNWUyNyIsImF1dGgiOiJST0xFX0FETUlOIiwidXNlciI6MiwibmFtZSI6IjEzODEwMjY5NjI3Iiwibmlja25hbWUiOiJUZXN0QWRtaW4iLCJwaG9uZSI6IjEzODEwMjY5NjI3Iiwic3ViIjoiMiJ9.cfIGo-00EKb1YqYjcYiauLZ1oPozNxzDM4KsFXXvRPJ1IModMl1kYqotBj7A0Dct7r6GmpMOEd8ngrRQSmyIrw"
          />
        </el-form-item>

        <el-form-item>
          <el-button
            type="primary"
            :loading="loading"
            style="width: 100%"
            native-type="submit"
          >
            登录
          </el-button>
        </el-form-item>
      </el-form>

      <div class="login-footer">
        <p>使用 ADMIN 角色 Token 登录以访问管理功能</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.login-box {
  background: white;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  padding: 40px;
  width: 500px;
  max-width: 90%;
}

.login-header {
  text-align: center;
  margin-bottom: 30px;
}

.login-header h1 {
  font-size: 28px;
  font-weight: 600;
  color: #303133;
  margin: 0 0 8px 0;
}

.login-header p {
  font-size: 14px;
  color: #909399;
  margin: 0;
}

.login-form {
  margin-top: 20px;
}

.login-footer {
  margin-top: 20px;
  text-align: center;
}

.login-footer p {
  font-size: 12px;
  color: #909399;
  margin: 0;
}
</style>
