# 观之：Inspector & 管理后台接入执行手册 v1
#Seee

### 0. 前提状态（先自己确认）

在开始之前，先确认这几件事大致成立：
* 本地项目根目录（以你现在用的为准）：

⠀~/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi
* 后端项目路径：

⠀guanzhi/Server/onettoo
* Admin 前端项目路径：

⠀guanzhi/admin-panel（或 CC 当前实际使用的路径）
* 服务器：
  * SSH 已能登录到 /root/onettoo/back
  * 当前运行的是旧版本 onettoo-0.0.1-SNAPSHOT.jar（11 月 24 日那颗）

⠀
⸻

### Phase A：本地实现 Inspector 接口 + 前后端联调（代码 → 给 CC）

**目标：**
在本地 Server 代码中实现两个 *只读* Inspector 接口，让现有 admin-panel 的「分享查询 / 用户查询」页面能够在本地跑通。

### 给 CC 的指令（可直接粘贴后根据实际路径微调）

现在请你在本地的观之后端项目中，实现用于管理后台 Inspector 页面的两个只读接口，并完成本地联调：
	* 本地后端路径：

⠀~/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/Server/onettoo
	* Admin 前端路径：

⠀~/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/admin-panel

### 一、后端接口实现（只读）
1. 在后端新增一个专门用于管理后台的 Controller（名字按项目风格来，例如 AdminInspectorController），路径前缀建议为：
   * /api/admin/inspector
2. 实现两个 GET 接口：
   * GET /api/admin/inspector/share/{shareId}
   * GET /api/admin/inspector/user/{userId}
3. 接口行为：
   * 只读查询，不修改任何业务数据；
   * 使用当前数据库结构和 DO/DTO 模型（请根据代码中已有类）聚合数据：
     * 分享 Inspector 返回字段要与前端定义的 ShareInspectorDetail 对齐：
       * 基本信息：shareId、userId、创建时间、状态（0/1/2/3）、位置（lat/lng/address）
       * 互动统计：viewUserCount、recentViewUserCount、agreeCount、neutralCount、commentCount、checkinCount
       * 标签：tagCode、tagName、tagType（“POSITIVE”/“NEGATIVE”）、操作人
       * 褪色相关：fadeScore、isFaded、officialMark（0/1/2）、illegalFlag、reportCount
     * 用户 Inspector 返回字段与 UserInspectorDetail 对齐：
       * 基本信息：userId、昵称、注册时间、状态（0/1/2）
       * 积分 & 等级：pointsTotal、levelCode、levelName
       * 行为统计：shareCount、viewCount、agreeCount、neutralCount、checkinCount、commentCount、taggedShareCount
       * 奖章（如果当前项目已有相关表/字段，则返回；否则可以先返回空数组）
4. 业务错误处理：
   * 分享 / 用户不存在时，不用 HTTP 404，而是：
     * HTTP 200
     * body 中 code 为一个明确的业务码（例如 1001），message 为「分享不存在」或「用户不存在」，datas 为 null。
5. 鉴权：
   * 与现有 admin 接口保持一致，只允许拥有 admin 权限的账号调用。

⠀
### 二、本地联调
1. 启动本地后端（使用当前 dev/local 配置，保持和 admin-panel 一致）；
2. 启动 admin-panel；
3. 在浏览器中：
   * 打开分享 Inspector 页，使用本地数据库中存在的几条 shareId 做查询；
   * 打开用户 Inspector 页，使用本地存在的 userId 做查询；
4. 确认：
   * 页面能够正常展示返回的数据；
   * 对不存在的 ID，有清晰的“未找到”提示，而不是前端崩溃。

⠀
### 三、文档记录

请在 Server/重要项目信息/Inspector-联调记录-本地-YYYYMMDD.md 中记录：
1. 新增了哪些后端类和接口路径；
2. 聚合数据的主要取数来源（表名/服务方法）；
3. 实际用于测试的 shareId 和 userId 示例，以及测试结果。

⠀
⸻

### Phase A 完成后，给 Gemini 的校验任务

等 CC 完成后，你可以把 CC 的总结 + 一两个接口的 JSON 响应截图丢给 Gemini，让它帮你检查：
* 返回结构是否和 PRD/TS 类型一致；
* 状态/枚举映射是否合理；
* 有没有明显的 N+1 查询 / 性能坑（它可以看代码结构给出建议）。

⠀
你可以给 Gemini 类似这样的提示：

