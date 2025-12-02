# Phase 4: AWS 线上配置数据导出/导入方案

**文档版本**: v1.0
**创建时间**: 2025-12-02
**适用环境**:
- 线上环境：AWS RDS MySQL
- 本地环境：本机 MySQL (端口 3306, 数据库 ONETTOO)

---

## 📋 目标

将 AWS 线上数据库中的以下 4 张配置表导出到本地，用于本地开发和测试：

1. **tag_definition** - 标签定义表
2. **level_definition** - 等级定义表
3. **points_rule** - 积分规则表
4. **fade_config** - 褪色配置表

---

## ⚠️ 重要注意事项

### Schema 差异问题
**本地数据库已有字段，线上可能没有：**
- `tag_definition.tag_type` (VARCHAR(20)) - 本地已添加，线上可能没有

**解决方案：**
1. 先在 AWS 上执行数据库迁移，添加缺失字段
2. 或导入时跳过该字段，手动补全

---

## 方案 A：纯 SQL 导出/导入（推荐）

### 优点
- ✅ 操作简单，无需编码
- ✅ 数据完整性高
- ✅ 可以选择性导出指定表

### 缺点
- ⚠️ 需要 SSH 访问 AWS 服务器或使用 RDS 客户端工具
- ⚠️ 需要处理主键冲突

---

### A.1 从 AWS 导出数据

#### 前置条件
- AWS RDS 连接信息（假设你已有）
- MySQL 客户端工具

#### 导出命令

```bash
# 设置 AWS 数据库连接信息
AWS_HOST="your-rds-endpoint.rds.amazonaws.com"
AWS_PORT="3306"
AWS_USER="admin"
AWS_PASSWORD="your-password"
AWS_DATABASE="ONETTOO"

# 导出目录
EXPORT_DIR="$HOME/Desktop/aws_config_export"
mkdir -p "$EXPORT_DIR"

# 1. 导出标签定义表
mysqldump -h "$AWS_HOST" -P "$AWS_PORT" -u "$AWS_USER" -p"$AWS_PASSWORD" \
  "$AWS_DATABASE" tag_definition \
  --no-create-info \
  --skip-add-locks \
  --skip-comments \
  --compact \
  > "$EXPORT_DIR/tag_definition.sql"

# 2. 导出等级定义表
mysqldump -h "$AWS_HOST" -P "$AWS_PORT" -u "$AWS_USER" -p"$AWS_PASSWORD" \
  "$AWS_DATABASE" level_definition \
  --no-create-info \
  --skip-add-locks \
  --skip-comments \
  --compact \
  > "$EXPORT_DIR/level_definition.sql"

# 3. 导出积分规则表
mysqldump -h "$AWS_HOST" -P "$AWS_PORT" -u "$AWS_USER" -p"$AWS_PASSWORD" \
  "$AWS_DATABASE" points_rule \
  --no-create-info \
  --skip-add-locks \
  --skip-comments \
  --compact \
  > "$EXPORT_DIR/points_rule.sql"

# 4. 导出褪色配置表
mysqldump -h "$AWS_HOST" -P "$AWS_PORT" -u "$AWS_USER" -p"$AWS_PASSWORD" \
  "$AWS_DATABASE" fade_config \
  --no-create-info \
  --skip-add-locks \
  --skip-comments \
  --compact \
  > "$EXPORT_DIR/fade_config.sql"

echo "✅ 导出完成，文件保存在: $EXPORT_DIR"
```

**参数说明：**
- `--no-create-info`: 不导出建表语句（本地已有表结构）
- `--skip-add-locks`: 跳过锁表语句
- `--compact`: 紧凑输出，减少冗余
- `--skip-comments`: 跳过注释

---

### A.2 处理 Schema 差异（重要！）

#### 问题：本地有 tag_type 字段，AWS 可能没有

**解决方案 1：先在 AWS 上添加字段（推荐）**

```bash
# 连接 AWS 数据库
mysql -h "$AWS_HOST" -P "$AWS_PORT" -u "$AWS_USER" -p"$AWS_PASSWORD" "$AWS_DATABASE"

# 执行迁移
ALTER TABLE tag_definition
ADD COLUMN tag_type VARCHAR(20) NOT NULL DEFAULT 'NEGATIVE'
COMMENT '标签类型: POSITIVE=正面标签, NEGATIVE=负面标签'
AFTER tag_name;

# 更新现有数据
UPDATE tag_definition SET tag_type = 'NEGATIVE' WHERE tag_type IS NULL OR tag_type = '';

# 退出
exit;
```

