import axios from 'axios'
import { ElMessage } from 'element-plus'
import router from '../router'

// Inspector API 专用请求工具
// Inspector API 路径为 /admin/inspector/...,不在 /api 路径下
const getBaseURL = () => {
  if (import.meta.env.DEV) {
    // 开发环境使用代理
    return '/admin'
  } else {
    // 生产环境使用完整URL
    return import.meta.env.VITE_API_BASE_URL + '/admin'
  }
}

const inspectorService = axios.create({
  baseURL: getBaseURL(),
  timeout: 10000 // Inspector查询可能较慢,设置10秒超时
})

// 请求拦截器 - 自动添加Token
inspectorService.interceptors.request.use(
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
inspectorService.interceptors.response.use(
  response => {
    const res = response.data
    // Inspector API 成功返回 respCode: 0
    if (res.respCode === 0) {
      return res
    } else if (res.respCode === 1001) {
      // 业务逻辑错误 (如:分享不存在)
      ElMessage.warning(res.respMsg || '查询失败')
      return res
    } else {
      ElMessage.error(res.respMsg || '请求失败')
      return Promise.reject(new Error(res.respMsg || 'Error'))
    }
  },
  error => {
    if (error.response && error.response.status === 401) {
      ElMessage.error('权限不足或登录已过期，请重新登录')
      localStorage.removeItem('token')
      router.push('/login')
    } else if (error.response && error.response.status === 403) {
      ElMessage.error('无管理员权限，无法访问Inspector')
    } else {
      ElMessage.error(error.message || 'Request Error')
    }
    return Promise.reject(error)
  }
)

export default inspectorService
