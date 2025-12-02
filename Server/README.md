# 观之项目 Server 端文档索引

**最后更新**: 2025-12-02

---

## 📂 目录结构

```
Server/
├── README.md                          # 本文件（文档索引）
├── CONTEXT_FOR_NEXT_SESSION.md       # ⭐ 对话压缩后必读
├── BACKEND_API_MODELS.md              # 后端API完整说明
├── 管理后台V1实施总结.md               # 当前项目实施总结
├── onettoo/                           # Spring Boot 后端代码
└── 文档归档/                           # 历史文档归档
    ├── 重要项目信息-归档-20251202/
    └── 后端升级设计文档-归档-20251202/
```

---

## 🚀 快速开始

### 对话压缩后首先阅读
**强制必读**: `CONTEXT_FOR_NEXT_SESSION.md`

这份文档包含：
- 项目当前状态
- 常见误解警告
- 后端API模型
- 下一步任务

### 新手入门
按顺序阅读：
1. `CONTEXT_FOR_NEXT_SESSION.md` - 了解项目全貌
2. `管理后台V1实施总结.md` - 了解当前进度和待办事项
3. `BACKEND_API_MODELS.md` - 了解后端接口细节

---

## 📚 文档分类

### 1. 当前项目文档（活跃）

| 文档 | 用途 | 更新频率 |
|------|------|---------|
| `CONTEXT_FOR_NEXT_SESSION.md` | 对话压缩后恢复上下文 | 每次压缩前更新 |
| `管理后台V1实施总结.md` | 当前进度和下一步计划 | 每日更新 |
| `BACKEND_API_MODELS.md` | 后端API参考手册 | 按需更新 |

### 2. 历史文档归档（只读）

**归档日期**: 2025-12-02

#### 重要项目信息（归档）
- `后台管理工具 V1 实施计划（精简版）.md` - 原始V1计划
- `V1项目进度总结.md` - 历史进度记录
- `后端完整验证报告.md` - 后端验证结果
- `关于分享的升级.md` - 核心业务需求文档
- ... 其他历史文档

#### 后端升级设计文档（归档）
- `docs/delivery-share-user-upgrade-v1.md` - 后端交付说明
- `sql/migration-*.sql` - 数据库迁移脚本
- ... 其他设计文档

---

## 🎯 项目状态速查

### 当前版本
- **管理后台**: V1（开发完成85%，测试中）
- **后端服务**: v1.0（已完成，运行稳定）

### 运行环境
- **后端**: http://localhost:8085 (Spring Boot)
- **前端**: http://localhost:5173 (Vue 3 + Vite)
- **数据库**: MySQL 9.5.0 (本地)
- **缓存**: Redis (本地)

### 测试凭证
```
ADMIN Token:
eyJhbGciOiJIUzUxMiJ9.eyJqdGkiOiI1ZTYwYzJlMjBlZTc0ZjMzOTk5MmRmZDFiNTVkNWUyNyIsImF1dGgiOiJST0xFX0FETUlOIiwidXNlciI6MiwibmFtZSI6IjEzODEwMjY5NjI3Iiwibmlja25hbWUiOiJUZXN0QWRtaW4iLCJwaG9uZSI6IjEzODEwMjY5NjI3Iiwic3ViIjoiMiJ9.cfIGo-00EKb1YqYjcYiauLZ1oPozNxzDM4KsFXXvRPJ1IModMl1kYqotBj7A0Dct7r6GmpMOEd8ngrRQSmyIrw
```

---

## ⚠️ 重要提醒

### 对于 AI 助手
1. **首次接手或对话压缩后**: 必读 `CONTEXT_FOR_NEXT_SESSION.md`
2. **不确定后端字段时**: 参考 `BACKEND_API_MODELS.md`
3. **规划下一步工作时**: 查看 `管理后台V1实施总结.md` 的待办清单

### 对于开发者
1. **启动后端**: `cd onettoo && mvn spring-boot:run`
2. **启动前端**: `cd ../admin-panel && npm run dev`
3. **查看API文档**: Swagger UI at http://localhost:8085/swagger-ui.html

---

## 🔧 常见问题

### Q: 前端保存配置时报400错误？
**A**: 检查 `BACKEND_API_MODELS.md` 确认请求体字段与后端模型一致。

### Q: 对话压缩后AI理解错了项目状态？
**A**: 让AI重新阅读 `CONTEXT_FOR_NEXT_SESSION.md`。

### Q: 找不到历史设计文档？
**A**: 查看 `文档归档/` 目录。

---

## 📅 更新日志

### 2025-12-02
- ✅ 创建文档归档体系
- ✅ 整理历史文档到归档目录
- ✅ 创建 `CONTEXT_FOR_NEXT_SESSION.md`
- ✅ 创建 `管理后台V1实施总结.md`
- ✅ 创建 `README.md`（本文件）

---

**维护人**: Claude Code (Anthropic)
**项目负责人**: Zaptain
