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
          }
        ]
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
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
