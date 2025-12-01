<template>
  <div class="app-container">
    <el-card class="box-card">
      <template #header>
        <div class="card-header">
          <span>褪色算法模拟器</span>
          <el-tag type="success">后端计算</el-tag>
        </div>
      </template>
      
      <el-row :gutter="20">
        <!-- 左侧：参数设置 -->
        <el-col :span="8">
          <el-form :model="form" label-width="100px">
            <el-form-item label="阅读人数">
              <el-input-number v-model="form.viewCount" :min="0" :step="10" />
              <div class="form-tip">影响基础褪色速度</div>
            </el-form-item>
            
            <el-form-item label="被贴标签数">
              <el-input-number v-model="form.tagCount" :min="0" />
              <div class="form-tip">负面标签会加速/减缓褪色</div>
            </el-form-item>
            
            <el-form-item label="模拟天数">
              <el-slider v-model="form.simulateDays" :min="7" :max="365" show-input />
            </el-form-item>
            
            <el-form-item>
              <el-button type="primary" @click="handleSimulate" :loading="loading">开始模拟</el-button>
            </el-form-item>
          </el-form>
          
          <div v-if="result" class="result-summary">
            <h3>模拟结果</h3>
            <p>每日褪色增量: <strong>{{ result.dailyFadeIncrement }}</strong></p>
            <p>当前分数: <strong>{{ result.currentFadeScore }}</strong></p>
            <p>预计完全褪色: 
              <el-tag :type="result.estimatedFadeDays > 30 ? 'danger' : 'success'">
                {{ result.estimatedFadeDays }} 天
              </el-tag>
            </p>
            <el-alert :title="result.configInfo" type="info" :closable="false" style="margin-top: 10px" />
          </div>
        </el-col>
        
        <!-- 右侧：图表展示 -->
        <el-col :span="16">
          <div id="chart" style="width: 100%; height: 400px;"></div>
        </el-col>
      </el-row>
    </el-card>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import request from '../utils/request'

const loading = ref(false)
const result = ref(null)
let chartInstance = null

const form = reactive({
  viewCount: 50,
  tagCount: 0,
  simulateDays: 90
})

const initChart = () => {
  const chartDom = document.getElementById('chart')
  chartInstance = echarts.init(chartDom)
}

const updateChart = (timeline, scores) => {
  const option = {
    title: {
      text: '褪色分数变化曲线'
    },
    tooltip: {
      trigger: 'axis'
    },
    xAxis: {
      type: 'category',
      name: '天数',
      data: timeline
    },
    yAxis: {
      type: 'value',
      name: '褪色分数',
      max: 100
    },
    series: [
      {
        data: scores,
        type: 'line',
        smooth: true,
        areaStyle: {},
        markLine: {
          data: [{ yAxis: 100, name: '完全褪色' }]
        }
      }
    ]
  }
  chartInstance.setOption(option)
}

const handleSimulate = async () => {
  loading.value = true
  try {
    const res = await request.post('/admin/fade/simulate', form)
    if (res.datas) {
      result.value = res.datas
      updateChart(res.datas.timeline, res.datas.fadeScores)
    }
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  initChart()
  // 自动执行一次模拟
  handleSimulate()
})
</script>

<style scoped>
.app-container {
  padding: 20px;
}
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.form-tip {
  font-size: 12px;
  color: #909399;
  line-height: 1.5;
}
.result-summary {
  margin-top: 20px;
  padding: 15px;
  background-color: #f5f7fa;
  border-radius: 4px;
}
.result-summary h3 {
  margin-top: 0;
}
</style>