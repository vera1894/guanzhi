Component({
  properties: {
    share: {
      type: Object,
      value: {}
    },
    distance: {
      type: String,
      value: ''
    }
  },

  data: {
    coverUrl: '',
    hasMedia: false
  },

  observers: {
    'share': function(share) {
      if (!share) return
      // 确定封面图
      let coverUrl = ''
      let hasMedia = false
      if (share.coverImageUrl) {
        coverUrl = share.coverImageUrl
        hasMedia = true
      } else if (share.mediaItems && share.mediaItems.length > 0) {
        const first = share.mediaItems[0]
        coverUrl = first.imageUrl || ''
        hasMedia = true
      }
      this.setData({ coverUrl, hasMedia })
    }
  }
})
