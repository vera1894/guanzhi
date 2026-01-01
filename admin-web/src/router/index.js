import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('../views/Login.vue')
  },
  {
    path: '/',
    name: 'Layout',
    component: () => import('../layout/Layout.vue'),
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('../views/Dashboard.vue')
      },
      {
        path: 'fade-simulation',
        name: 'FadeSimulation',
        component: () => import('../views/FadeSimulation.vue')
      },
      {
        path: 'notification',
        name: 'SystemNotification',
        component: () => import('../views/SystemNotification.vue')
      },
      {
        path: 'config',
        name: 'Config',
        children: [
          {
            path: 'fade',
            name: 'FadeConfig',
            component: () => import('../views/config/FadeConfig.vue')
          },
          {
            path: 'points',
            name: 'PointsRule',
            component: () => import('../views/config/PointsRule.vue')
          },
          {
            path: 'level',
            name: 'LevelDefinition',
            component: () => import('../views/config/LevelDefinition.vue')
          },
          {
            path: 'tag',
            name: 'TagDefinition',
            component: () => import('../views/config/TagDefinition.vue')
          },
          {
            path: 'notification-events',
            name: 'NotificationEventConfig',
            component: () => import('../views/notification/EventConfig.vue')
          },
          {
            path: 'notification-templates',
            name: 'NotificationTemplateConfig',
            component: () => import('../views/notification/TemplateConfig.vue')
          }
        ]
      },
      {
        path: 'inspector',
        name: 'Inspector',
        redirect: '/inspector/query',
        children: [
          {
            path: 'query',
            name: 'ComprehensiveQuery',
            component: () => import('../views/inspector/ComprehensiveQuery.vue')
          },
          {
            path: 'user',
            name: 'UserDetail',
            component: () => import('../views/inspector/UserDetail.vue')
          },
          {
            path: 'share',
            name: 'ShareDetail',
            component: () => import('../views/inspector/ShareDetail.vue')
          }
        ]
      }
    ]
  }
]

const router = createRouter({
  // 生产环境使用 /guanzhi-admin/ 作为基础路径
  history: createWebHistory(import.meta.env.BASE_URL),
  routes
})

router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token')
  if (to.path !== '/login' && !token) {
    next('/login')
  } else {
    next()
  }
})

export default router
