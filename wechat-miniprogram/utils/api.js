const BASE_URL = 'https://onettoo.com'

/**
 * 封装 wx.request，统一错误处理
 */
function request(url, options = {}) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${BASE_URL}${url}`,
      method: options.method || 'GET',
      data: options.data || {},
      header: {
        'Content-Type': 'application/json',
        ...options.header
      },
      success(res) {
        if (res.statusCode === 200 && res.data && res.data.respCode === 0) {
          resolve(res.data.datas)
        } else {
          const msg = (res.data && res.data.respMsg) || '请求失败'
          reject(new Error(msg))
        }
      },
      fail(err) {
        reject(new Error(err.errMsg || '网络错误'))
      }
    })
  })
}

/**
 * 获取分享详情
 */
function getShareDetail(shareId) {
  return request(`/api/mp/share/${shareId}`)
}

/**
 * 获取附近分享列表
 */
function getNearbyShares(latitude, longitude, options = {}) {
  const { radius = 5000, page = 1, size = 20 } = options
  return request('/api/mp/shares/nearby', {
    data: { latitude, longitude, radius, page, size }
  })
}

/**
 * 获取用户公开信息
 */
function getUserProfile(userId) {
  return request(`/api/mp/user/${userId}/profile`)
}

/**
 * 获取用户的分享列表
 */
function getUserShares(userId, options = {}) {
  const { page = 1, size = 20 } = options
  return request(`/api/mp/user/${userId}/shares`, {
    data: { page, size }
  })
}

module.exports = {
  getShareDetail,
  getNearbyShares,
  getUserProfile,
  getUserShares,
  BASE_URL
}
