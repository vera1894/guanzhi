import axios from 'axios'
import type { AxiosError, InternalAxiosRequestConfig, AxiosResponse } from 'axios'
import { ElMessage } from 'element-plus'
import { getToken, removeToken } from '../utils/auth'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8085/api'

const request = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
})

request.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = getToken()
    if (token && config.headers) {
      // 如果 token 已经包含 Bearer 前缀，直接使用；否则添加 Bearer 前缀
      config.headers.Authorization = token.startsWith('Bearer ') ? token : `Bearer ${token}`
      console.log('[Request] Authorization header:', config.headers.Authorization.substring(0, 30) + '...')
    }
    return config
  },
  (error: AxiosError) => {
    console.error('Request error:', error)
    return Promise.reject(error)
  }
)

request.interceptors.response.use(
  (response: AxiosResponse) => {
    const { respCode, respMsg } = response.data

    console.log('[Response] respCode:', respCode, 'respMsg:', respMsg)

    if (respCode === 0) {
      return response.data
    } else {
      ElMessage.error(respMsg || '请求失败')
      return Promise.reject(new Error(respMsg || '请求失败'))
    }
  },
  (error: AxiosError) => {
    console.error('[Response Error]', {
      status: error.response?.status,
      statusText: error.response?.statusText,
      url: error.config?.url,
      hasResponse: !!error.response
    })

    if (error.response) {
      switch (error.response.status) {
        case 401:
          console.log('[Response Error] 401 Unauthorized - 清除 token 并跳转登录页')
          ElMessage.error('登录已失效，请重新登录')
          removeToken()
          // 使用 setTimeout 避免在请求过程中立即跳转
          setTimeout(() => {
            window.location.href = '/login'
          }, 100)
          break
        case 403:
          ElMessage.error('拒绝访问：权限不足')
          break
        case 404:
          ElMessage.error('请求地址不存在：' + (error.config?.url || ''))
          break
        case 500:
          ElMessage.error('服务器错误')
          break
        default:
          ElMessage.error(error.message || '请求失败')
      }
    } else {
      // 网络错误或后端未启动，不清除 token
      console.log('[Response Error] 网络错误，保留 token')
      ElMessage.error('网络错误或后端服务不可用，请检查后端是否启动')
    }
    return Promise.reject(error)
  }
)

export default request
