const api = require('../../utils/api')
const coord = require('../../utils/coordinate')
const app = getApp()

Page({
  data: {
    userId: '',
    user: null,
    shares: [],
    loading: true,
    error: false
  },

  onLoad(options) {
    if (options.userId) {
      this.setData({ userId: options.userId })
      this.loadProfile(options.userId)
    }
  },

  loadProfile(userId) {
    this.setData({ loading: true, error: false })

    // 并行请求用户信息和分享列表
    Promise.all([
      api.getUserProfile(userId),
      api.getUserShares(userId, { page: 1, size: 50 }).catch(() => [])
    ]).then(([userData, sharesData]) => {
      const shares = Array.isArray(sharesData) ? sharesData : (sharesData.list || [])

      // 计算距离
      const location = app.globalData.userLocation
      const sharesWithDistance = shares.map(item => {
        let distance = ''
        if (item.latitude && item.longitude && location) {
          const gcj = coord.wgs84ToGcj02(item.latitude, item.longitude)
          const meters = coord.getDistance(
            location.latitude,
            location.longitude,
            gcj.latitude,
            gcj.longitude
          )
          distance = coord.formatDistance(meters)
        }
        return { ...item, distance }
      })

      this.setData({
        user: userData,
        shares: sharesWithDistance,
        loading: false
      })
    }).catch(() => {
      this.setData({ loading: false, error: true })
    })
  },

  // 跳转详情
  goToDetail(e) {
    const shareId = e.currentTarget.dataset.id
    wx.navigateTo({
      url: `/pages/detail/detail?id=${shareId}`
    })
  },

  // 打开 App 失败
  onLaunchAppError() {
    wx.showModal({
      title: '未安装观之 App',
      content: '前往 App Store 下载「观之」，获得完整体验',
      confirmText: '去下载',
      success(res) {
        if (res.confirm) {
          wx.setClipboardData({
            data: app.globalData.appStoreUrl,
            success() {
              wx.showToast({ title: '链接已复制', icon: 'success' })
            }
          })
        }
      }
    })
  },

  onShareAppMessage() {
    const user = this.data.user
    return {
      title: user ? `${user.nickname} 的观之主页` : '观之 - 发现身边的精彩',
      path: `/pages/profile/profile?userId=${this.data.userId}`
    }
  }
})