这是 CC 完成的 Inspector 接口实现说明 + 部分 JSON 返回样例，请你从「结构是否完整合理、是否覆盖了我们设计的字段、是否存在明显的设计风险」几个角度帮我做一次审查，并列出你认为需要改进的点。

⸻

### Phase B：服务器 application.yml 差异确认与定稿（操作 → CC，审查 → Gemini）

**目标：**
弄清楚：服务器 /root/onettoo/back/application.yml 与本地版本的差异，产出一个「我们真正想让 prod 使用」的定稿配置。

### 给 CC 的指令

接下来请你帮我整理服务器和本地的 application.yml 差异，并生成一份「prod 最终配置」说明：
1. 从服务器拉取当前正在使用的 application.yml 到本地：
   * 服务器路径：/root/onettoo/back/application.yml
   * 本地保存到：

⠀~/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/Server/infra/remote-application-prod-aws.yml
2. 对比本地后端项目中的 application.yml 和这份 remote-application-prod-aws.yml：
   * 使用 diff 或 IDE 的对比功能，把差异点整理成一份 Markdown 文档：
   * 文档路径：

⠀Server/重要项目信息/application-prod-差异与决策-YYYYMMDD.md
	* 文档中请按模块分组说明：
		* 数据源（DB_HOST/DB_NAME/用户名/端口等）
		* Redis
		* 端口配置
		* CORS / 安全相关
		* 其他比较重要的配置（如日志、JWT 等）
	* 对每一处差异给出「沿用服务器版本 / 使用本地版本 / 需要重新设定」的建议。
3. 在同目录生成一份「观之 prod 最终 application 配置草案」：
   * 文件名：application-prod-final-草案-YYYYMMDD.md
   * 用清单形式写明：对于 prod 环境，我们最终希望：
     * 使用哪个 DB 连接（host/db 用户等可以打码，只要结构明确）；
     * 使用哪个 Redis；
     * 服务运行端口；
     * 哪些配置必须与本地 dev 区分。

⠀
不要在这个阶段修改服务器上的 application.yml，只做「拉取、对比、写文档」。

### 给 Gemini 的指令（审查）

这是 CC 为我生成的：
	* 服务器 / 本地 application.yml 差异分析文档；
	* 以及「prod 最终 application 配置草案」。

⠀
请你帮我审查：
1. 对于 DB / Redis / 端口 / CORS / JWT 等关键配置，草案是否合理，会不会有明显风险？
2. 哪些地方你建议在上线前必须确认一下（例如：DB 权限、连接池大小、跨域来源列表等）？
3. 请给出你修改后的「prod 配置建议要点」，我会在下一步让 CC 按这个建议真正去更新 application.yml。

⠀
⸻

### Phase C：部署前准备（备份数据库 + 备份旧 jar）

（命令执行 → CC，风险评估 → Gemini）

**目标：**
在更新服务器后端之前，确保有可用的数据库备份和旧 jar，可随时回滚。

### 给 CC 的指令

请在 AWS 服务器上为这次部署做好备份准备，注意所有操作都要记录在文档中：
1. 数据库备份：
   * 以当前 prod 使用的 DB 连接为准（参考 application.yml / 你之前分析的配置），对 ONETTOO 整库做一次 mysqldump 备份：
     * 备份文件建议命名：/root/backup-ONETTOO-YYYYMMDD.sql
   * 备份完成后，记录：
     * 备份命令；
     * 文件大小；
     * 是否验证成功（例如用 head / tail 查看）。
2. 旧 jar 备份：
   * 在 /root/onettoo/back 目录下，将当前正在运行的 onettoo-0.0.1-SNAPSHOT.jar 复制一份为：
     * onettoo-0.0.1-SNAPSHOT-pre-inspector-YYYYMMDD.jar
   * 确认两个文件都存在，权限正常。
3. 文档记录：
   * 在服务器项目的文档目录中新增：
     * Server/重要项目信息/部署前备份记录-YYYYMMDD.md
   * 记录本次备份的：
     * 数据库备份文件路径；
     * jar 备份文件名；
     * 所用命令和执行时间。

⠀
在这个阶段，不要修改 application.yml，也不要重启服务，只做备份和记录。

### 给 Gemini 的指令（可选）

这是 CC 为我记录的「部署前备份记录-YYYYMMDD.md」，请帮我看一下：
1. 数据库备份命令和路径是否合理、足够恢复？
2. jar 备份是否足够让我们出现问题时快速回滚？
3. 是否有你建议补充的备份动作（例如单表备份、日志留存等）？

