import axios from 'axios'
import { ElMessage } from 'element-plus'
import router from '../router'

const service = axios.create({
  baseURL: '/api', // 使用代理
  timeout: 5000
})

// 请求拦截器
service.interceptors.request.use(
  config => {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers['Authorization'] = 'Bearer ' + token
    }
    return config
  },
  error => {
    return Promise.reject(error)
  }
)

// 响应拦截器
service.interceptors.response.use(
  response => {
    const res = response.data
    if (res.respCode !== 0 && res.respCode !== 200) {
      ElMessage.error(res.respMsg || 'Error')
      return Promise.reject(new Error(res.respMsg || 'Error'))
    } else {
      return res
    }
  },
  error => {
    if (error.response && error.response.status === 401) {
      ElMessage.error('登录已过期，请重新登录')
      localStorage.removeItem('token')
      router.push('/login')
    } else {
      ElMessage.error(error.message || 'Request Error')
    }
    return Promise.reject(error)
  }
)

export default service