**解决方案 2：修改导出文件，移除 tag_type 列**

如果不能修改 AWS 数据库，需要手动编辑导出的 SQL 文件：

```bash
# 备份原始文件
cp "$EXPORT_DIR/tag_definition.sql" "$EXPORT_DIR/tag_definition.sql.bak"

# 使用 sed 移除 tag_type 相关内容
# 注意：这个脚本假设 INSERT 语句格式为标准的 mysqldump 输出
# 实际使用时需要根据导出文件的具体格式调整
```

---

### A.3 导入到本地数据库

#### 准备工作：清空本地表（可选）

```bash
# 连接本地数据库
/opt/homebrew/Cellar/mysql/9.5.0_2/bin/mysql -u root ONETTOO

# 在 MySQL 中执行：
TRUNCATE TABLE tag_definition;
TRUNCATE TABLE level_definition;
TRUNCATE TABLE points_rule;
TRUNCATE TABLE fade_config;

exit;
```

**⚠️ 警告：** TRUNCATE 会删除所有数据，请确保已备份本地重要数据！

#### 导入命令

```bash
# 导入标签定义
/opt/homebrew/Cellar/mysql/9.5.0_2/bin/mysql -u root ONETTOO < "$EXPORT_DIR/tag_definition.sql"

# 导入等级定义
/opt/homebrew/Cellar/mysql/9.5.0_2/bin/mysql -u root ONETTOO < "$EXPORT_DIR/level_definition.sql"

# 导入积分规则
/opt/homebrew/Cellar/mysql/9.5.0_2/bin/mysql -u root ONETTOO < "$EXPORT_DIR/points_rule.sql"

# 导入褪色配置
/opt/homebrew/Cellar/mysql/9.5.0_2/bin/mysql -u root ONETTOO < "$EXPORT_DIR/fade_config.sql"

echo "✅ 导入完成"
```

#### 验证导入结果

```bash
/opt/homebrew/Cellar/mysql/9.5.0_2/bin/mysql -u root ONETTOO -e "
SELECT '=== 标签定义表 ===' AS '';
SELECT COUNT(*) AS total_tags FROM tag_definition;
SELECT * FROM tag_definition LIMIT 3;

SELECT '=== 等级定义表 ===' AS '';
SELECT COUNT(*) AS total_levels FROM level_definition;
SELECT * FROM level_definition LIMIT 3;

SELECT '=== 积分规则表 ===' AS '';
SELECT COUNT(*) AS total_rules FROM points_rule;
SELECT * FROM points_rule;

SELECT '=== 褪色配置表 ===' AS '';
SELECT COUNT(*) AS total_configs FROM fade_config;
SELECT * FROM fade_config LIMIT 5;
"
```

---

### A.4 处理主键冲突

如果导入时出现主键冲突错误：

```
ERROR 1062 (23000): Duplicate entry '1' for key 'PRIMARY'
```

**解决方案：在导入前清空表或使用 REPLACE INTO**

修改导出的 SQL 文件，将 `INSERT INTO` 替换为 `REPLACE INTO`：

```bash
sed -i.bak 's/INSERT INTO/REPLACE INTO/g' "$EXPORT_DIR/tag_definition.sql"
sed -i.bak 's/INSERT INTO/REPLACE INTO/g' "$EXPORT_DIR/level_definition.sql"
sed -i.bak 's/INSERT INTO/REPLACE INTO/g' "$EXPORT_DIR/points_rule.sql"
sed -i.bak 's/INSERT INTO/REPLACE INTO/g' "$EXPORT_DIR/fade_config.sql"
```

---

## 方案 B：后端 API 导出 + 本地导入工具

### 优点
- ✅ 自动处理字段映射和格式转换
- ✅ 可以在导出时做数据清洗
- ✅ 格式统一（JSON）

### 缺点
- ⚠️ 需要修改后端代码，添加导出接口
- ⚠️ 需要编写导入脚本

---

### B.1 后端导出接口设计

在 AWS 后端添加以下 Controller 方法：

#### 新增导出 Controller

