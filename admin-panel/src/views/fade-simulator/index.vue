<script setup lang="ts">
import { ref } from 'vue'

const loading = ref(false)
</script>

<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <div class="card-header">
          <span class="card-title">褪色曲线模拟器</span>
        </div>
      </template>

      <div style="text-align: center; padding: 40px 0;">
        <el-icon style="font-size: 64px; color: #409eff;">
          <TrendCharts />
        </el-icon>
        <h3 style="margin-top: 20px;">褪色曲线模拟器</h3>
        <p style="color: #909399;">即将实现...</p>
      </div>
    </el-card>
  </div>
</template>

<style scoped>
</style>
