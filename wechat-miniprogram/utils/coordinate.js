/**
 * WGS-84 <-> GCJ-02 坐标转换
 * 中国境内使用 GCJ-02（火星坐标系），需要对 WGS-84 坐标做偏移
 */

const PI = Math.PI
const A = 6378245.0 // 长半轴
const EE = 0.00669342162296594323 // 偏心率平方

function transformLat(x, y) {
  let ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(Math.abs(x))
  ret += (20.0 * Math.sin(6.0 * x * PI) + 20.0 * Math.sin(2.0 * x * PI)) * 2.0 / 3.0
  ret += (20.0 * Math.sin(y * PI) + 40.0 * Math.sin(y / 3.0 * PI)) * 2.0 / 3.0
  ret += (160.0 * Math.sin(y / 12.0 * PI) + 320 * Math.sin(y * PI / 30.0)) * 2.0 / 3.0
  return ret
}

function transformLon(x, y) {
  let ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x))
  ret += (20.0 * Math.sin(6.0 * x * PI) + 20.0 * Math.sin(2.0 * x * PI)) * 2.0 / 3.0
  ret += (20.0 * Math.sin(x * PI) + 40.0 * Math.sin(x / 3.0 * PI)) * 2.0 / 3.0
  ret += (150.0 * Math.sin(x / 12.0 * PI) + 300.0 * Math.sin(x / 30.0 * PI)) * 2.0 / 3.0
  return ret
}

/**
 * 判断坐标是否在中国境内
 */
function isInChina(lat, lon) {
  return (lon > 73.66 && lon < 135.05 && lat > 3.86 && lat < 53.55)
}

/**
 * WGS-84 -> GCJ-02
 */
function wgs84ToGcj02(lat, lon) {
  if (!isInChina(lat, lon)) {
    return { latitude: lat, longitude: lon }
  }
  let dLat = transformLat(lon - 105.0, lat - 35.0)
  let dLon = transformLon(lon - 105.0, lat - 35.0)
  const radLat = lat / 180.0 * PI
  let magic = Math.sin(radLat)
  magic = 1 - EE * magic * magic
  const sqrtMagic = Math.sqrt(magic)
  dLat = (dLat * 180.0) / ((A * (1 - EE)) / (magic * sqrtMagic) * PI)
  dLon = (dLon * 180.0) / (A / sqrtMagic * Math.cos(radLat) * PI)
  return {
    latitude: lat + dLat,
    longitude: lon + dLon
  }
}

/**
 * GCJ-02 -> WGS-84（逆向转换，迭代法）
 */
function gcj02ToWgs84(lat, lon) {
  if (!isInChina(lat, lon)) {
    return { latitude: lat, longitude: lon }
  }
  const gcj = wgs84ToGcj02(lat, lon)
  return {
    latitude: lat * 2 - gcj.latitude,
    longitude: lon * 2 - gcj.longitude
  }
}

/**
 * 计算两点间距离（米）- Haversine 公式
 * 输入均为 GCJ-02 坐标
 */
function getDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000
  const dLat = (lat2 - lat1) * PI / 180
  const dLon = (lon2 - lon1) * PI / 180
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * PI / 180) * Math.cos(lat2 * PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

/**
 * 格式化距离显示
 */
function formatDistance(meters) {
  if (meters < 100) {
    return '< 100m'
  } else if (meters < 1000) {
    return Math.round(meters) + 'm'
  } else if (meters < 10000) {
    return (meters / 1000).toFixed(1) + 'km'
  } else {
    return Math.round(meters / 1000) + 'km'
  }
}

module.exports = {
  wgs84ToGcj02,
  gcj02ToWgs84,
  isInChina,
  getDistance,
  formatDistance
}