```java
package com.cloud.onettoo.modules.controller.admin;

import com.cloud.onettoo.modules.model.*;
import com.cloud.onettoo.modules.service.*;
import com.cloud.onettoo.util.Result;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/admin/export")
public class ConfigExportController {

    @Autowired
    private TagDefinitionService tagDefinitionService;

    @Autowired
    private LevelDefinitionService levelDefinitionService;

    @Autowired
    private PointsRuleService pointsRuleService;

    @Autowired
    private FadeConfigService fadeConfigService;

    /**
     * 导出所有配置数据为 JSON
     * GET /api/admin/export/config-all
     */
    @GetMapping("/config-all")
    public Result<Map<String, Object>> exportAllConfigs() {
        Map<String, Object> exportData = new HashMap<>();

        // 1. 导出标签定义
        List<TagDefinitionDO> tags = tagDefinitionService.list();
        exportData.put("tag_definition", tags);

        // 2. 导出等级定义
        List<LevelDefinitionDO> levels = levelDefinitionService.list();
        exportData.put("level_definition", levels);

        // 3. 导出积分规则
        List<PointsRuleDO> rules = pointsRuleService.list();
        exportData.put("points_rule", rules);

        // 4. 导出褪色配置
        List<FadeConfigDO> fadeConfigs = fadeConfigService.list();
        exportData.put("fade_config", fadeConfigs);

        // 添加导出时间戳
        exportData.put("export_timestamp", System.currentTimeMillis());
        exportData.put("export_date", new java.util.Date().toString());

        return Result.success(exportData);
    }
}
```

#### 使用方法

```bash
# 假设 AWS 后端地址为
AWS_API="https://your-aws-backend.com"
TOKEN="your-admin-token"

# 导出所有配置到 JSON 文件
curl -X GET "$AWS_API/api/admin/export/config-all" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -o "$HOME/Desktop/aws_config_export.json"

echo "✅ 导出完成: $HOME/Desktop/aws_config_export.json"
```

---

### B.2 本地导入脚本

#### 方案 B2.1：使用 Java 工具类导入

创建一个独立的 Java 工具类来读取 JSON 并导入本地数据库：

```java
package com.cloud.onettoo.util;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.cloud.onettoo.modules.model.*;
import com.cloud.onettoo.modules.service.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.io.File;
import java.util.*;

@Component
public class ConfigImportTool {

    @Autowired
    private TagDefinitionService tagDefinitionService;

    @Autowired
    private LevelDefinitionService levelDefinitionService;

    @Autowired
    private PointsRuleService pointsRuleService;

    @Autowired
    private FadeConfigService fadeConfigService;

    public void importFromJson(String jsonFilePath) throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        Map<String, Object> data = mapper.readValue(new File(jsonFilePath), Map.class);

        // 1. 导入标签定义
        List<Map<String, Object>> tags = (List<Map<String, Object>>) data.get("tag_definition");
        for (Map<String, Object> tag : tags) {
            TagDefinitionDO tagDO = mapper.convertValue(tag, TagDefinitionDO.class);
            tagDefinitionService.saveOrUpdate(tagDO);
        }

        // 2. 导入等级定义
        List<Map<String, Object>> levels = (List<Map<String, Object>>) data.get("level_definition");
        for (Map<String, Object> level : levels) {
            LevelDefinitionDO levelDO = mapper.convertValue(level, LevelDefinitionDO.class);
            levelDefinitionService.saveOrUpdate(levelDO);
        }

        // 3. 导入积分规则
        List<Map<String, Object>> rules = (List<Map<String, Object>>) data.get("points_rule");
        for (Map<String, Object> rule : rules) {
            PointsRuleDO ruleDO = mapper.convertValue(rule, PointsRuleDO.class);
            pointsRuleService.saveOrUpdate(ruleDO);
        }

        // 4. 导入褪色配置
        List<Map<String, Object>> fadeConfigs = (List<Map<String, Object>>) data.get("fade_config");
        for (Map<String, Object> config : fadeConfigs) {
            FadeConfigDO configDO = mapper.convertValue(config, FadeConfigDO.class);
            fadeConfigService.saveOrUpdate(configDO);
        }

        System.out.println("✅ 导入完成");
    }
}
```

**使用方法：**
在本地后端的某个测试接口或启动脚本中调用：

