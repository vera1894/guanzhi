import axios, { AxiosInstance, AxiosError, InternalAxiosRequestConfig, AxiosResponse } from 'axios'
import { ElMessage } from 'element-plus'
import { getToken, removeToken } from '../utils/auth'

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8085/api'

const request: AxiosInstance = axios.create({
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
      config.headers.Authorization = `Bearer ${token}`
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

    if (respCode === 0) {
      return response.data
    } else {
      ElMessage.error(respMsg || '请求失败')
      return Promise.reject(new Error(respMsg || '请求失败'))
    }
  },
  (error: AxiosError) => {
    if (error.response) {
      switch (error.response.status) {
        case 401:
          ElMessage.error('未授权，请重新登录')
          removeToken()
          window.location.href = '/login'
          break
        case 403:
          ElMessage.error('拒绝访问')
          break
        case 404:
          ElMessage.error('请求地址不存在')
          break
        case 500:
          ElMessage.error('服务器错误')
          break
        default:
          ElMessage.error(error.message || '请求失败')
      }
    } else {
      ElMessage.error('网络错误，请检查网络连接')
    }
    return Promise.reject(error)
  }
)

export default request
