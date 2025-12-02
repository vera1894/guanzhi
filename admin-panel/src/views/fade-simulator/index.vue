<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import { ElMessage } from 'element-plus'
import * as echarts from 'echarts'
import { simulateFadeScore, type FadeSimulationRequest } from '../../api/admin'

const loading = ref(false)
const chartInstance = ref<echarts.ECharts | null>(null)
const chartRef = ref<HTMLElement | null>(null)

const form = ref<FadeSimulationRequest>({
  viewCount: 50,
  tagCount: 2,
  simulateDays: 90
})

const result = ref({
  currentFadeScore: 0,
  estimatedFadeDays: 0,
  dailyFadeIncrement: 0,
  configInfo: ''
})

const initChart = () => {
  if (!chartRef.value) return

  if (chartInstance.value) {
    chartInstance.value.dispose()
  }

  chartInstance.value = echarts.init(chartRef.value)

  const option: echarts.EChartsOption = {
    title: {
      text: '褪色曲线',
      left: 'center'
    },
    tooltip: {
      trigger: 'axis',
      formatter: (params: any) => {
        const data = params[0]
        return `第 ${data.name} 天<br/>褪色分数: ${data.value}`
      }
    },
    xAxis: {
      type: 'category',
      name: '天数',
      data: [],
      axisLabel: {
        formatter: '{value} 天'
      }
    },
    yAxis: {
      type: 'value',
      name: '褪色分数',
      min: 0,
      max: 100
    },
    series: [
      {
        name: '褪色分数',
        type: 'line',
        smooth: true,
        data: [],
        markLine: {
          data: [
            { yAxis: 100, label: { formatter: '完全褪色 (100分)' } }
          ],
          lineStyle: {
            color: '#f56c6c',
            type: 'dashed'
          }
        },
        itemStyle: {
          color: '#409eff'
        },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(64, 158, 255, 0.3)' },
            { offset: 1, color: 'rgba(64, 158, 255, 0.05)' }
          ])
        }
      }
    ],
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      containLabel: true
    }
  }

  chartInstance.value.setOption(option)
}

const handleSimulate = async () => {
  if (!form.value.viewCount || form.value.viewCount < 0) {
    ElMessage.warning('请输入有效的浏览人数')
    return
  }

  if (form.value.tagCount == null || form.value.tagCount < 0) {
    ElMessage.warning('请输入有效的负面标签数')
    return
  }

  loading.value = true

  try {
    const response = await simulateFadeScore(form.value)
    const data = response.datas

    result.value = {
      currentFadeScore: data.currentFadeScore,
      estimatedFadeDays: data.estimatedFadeDays,
      dailyFadeIncrement: data.dailyFadeIncrement,
      configInfo: data.configInfo
    }

    if (chartInstance.value) {
      chartInstance.value.setOption({
        xAxis: {
          data: data.timeline
        },
        series: [
          {
            data: data.fadeScores
          }
        ]
      })
    }

    ElMessage.success('模拟成功')
  } catch (error: any) {
    ElMessage.error(error.message || '模拟失败')
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await nextTick()
  initChart()
  handleSimulate()

  window.addEventListener('resize', () => {
    chartInstance.value?.resize()
  })
})
</script>

<template>
  <div class="page-container">
    <el-row :gutter="20">
      <el-col :span="8">
        <el-card>
          <template #header>
            <div class="card-header">
              <span class="card-title">模拟参数</span>
            </div>
          </template>

          <el-form :model="form" label-width="120px">
            <el-form-item label="浏览人数">
              <el-input-number
                v-model="form.viewCount"
                :min="0"
                :max="10000"
                style="width: 100%"
              />
              <div style="color: #909399; font-size: 12px; margin-top: 4px;">
                影响基础褪色速度（分档：≤5, ≤20, ≤50, ≤100, >100）
              </div>
            </el-form-item>

            <el-form-item label="负面标签数">
              <el-input-number
                v-model="form.tagCount"
                :min="0"
                :max="10"
                style="width: 100%"
              />
              <div style="color: #909399; font-size: 12px; margin-top: 4px;">
                每个负面标签减缓褪色速度
              </div>
            </el-form-item>

            <el-form-item label="模拟天数">
              <el-input-number
                v-model="form.simulateDays"
                :min="1"
                :max="365"
                style="width: 100%"
              />
            </el-form-item>

            <el-form-item>
              <el-button
                type="primary"
                :loading="loading"
                @click="handleSimulate"
                style="width: 100%"
              >
                开始模拟
              </el-button>
            </el-form-item>
          </el-form>

          <el-divider />

          <div class="result-info">
            <h4>模拟结果</h4>
            <div class="info-item">
              <span class="label">当前褪色分数：</span>
              <span class="value">{{ result.currentFadeScore }} 分</span>
            </div>
            <div class="info-item">
              <span class="label">每日褪色增量：</span>
              <span class="value">{{ result.dailyFadeIncrement.toFixed(1) }} 分/天</span>
            </div>
            <div class="info-item">
              <span class="label">预计完全褪色：</span>
              <span class="value" style="color: #f56c6c; font-weight: 600;">
                {{ result.estimatedFadeDays }} 天
              </span>
            </div>
            <div class="info-item" style="margin-top: 12px;">
              <span class="label">配置详情：</span>
              <div style="color: #606266; font-size: 12px; margin-top: 4px; line-height: 1.5;">
                {{ result.configInfo }}
              </div>
            </div>
          </div>
        </el-card>
      </el-col>

      <el-col :span="16">
        <el-card>
          <template #header>
            <div class="card-header">
              <span class="card-title">褪色曲线</span>
            </div>
          </template>

          <div ref="chartRef" style="width: 100%; height: 500px;"></div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<style scoped>
.result-info h4 {
  margin: 0 0 16px 0;
  font-size: 16px;
  font-weight: 600;
  color: #303133;
}

.info-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
  padding: 8px 0;
}

.info-item .label {
  color: #606266;
  font-size: 14px;
}

.info-item .value {
  color: #303133;
  font-size: 14px;
  font-weight: 500;
}
</style>