⠀
⸻

### Phase D：部署新的后端 jar 到服务器

（打包/上传/重启 → CC，部署结果检查 → Gemini）

**目标：**
用当前本地经过联调的后端代码打包新 jar，部署到 AWS，并安全重启服务。

### 给 CC 的指令

现在请你帮我完成观之后端的「Inspector 版本」部署，使用当前本地后端代码作为基线：
1. 在本地 Server/onettoo：
   * 确认 git status 干净（所有改动已提交到我在 gitee 的分支，例如 Zaptain）；
   * 执行打包命令（根据项目既有方式，通常是 mvn clean package -DskipTests）；
   * 找到打好的 jar（在 target/ 下），确认版本号和大小。
2. 上传新 jar 到服务器 /root/onettoo/back：
   * 使用 scp 将新 jar 上传到服务器；
   * 上传后在服务器上确认文件完整存在；
   * 建议命名为：onettoo-0.0.1-SNAPSHOT-inspector-YYYYMMDD.jar
   * 将 start.sh 中使用的 jar 指向这个新文件（或按项目当前约定方式更新）。
3. 确认 application.yml：
   * 使用我们在 Phase B 中确定的「prod 最终配置」更新 application.yml；
   * 注意：只在本次部署时修改，修改前后记录 diff。
4. 平滑重启服务：
   * 停掉当前 Java 进程（按安全方式来，如使用已有的 stop 脚本或 kill + 等待）；
   * 使用 start.sh 启动新 jar；
   * 确认：
     * 进程已启动；
     * 监听端口正常；
     * 基础健康检查接口（例如 /api/health）返回正常。
5. 在 Server/重要项目信息/部署记录-Inspector-YYYYMMDD.md 中记录：
   * 使用了哪个 jar；
   * 使用了哪份 application.yml；
   * 重启过程中的日志摘要；
   * 如有异常，如何处理的。

⠀
### 给 Gemini 的指令

这是 CC 给出的「部署记录-Inspector-YYYYMMDD.md」内容，以及新 jar 启动后的日志摘要。请你帮我检查：
1. 部署流程是否规范、可回滚？
2. 新服务启动日志中是否有明显错误或警告需要处理？
3. 是否有你建议加入到后续部署 checklist 中的步骤？

⠀
⸻

### Phase E：Admin 前端接入真实服务器数据 + 线上验证

（前端配置 & 基本测试 → CC，效果评估 → Gemini）

**目标：**
让本地 admin-panel 用真实服务器 API，验证配置页 + Inspector 页在「线上数据」下正常工作。

### 给 CC 的指令

现在请你帮我让 admin-panel 前端可以连接到 AWS 上的真实后端，并用它来做一轮基本验证：
1. 在 admin-panel 中增加或调整后端 baseUrl 配置：
   * dev 模式仍使用本地后端（例如：http://localhost:8085）；
   * 新增一个 prod 配置，指向 AWS 服务器，例如：
     * https://<服务器域名或IP>:<端口>
   * 按当前项目的方式（.env / config 文件）实现一个简单的「切换 dev/prod 后端」机制。
2. 使用 prod baseUrl 启动 admin-panel：
   * 获取 prod 环境可用的管理后台登录方式（token / 账号密码）；
   * 登录后依次访问：
     * 褪色规则配置页
     * 积分规则配置页
     * 等级定义管理页
     * 标签定义管理页
     * 新增的分享 Inspector 页（用一两个线上 shareId）
     * 新增的用户 Inspector 页（用一两个线上 userId）
3. 记录每个页面的状态：
   * 是否能正常加载数据；
   * 是否有后端返回错误；
   * 是否有字段对不上 UI 预期的情况。
4. 在 Server/重要项目信息/Admin-连通性验证-Prod-YYYYMMDD.md 中记录：
   * 使用的 prod baseUrl；
   * 每个页面的验证结果；
   * 发现的问题清单（如果有）。

⠀
### 给 Gemini 的指令

这是 admin-panel 连接 prod 后端后的连通性验证记录、部分页面截图和控制台/网络面板日志，请你帮我：
1. 检查各配置页和 Inspector 页展示的数据是否看起来合理（例如：枚举、计数、状态）；
2. 分析控制台/网络面板中是否有严重错误（例如接口结构不一致、关键字段缺失）；
3. 根据这些现象，给出一份「下一轮优化建议」，包括：
   * 必须修复的 bug 列表；
   * 可以稍后迭代的体验优化项。

⠀
⸻