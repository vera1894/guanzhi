const api = require('../../utils/api')
const coord = require('../../utils/coordinate')
const app = getApp()

Page({
  data: {
    latitude: 39.9042,
    longitude: 116.4074,
    scale: 14,
    markers: [],
    shares: [],
    selectedShare: null,
    showCard: false,
    loading: true,
    mapHeight: 0
  },

  onLoad() {
    // 计算地图高度（全屏减去底部 tabBar）
    const sysInfo = wx.getSystemInfoSync()
    this.setData({
      mapHeight: sysInfo.windowHeight
    })

    const location = app.globalData.userLocation
    if (location) {
      this.initMap(location)
    } else {
      app.locationReadyCallback = (loc) => {
        this.initMap(loc)
      }
    }
  },

  onShow() {
    if (typeof this.getTabBar === 'function' && this.getTabBar()) {
      this.getTabBar().setData({ selected: 0 })
    }
  },

  initMap(location) {
    this.setData({
      latitude: location.latitude,
      longitude: location.longitude
    })
    this.loadNearbyShares()
  },

  loadNearbyShares() {
    this.setData({ loading: true })
    // 地图使用 GCJ-02 坐标，API 需要 WGS-84
    const wgs = coord.gcj02ToWgs84(this.data.latitude, this.data.longitude)
    api.getNearbyShares(wgs.latitude, wgs.longitude, {
      radius: this.getRadiusByScale(this.data.scale),
      page: 1,
      size: 50
    }).then(data => {
      const list = data.list || data || []
      const shares = Array.isArray(list) ? list : []
      const markers = shares.map((item, index) => {
        const gcj = coord.wgs84ToGcj02(item.latitude, item.longitude)
        return {
          id: index,
          latitude: gcj.latitude,
          longitude: gcj.longitude,
          width: 36,
          height: 36,
          iconPath: '/assets/marker.png',
          callout: {
            content: item.data ? item.data.substring(0, 20) : (item.title || ''),
            display: 'BYCLICK',
            bgColor: '#ffffff',
            padding: 8,
            borderRadius: 8,
            fontSize: 13
          }
        }
      })
      this.setData({ shares, markers, loading: false })
    }).catch(() => {
      this.setData({ loading: false })
    })
  },

  // 根据地图缩放级别估算搜索半径
  getRadiusByScale(scale) {
    const radiusMap = {
      3: 5000000, 4: 2000000, 5: 1000000, 6: 500000,
      7: 200000, 8: 100000, 9: 50000, 10: 25000,
      11: 15000, 12: 8000, 13: 5000, 14: 3000,
      15: 1500, 16: 800, 17: 400, 18: 200, 19: 100, 20: 50
    }
    return radiusMap[scale] || 5000
  },

  // 地图视野变化后重新加载
  onRegionChange(e) {
    if (e.type === 'end' && e.causedBy === 'drag') {
      this.mapCtx = this.mapCtx || wx.createMapContext('mainMap')
      this.mapCtx.getCenterLocation({
        success: (res) => {
          this.setData({
            latitude: res.latitude,
            longitude: res.longitude
          })
          this.loadNearbyShares()
        }
      })
    }
  },

  onScaleChange(e) {
    this.setData({ scale: e.detail.scale })
  },

  // 点击标记点
  onMarkerTap(e) {
    const markerId = e.markerId
    const share = this.data.shares[markerId]
    if (share) {
      this.setData({
        selectedShare: share,
        showCard: true
      })
    }
  },

  // 关闭预览卡片
  closeCard() {
    this.setData({ showCard: false, selectedShare: null })
  },

  // 跳转详情
  goToDetail() {
    if (this.data.selectedShare) {
      wx.navigateTo({
        url: `/pages/detail/detail?id=${this.data.selectedShare.shareId}`
      })
    }
  },

  // 回到当前位置
  moveToLocation() {
    this.mapCtx = this.mapCtx || wx.createMapContext('mainMap')
    this.mapCtx.moveToLocation()
  },

  onShareAppMessage() {
    return {
      title: '观之 - 发现身边的精彩',
      path: '/pages/index/index'
    }
  },

  onShareTimeline() {
    return {
      title: '观之 - 发现身边的精彩'
    }
  }
})
