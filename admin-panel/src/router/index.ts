import { createRouter, createWebHistory } from 'vue-router'
import { isAuthenticated } from '../utils/auth'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('../views/login/index.vue'),
    meta: { requiresAuth: false }
  },
  {
    path: '/',
    name: 'Dashboard',
    component: () => import('../views/dashboard/index.vue'),
    meta: { requiresAuth: true },
    redirect: '/fade-simulator',
    children: [
      {
        path: '/fade-simulator',
        name: 'FadeSimulator',
        component: () => import('../views/fade-simulator/index.vue'),
        meta: { requiresAuth: true, title: '褪色曲线模拟器' }
      },
      {
        path: '/configs/fade',
        name: 'FadeConfig',
        component: () => import('../views/configs/FadeConfig.vue'),
        meta: { requiresAuth: true, title: '褪色规则配置' }
      },
      {
        path: '/configs/points',
        name: 'PointsConfig',
        component: () => import('../views/configs/PointsConfig.vue'),
        meta: { requiresAuth: true, title: '积分规则配置' }
      },
      {
        path: '/configs/levels',
        name: 'LevelsConfig',
        component: () => import('../views/configs/LevelsConfig.vue'),
        meta: { requiresAuth: true, title: '等级定义管理' }
      },
      {
        path: '/configs/tags',
        name: 'TagsConfig',
        component: () => import('../views/configs/TagsConfig.vue'),
        meta: { requiresAuth: true, title: '标签定义管理' }
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to, from, next) => {
  const requiresAuth = to.meta.requiresAuth !== false
  const authenticated = isAuthenticated()

  console.log('[Router Guard]', {
    to: to.path,
    from: from.path,
    requiresAuth,
    authenticated
  })

  if (requiresAuth && !authenticated) {
    console.log('[Router Guard] 未认证，重定向到登录页')
    next('/login')
  } else if (to.path === '/login' && authenticated) {
    console.log('[Router Guard] 已认证，重定向到首页')
    next('/')
  } else {
    console.log('[Router Guard] 允许导航')
    next()
  }
})

export default router
