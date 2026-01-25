<template>
  <el-container class="layout-container">
    <el-aside width="200px" class="aside">
      <div class="logo">
        <h2>观之后台</h2>
      </div>
      <el-menu
        router
        :default-active="$route.path"
        class="el-menu-vertical"
        background-color="#304156"
        text-color="#bfcbd9"
        active-text-color="#409EFF"
      >
        <el-menu-item index="/dashboard">
          <el-icon><Odometer /></el-icon>
          <span>仪表盘</span>
        </el-menu-item>
        
        <el-menu-item index="/fade-simulation">
          <el-icon><TrendCharts /></el-icon>
          <span>褪色模拟器</span>
        </el-menu-item>

        <el-menu-item index="/notification">
          <el-icon><Bell /></el-icon>
          <span>系统通知</span>
        </el-menu-item>

        <el-sub-menu index="/config">
          <template #title>
            <el-icon><Setting /></el-icon>
            <span>配置管理</span>
          </template>
          <el-menu-item index="/config/fade">褪色规则配置</el-menu-item>
          <el-menu-item index="/config/points">积分规则配置</el-menu-item>
          <el-menu-item index="/config/level">等级定义管理</el-menu-item>
          <el-menu-item index="/config/tag">标签定义管理</el-menu-item>
          <el-menu-item index="/config/notification-events">通知事件配置</el-menu-item>
          <el-menu-item index="/config/notification-templates">通知模板管理</el-menu-item>
        </el-sub-menu>

        <el-menu-item index="/inspector/query">
          <el-icon><Search /></el-icon>
          <span>综合查询</span>
        </el-menu-item>

        <el-menu-item index="/reports">
          <el-icon><Warning /></el-icon>
          <span>举报管理</span>
        </el-menu-item>
      </el-menu>
    </el-aside>
    
    <el-container>
      <el-header class="header">
        <div class="header-right">
          <el-dropdown @command="handleCommand">
            <span class="el-dropdown-link">
              管理员 <el-icon class="el-icon--right"><arrow-down /></el-icon>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="logout">退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>
      
      <el-main>
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'

const router = useRouter()

const handleCommand = (command) => {
  if (command === 'logout') {
    localStorage.removeItem('token')
    ElMessage.success('退出成功')
    router.push('/login')
  }
}
</script>

<style scoped>
.layout-container {
  height: 100vh;
}

.aside {
  background-color: #304156;
  color: #fff;
}

.logo {
  height: 60px;
  line-height: 60px;
  text-align: center;
  background-color: #2b2f3a;
}

.logo h2 {
  margin: 0;
  color: #fff;
  font-size: 20px;
}

.header {
  background-color: #fff;
  border-bottom: 1px solid #dcdfe6;
  display: flex;
  justify-content: flex-end;
  align-items: center;
}

.el-dropdown-link {
  cursor: pointer;
  display: flex;
  align-items: center;
}

.el-menu-vertical {
  border-right: none;
}
</style>