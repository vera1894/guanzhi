const api = require('../../utils/api')
const coord = require('../../utils/coordinate')
const app = getApp()

Page({
  data: {
    shares: [],
    loading: true,
    loadingMore: false,
    noMore: false,
    page: 1,
    size: 20,
    refreshing: false
  },

  onLoad() {
    const location = app.globalData.userLocation
    if (location) {
      this.userLocation = location
      this.loadShares()
    } else {
      app.locationReadyCallback = (loc) => {
        this.userLocation = loc
        this.loadShares()
      }
    }
  },

  onShow() {
    if (typeof this.getTabBar === 'function' && this.getTabBar()) {
      this.getTabBar().setData({ selected: 1 })
    }
  },

  loadShares(append = false) {
    if (!this.userLocation) return

    if (!append) {
      this.setData({ loading: true })
    }

    // GCJ-02 -> WGS-84 for API
    const wgs = coord.gcj02ToWgs84(
      this.userLocation.latitude,
      this.userLocation.longitude
    )

    api.getNearbyShares(wgs.latitude, wgs.longitude, {
      radius: 50000,
      page: this.data.page,
      size: this.data.size
    }).then(data => {
      const list = data.list || data || []
      const newShares = Array.isArray(list) ? list : []

      // 计算每个分享的距离
      const sharesWithDistance = newShares.map(item => {
        let distance = ''
        if (item.latitude && item.longitude && this.userLocation) {
          const gcj = coord.wgs84ToGcj02(item.latitude, item.longitude)
          const meters = coord.getDistance(
            this.userLocation.latitude,
            this.userLocation.longitude,
            gcj.latitude,
            gcj.longitude
          )
          distance = coord.formatDistance(meters)
        }
        return { ...item, distance }
      })

      this.setData({
        shares: append ? [...this.data.shares, ...sharesWithDistance] : sharesWithDistance,
        loading: false,
        loadingMore: false,
        refreshing: false,
        noMore: newShares.length < this.data.size
      })
    }).catch(() => {
      this.setData({
        loading: false,
        loadingMore: false,
        refreshing: false
      })
    })
  },

  // 下拉刷新
  onRefresh() {
    this.setData({ page: 1, noMore: false, refreshing: true })
    this.loadShares(false)
  },

  // 触底加载更多
  onLoadMore() {
    if (this.data.loadingMore || this.data.noMore) return
    this.setData({
      page: this.data.page + 1,
      loadingMore: true
    })
    this.loadShares(true)
  },

  // 跳转详情
  goToDetail(e) {
    const shareId = e.currentTarget.dataset.id
    wx.navigateTo({
      url: `/pages/detail/detail?id=${shareId}`
    })
  },

  onShareAppMessage() {
    return {
      title: '观之 - 发现身边的精彩',
      path: '/pages/list/list'
    }
  },

  onShareTimeline() {
    return {
      title: '观之 - 发现身边的精彩'
    }
  }
})