```java
@Autowired
private ConfigImportTool importTool;

@GetMapping("/test-import")
public String testImport() {
    try {
        importTool.importFromJson("/Users/zaptain/Desktop/aws_config_export.json");
        return "导入成功";
    } catch (Exception e) {
        e.printStackTrace();
        return "导入失败: " + e.getMessage();
    }
}
```

---

#### 方案 B2.2：使用 Python 脚本导入（更灵活）

```python
#!/usr/bin/env python3
"""
AWS 配置数据导入工具
"""

import json
import pymysql
from datetime import datetime

# 本地数据库配置
DB_CONFIG = {
    'host': 'localhost',
    'port': 3306,
    'user': 'root',
    'password': '',  # macOS brew 安装的 MySQL 默认无密码
    'database': 'ONETTOO',
    'charset': 'utf8mb4'
}

def import_config_from_json(json_file_path):
    """从 JSON 文件导入配置数据"""

    # 读取 JSON 文件
    with open(json_file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 连接数据库
    conn = pymysql.connect(**DB_CONFIG)
    cursor = conn.cursor()

    try:
        # 1. 导入标签定义
        print("=== 导入标签定义 ===")
        tags = data.get('tag_definition', [])
        for tag in tags:
            sql = """
            REPLACE INTO tag_definition
            (id, tag_code, tag_name, tag_type, min_level_code, is_active, sort_order)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql, (
                tag.get('id'),
                tag.get('tagCode'),
                tag.get('tagName'),
                tag.get('tagType', 'NEGATIVE'),  # 默认值
                tag.get('minLevelCode'),
                tag.get('isActive', True),
                tag.get('sortOrder', 0)
            ))
        print(f"✅ 导入 {len(tags)} 条标签定义")

        # 2. 导入等级定义
        print("=== 导入等级定义 ===")
        levels = data.get('level_definition', [])
        for level in levels:
            sql = """
            REPLACE INTO level_definition
            (id, level_code, level_name, min_points, min_checkins, min_comments, tagging_allowance, extra_conditions)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql, (
                level.get('id'),
                level.get('levelCode'),
                level.get('levelName'),
                level.get('minPoints', 0),
                level.get('minCheckins', 0),
                level.get('minComments', 0),
                level.get('taggingAllowance', 0),
                level.get('extraConditions')
            ))
        print(f"✅ 导入 {len(levels)} 条等级定义")

        # 3. 导入积分规则
        print("=== 导入积分规则 ===")
        rules = data.get('points_rule', [])
        for rule in rules:
            sql = """
            REPLACE INTO points_rule
            (id, action_type, points_value, daily_limit)
            VALUES (%s, %s, %s, %s)
            """
            cursor.execute(sql, (
                rule.get('id'),
                rule.get('actionType'),
                rule.get('pointsValue', 0),
                rule.get('dailyLimit')
            ))
        print(f"✅ 导入 {len(rules)} 条积分规则")

        # 4. 导入褪色配置
        print("=== 导入褪色配置 ===")
        fade_configs = data.get('fade_config', [])
        for config in fade_configs:
            sql = """
            REPLACE INTO fade_config
            (id, config_key, config_value, description)
            VALUES (%s, %s, %s, %s)
            """
            cursor.execute(sql, (
                config.get('id'),
                config.get('configKey'),
                config.get('configValue'),
                config.get('description')
            ))
        print(f"✅ 导入 {len(fade_configs)} 条褪色配置")

        # 提交事务
        conn.commit()
        print("\n✅ 所有数据导入完成")

        # 导出时间信息
        export_timestamp = data.get('export_timestamp')
        if export_timestamp:
            export_date = datetime.fromtimestamp(export_timestamp / 1000)
            print(f"📅 数据导出时间: {export_date}")

    except Exception as e:
        conn.rollback()
        print(f"❌ 导入失败: {e}")
        raise
    finally:
        cursor.close()
        conn.close()

if __name__ == '__main__':
    import sys

    if len(sys.argv) < 2:
        print("用法: python3 import_aws_config.py <json文件路径>")
        print("示例: python3 import_aws_config.py ~/Desktop/aws_config_export.json")
        sys.exit(1)

    json_file = sys.argv[1]
    import_config_from_json(json_file)
```

**使用方法：**

```bash
# 安装依赖
pip3 install pymysql

# 执行导入
cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/Server
python3 import_aws_config.py ~/Desktop/aws_config_export.json
```

