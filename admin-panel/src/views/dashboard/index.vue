<script setup lang="ts">
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { removeToken } from '../../utils/auth'

const router = useRouter()
const route = useRoute()
const collapsed = ref(false)

const handleLogout = () => {
  ElMessageBox.confirm('确定要退出登录吗？', '提示', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  })
    .then(() => {
      removeToken()
      ElMessage.success('已退出登录')
      router.push('/login')
    })
    .catch(() => {})
}

const menuItems = [
  {
    path: '/fade-simulator',
    icon: 'TrendCharts',
    title: '褪色曲线模拟器'
  },
  {
    path: '/configs/fade',
    icon: 'Setting',
    title: '褪色规则配置'
  },
  {
    path: '/configs/points',
    icon: 'Coin',
    title: '积分规则配置'
  },
  {
    path: '/configs/levels',
    icon: 'Trophy',
    title: '等级定义管理'
  },
  {
    path: '/configs/tags',
    icon: 'PriceTag',
    title: '标签定义管理'
  }
]
</script>

<template>
  <div class="dashboard-container">
    <el-container>
      <el-aside :width="collapsed ? '64px' : '240px'">
        <div class="logo">
          <span v-if="!collapsed">观之管理后台</span>
          <span v-else>观</span>
        </div>

        <el-menu
          :default-active="route.path"
          :collapse="collapsed"
          :router="true"
        >
          <el-menu-item
            v-for="item in menuItems"
            :key="item.path"
            :index="item.path"
          >
            <el-icon><component :is="item.icon" /></el-icon>
            <template #title>{{ item.title }}</template>
          </el-menu-item>
        </el-menu>

        <div class="collapse-btn" @click="collapsed = !collapsed">
          <el-icon>
            <component :is="collapsed ? 'Expand' : 'Fold'" />
          </el-icon>
        </div>
      </el-aside>

      <el-container>
        <el-header>
          <div class="header-left">
            <h2>{{ route.meta.title || '管理后台' }}</h2>
          </div>
          <div class="header-right">
            <el-button type="danger" plain @click="handleLogout">
              退出登录
            </el-button>
          </div>
        </el-header>

        <el-main>
          <router-view />
        </el-main>
      </el-container>
    </el-container>
  </div>
</template>

<style scoped>
.dashboard-container {
  height: 100vh;
}

.el-aside {
  background-color: #304156;
  transition: width 0.3s;
  display: flex;
  flex-direction: column;
}

.logo {
  height: 60px;
  line-height: 60px;
  text-align: center;
  font-size: 20px;
  font-weight: 600;
  color: white;
  background-color: #1f2d3d;
}

.el-menu {
  border: none;
  flex: 1;
  background-color: #304156;
}

:deep(.el-menu-item) {
  color: #bfcbd9;
}

:deep(.el-menu-item:hover) {
  background-color: #263445 !important;
  color: #fff;
}

:deep(.el-menu-item.is-active) {
  background-color: #409eff !important;
  color: #fff;
}

.collapse-btn {
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  cursor: pointer;
  border-top: 1px solid #1f2d3d;
}

.collapse-btn:hover {
  background-color: #263445;
}

.el-header {
  background-color: white;
  box-shadow: 0 1px 4px rgba(0, 21, 41, 0.08);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
}

.header-left h2 {
  margin: 0;
  font-size: 18px;
  font-weight: 500;
  color: #303133;
}

.el-main {
  background-color: #f0f2f5;
  padding: 20px;
}
</style>
