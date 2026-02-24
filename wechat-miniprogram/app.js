App({
  globalData: {
    baseUrl: 'https://onettoo.com',
    userLocation: null, // { latitude, longitude } in GCJ-02
    appStoreUrl: 'https://apps.apple.com/app/id6746823606'
  },

  onLaunch() {
    this.getUserLocation()
  },

  getUserLocation() {
    const that = this
    wx.getLocation({
      type: 'gcj02',
      success(res) {
        that.globalData.userLocation = {
          latitude: res.latitude,
          longitude: res.longitude
        }
        if (that.locationReadyCallback) {
          that.locationReadyCallback(that.globalData.userLocation)
        }
      },
      fail() {
        // 用户拒绝授权，使用默认位置（北京）
        that.globalData.userLocation = {
          latitude: 39.9042,
          longitude: 116.4074
        }
        if (that.locationReadyCallback) {
          that.locationReadyCallback(that.globalData.userLocation)
        }
      }
    })
  }
})