---

## 📊 方案对比

| 特性 | 方案 A: SQL 导出/导入 | 方案 B: API + 脚本 |
|------|---------------------|-------------------|
| **难度** | ⭐⭐ 简单 | ⭐⭐⭐⭐ 复杂 |
| **准备时间** | 5 分钟 | 30-60 分钟 |
| **数据完整性** | ✅ 高 | ✅ 高 |
| **自动化程度** | ⚠️ 中等 | ✅ 高 |
| **Schema 差异处理** | ⚠️ 手动处理 | ✅ 自动处理 |
| **适用场景** | 一次性导入 | 需要定期同步 |
| **推荐指数** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

---

## 🎯 推荐执行流程

### 对于首次导入（推荐方案 A）

```bash
# 第 1 步：连接 AWS 数据库并导出
# （参考 A.1 节的导出命令）

# 第 2 步：检查 schema 差异
# （参考 A.2 节，决定是在 AWS 添加字段还是修改导出文件）

# 第 3 步：备份本地数据（重要！）
/opt/homebrew/Cellar/mysql/9.5.0_2/bin/mysqldump -u root ONETTOO > ~/Desktop/local_backup_$(date +%Y%m%d_%H%M%S).sql

# 第 4 步：清空本地表
# （参考 A.3 节的 TRUNCATE 命令）

# 第 5 步：导入数据
# （参考 A.3 节的导入命令）

# 第 6 步：验证导入结果
# （参考 A.3 节的验证查询）

# 第 7 步：重启本地后端服务
cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/Server/onettoo
JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" mvn spring-boot:run

# 第 8 步：在管理后台验证数据
# 访问 http://localhost:5173
# 查看 4 个配置页面是否显示正确
```

---

## ⚠️ 注意事项和常见问题

### 1. 数据库连接超时
如果 AWS RDS 连接超时，检查：
- 安全组规则是否允许你的 IP 访问
- RDS 实例是否为 Public 可访问
- 是否需要通过堡垒机/VPN 连接

### 2. 字符编码问题
如果导入后中文乱码：
```bash
# 导出时指定字符集
mysqldump --default-character-set=utf8mb4 ...

# 导入时指定字符集
mysql --default-character-set=utf8mb4 ...
```

### 3. 主键冲突
如果本地已有 id=1 的记录，导入会失败。解决方法：
- 方法1：导入前 TRUNCATE 表（推荐）
- 方法2：使用 REPLACE INTO 替代 INSERT INTO
- 方法3：手动调整导出数据的 id 值

### 4. 外键约束冲突
如果表之间有外键关系，导入顺序很重要：
```bash
# 暂时禁用外键检查
SET FOREIGN_KEY_CHECKS = 0;
# 导入数据
# 重新启用外键检查
SET FOREIGN_KEY_CHECKS = 1;
```

### 5. tag_type 字段缺失问题
**最保险的做法：先在 AWS 执行迁移 SQL，再导出数据**

这样可以确保：
- ✅ 线上和本地 schema 完全一致
- ✅ 导出的数据包含所有字段
- ✅ 导入不会有任何报错

---

## 📝 执行检查清单

在开始导入前，请确认：

- [ ] 已备份本地数据库
- [ ] 已确认 AWS 数据库连接信息
- [ ] 已检查 schema 差异（特别是 tag_type 字段）
- [ ] 已决定使用方案 A 还是方案 B
- [ ] 已准备好导出目录
- [ ] 本地 MySQL 服务正在运行
- [ ] 本地后端服务已停止（避免数据冲突）

导入后，请验证：

- [ ] 标签配置页面显示正确
- [ ] 等级配置页面显示正确
- [ ] 积分配置页面显示正确
- [ ] 褪色配置页面显示正确
- [ ] 所有配置数据可以正常编辑和保存
- [ ] 褪色模拟器能正常使用新配置

---

## 📚 相关文档

- [四个配置页面自测操作手册.md](./四个配置页面自测操作手册.md)
- [Phase2-Phase3-进度报告.md](./Phase2-Phase3-进度报告.md)
- [管理后台V1实施总结.md](./管理后台V1实施总结.md)

---

**文档版本**: v1.0
**最后更新**: 2025-12-02
**作者**: Claude Code

如有问题，请在执行前仔细阅读相关章节，或先在测试数据库上验证流程。
