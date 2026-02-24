const app = getApp()

Component({
  properties: {
    // 'bottom' = 固定在底部(地图页), 'float' = 浮动小条(列表页)
    position: {
      type: String,
      value: 'bottom'
    }
  },

  data: {
    visible: true
  },

  methods: {
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

    close() {
      this.setData({ visible: false })
    }
  }
})
