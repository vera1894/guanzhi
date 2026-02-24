Component({
  properties: {
    mediaItems: {
      type: Array,
      value: []
    }
  },

  data: {
    currentIndex: 0,
    swiperHeight: 750 // 默认高度 rpx
  },

  methods: {
    onSwiperChange(e) {
      this.setData({ currentIndex: e.detail.current })
    },

    // 预览图片
    onImageTap(e) {
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

    // 图片加载完成后调整高度
    onImageLoad(e) {
      if (this.data.currentIndex === 0) {
        const { width, height } = e.detail
        const screenWidth = 750 // rpx
        const ratio = height / width
        const swiperHeight = Math.min(Math.max(screenWidth * ratio, 400), 1000)
        this.setData({ swiperHeight })
      }
    }
  }
})
