const api = require('../../utils/api')
const coord = require('../../utils/coordinate')
const app = getApp()

Page({
  data: {
    shareId: '',
    share: null,
    mediaItems: [],
    loading: true,
    error: false,
    mapLatitude: 0,
    mapLongitude: 0,
    mapMarkers: [],
    currentMediaIndex: 0
  },

  onLoad(options) {
    if (options.id) {
      this.setData({ shareId: options.id })
      this.loadDetail(options.id)
    }
  },

  loadDetail(shareId) {
    this.setData({ loading: true, error: false })
    api.getShareDetail(shareId).then(data => {
      // 处理媒体列表（后端 SharePublicDTO 返回 mediaItems）
      const mediaItems = (data.mediaItems || []).map(item => ({
        type: item.type === 'video' ? 'video' : 'image',
        url: item.type === 'video' ? item.videoUrl : item.imageUrl,
        thumbnailUrl: item.imageUrl
      }))

      // 坐标转换用于地图显示
      let mapLat = 0, mapLon = 0, mapMarkers = []
      if (data.latitude && data.longitude) {
        const gcj = coord.wgs84ToGcj02(data.latitude, data.longitude)
        mapLat = gcj.latitude
        mapLon = gcj.longitude
        mapMarkers = [{
          id: 0,
          latitude: gcj.latitude,
          longitude: gcj.longitude,
          width: 32,
          height: 32,
          iconPath: '/assets/marker.png'
        }]
      }

      this.setData({
        share: data,
        mediaItems,
        mapLatitude: mapLat,
        mapLongitude: mapLon,
        mapMarkers: mapMarkers,
        formattedTime: this.formatTime(data.createDate),
        loading: false
      })
    }).catch(() => {
      this.setData({ loading: false, error: true })
    })
  },

  // 媒体轮播切换
  onSwiperChange(e) {
    this.setData({ currentMediaIndex: e.detail.current })
  },

  // 预览图片（全屏）
  previewImage(e) {
    const index = e.currentTarget.dataset.index
    const urls = this.data.mediaItems
      .filter(m => m.type === 'image')
      .map(m => m.url)
    if (urls.length > 0) {
      wx.previewImage({
        current: urls[index] || urls[0],
        urls: urls
      })
    }
  },

  // 导航到位置
  openLocation() {
    const share = this.data.share
    if (share && share.latitude && share.longitude) {
      // wx.openLocation 使用 GCJ-02
      const gcj = coord.wgs84ToGcj02(share.latitude, share.longitude)
      wx.openLocation({
        latitude: gcj.latitude,
        longitude: gcj.longitude,
        name: share.address || '分享位置',
        address: share.address || ''
      })
    }
  },

  // 查看作者主页
  goToProfile() {
    const share = this.data.share
    if (share && share.authorId) {
      wx.navigateTo({
        url: `/pages/profile/profile?userId=${share.authorId}`
      })
    }
  },

  // 打开 App 失败，引导下载
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

  // 格式化时间
  formatTime(timestamp) {
    if (!timestamp) return ''
    const date = new Date(timestamp)
    const year = date.getFullYear()
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hour = date.getHours().toString().padStart(2, '0')
    const min = date.getMinutes().toString().padStart(2, '0')
    return `${year}-${month}-${day} ${hour}:${min}`
  },

  onShareAppMessage() {
    const share = this.data.share
    return {
      title: share ? (share.data || '').substring(0, 30) || '来看看这个分享' : '观之 - 发现身边的精彩',
      path: `/pages/detail/detail?id=${this.data.shareId}`,
      imageUrl: share && share.coverImageUrl ? share.coverImageUrl : ''
    }
  },

  onShareTimeline() {
    const share = this.data.share
    return {
      title: share ? (share.data || '').substring(0, 30) || '来看看这个分享' : '观之 - 发现身边的精彩',
      query: `id=${this.data.shareId}`,
      imageUrl: share && share.coverImageUrl ? share.coverImageUrl : ''
    }
  }
})
