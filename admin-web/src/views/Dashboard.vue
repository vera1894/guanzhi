<template>
  <div>
    <h1>欢迎使用观之管理后台</h1>
    <el-row :gutter="20">
      <el-col :span="6">
        <el-card shadow="hover">
          <template #header>系统状态</template>
          <div class="status-normal">运行正常</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <template #header>待处理举报</template>
          <div class="status-warning">0 条</div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<style scoped>
.status-normal {
  color: #67C23A;
  font-weight: bold;
  font-size: 24px;
}
.status-warning {
  color: #E6A23C;
  font-weight: bold;
  font-size: 24px;
}
</style>