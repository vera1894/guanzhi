<template>
  <div class="login-container">
    <el-card class="login-card">
      <template #header>
        <div class="login-header">
          <h2>观之管理后台</h2>
        </div>
      </template>
      <el-form :model="loginForm" :rules="rules" ref="loginFormRef">
        <el-form-item prop="phone">
          <el-input
            v-model="loginForm.phone"
            placeholder="请输入手机号"
            prefix-icon="User"
            maxlength="11"
          />
        </el-form-item>
        <el-form-item prop="code">
          <div class="code-input-wrapper">
            <el-input
              v-model="loginForm.code"
              placeholder="请输入验证码"
              prefix-icon="Lock"
              maxlength="6"
              @keyup.enter="handleLogin"
            />
            <el-button
              :disabled="countdown > 0"
              @click="sendCode"
              class="send-code-btn"
            >
              {{ countdown > 0 ? `${countdown}秒后重试` : '发送验证码' }}
            </el-button>
          </div>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" class="login-button" :loading="loading" @click="handleLogin">
            登录
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import request from '../utils/request'

const router = useRouter()
const loginFormRef = ref(null)
const loading = ref(false)
const countdown = ref(0)
let timer = null

const loginForm = reactive({
  phone: '',
  code: ''
})

const validatePhone = (rule, value, callback) => {
  if (!value) {
    callback(new Error('请输入手机号'))
  } else if (!/^1[3-9]\d{9}$/.test(value)) {
    callback(new Error('请输入正确的手机号'))
  } else {
    callback()
  }
}

const rules = {
  phone: [{ required: true, validator: validatePhone, trigger: 'blur' }],
  code: [
    { required: true, message: '请输入验证码', trigger: 'blur' },
    { min: 4, max: 6, message: '验证码长度为4-6位', trigger: 'blur' }
  ]
}

const sendCode = async () => {
  if (!loginForm.phone) {
    ElMessage.warning('请先输入手机号')
    return
  }

  if (!/^1[3-9]\d{9}$/.test(loginForm.phone)) {
    ElMessage.warning('请输入正确的手机号')
    return
  }

  try {
    const res = await request.post('/user/sendCode', {
      phone: loginForm.phone
    })

    if (res.respCode === 0) {
      ElMessage.success('验证码已发送，请注意查收')

      countdown.value = 60
      timer = setInterval(() => {
        countdown.value--
        if (countdown.value <= 0) {
          clearInterval(timer)
        }
      }, 1000)
    }
  } catch (error) {
    console.error('发送验证码失败', error)
  }
}

const handleLogin = async () => {
  if (!loginFormRef.value) return

  await loginFormRef.value.validate(async (valid) => {
    if (valid) {
      loading.value = true
      try {
        // 调用验证码登录接口
        const res = await request.post('/user/checkCodeOrLogin', {
          phone: loginForm.phone,
          code: loginForm.code
        })

        // 后端返回格式：{ respCode: 0, respMsg: "...", datas: "token字符串" }
        // datas 直接是 token 字符串，不是对象
        const token = typeof res.datas === 'string' ? res.datas : res.datas?.token

        if (token) {
          localStorage.setItem('token', token)

          // 解析 JWT token 获取用户信息
          try {
            const payload = JSON.parse(atob(token.split('.')[1]))
            localStorage.setItem('userInfo', JSON.stringify(payload))

            // 检查是否有ADMIN权限
            if (payload.auth !== 'ROLE_ADMIN' && !payload.auth?.includes('ADMIN')) {
              ElMessage.warning('登录成功，但该账号无管理员权限')
            } else {
              ElMessage.success('登录成功')
            }
          } catch (e) {
            ElMessage.success('登录成功')
          }

          router.push('/')
        } else {
          ElMessage.error('登录失败：无效的响应')
        }
      } catch (error) {
        console.error('登录失败', error)
        ElMessage.error(error.message || '登录失败，请检查验证码是否正确')
      } finally {
        loading.value = false
      }
    }
  })
}
</script>

<style scoped>
.login-container {
  height: 100vh;
  display: flex;
  justify-content: center;
  align-items: center;
  background-color: #f0f2f5;
  background-image: url('https://gw.alipayobjects.com/zos/rmsportal/TVYTbAXWheQpRcWDaDMu.svg');
}

.login-card {
  width: 400px;
  border-radius: 8px;
}

.login-header {
  text-align: center;
}

.login-header h2 {
  margin: 0;
  color: #303133;
}

.code-input-wrapper {
  display: flex;
  gap: 10px;
}

.code-input-wrapper .el-input {
  flex: 1;
}

.send-code-btn {
  white-space: nowrap;
  min-width: 120px;
}

.login-button {
  width: 100%;
}
</style>