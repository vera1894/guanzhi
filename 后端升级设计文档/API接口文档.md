# API 接口文档 (v1.0)

本文档总结了为“分享与用户系统升级”所新增和修改的核心API接口。

---

## 一、 用户侧接口 (`/guan/...`)

这些是面向所有普通用户的接口。

### 分享互动

-   **记录分享查看**
    -   `POST /guan/share/view`
    -   **功能**: 记录用户对某条分享的查看行为。后端会自动进行去重判断，并为首次查看的用户增加积分。
    -   **请求体**: `{"shareId": ...}`

-   **赞同/无感分享**
    -   `POST /guan/share/vote`
    -   **功能**: 对分享进行投票。首次投票会增加积分。切换投票或取消会正确更新统计和褪色度。
    -   **请求体**: `{"shareId": ..., "voteType": ...}` (`1`=赞同, `0`=无感, `-1`=取消)

-   **打卡分享**
    -   `POST /guan/share/checkin`
    -   **功能**: 在分享的地理位置附近进行打卡。有距离限制（后台可配置，默认200米）。首次打卡会增加积分并检查是否满足奖章条件。
    -   **请求体**: `{"shareId": ..., "latitude": ..., "longitude": ...}`

-   **发表评论**
    -   `POST /guan/share/comment/add`
    -   **功能**: 对分享发表评论。有距离限制。首次评论会增加积分。
    -   **请求体**: `{"shareId": ..., "content": "...", "latitude": ..., "longitude": ...}`

-   **获取评论列表**
    -   `GET /guan/share/comment/list`
    -   **功能**: 分页获取某条分享下的评论列表，按时间倒序排列。
    -   **请求参数**: `shareId`, `page`, `pageSize`

-   **贴标签**
    -   `POST /guan/share/tag`
    -   **功能**: 为分享贴上或移除一个标签。后端会校验用户的等级是否满足标签要求，并检查每日贴标签次数限额。
    -   **请求体**: `{"shareId": ..., "tagCode": "...", "action": ...}` (`1`=添加, `0`=取消)

-   **举报分享**
    -   `POST /guan/share/report`
    -   **功能**: 举报一条不恰当的分享。
    -   **请求体**: `{"shareId": ..., "reason": "..."}`

### 用户信息

-   **获取我的奖章列表**
    -   `GET /guan/user/my-medals`
    -   **功能**: 获取当前登录用户已获得的所有奖章。

-   **获取指定用户的奖章列表**
    -   `GET /guan/user/medals`
    -   **功能**: 查看任意用户的奖章墙。
    -   **请求参数**: `userId`

---

## 二、 管理后台接口 (`/api/admin/...`)

**注意**: 以下所有接口都需要管理员权限 (`ROLE_ADMIN`)。

### 内容与用户管理

-   **更新用户状态**
    -   `POST /api/admin/user/status`
    -   **功能**: 修改用户的状态（正常、警告、冻结）。
    -   **请求体**: `{"userId": ..., "status": ..., "warnDurationInDays": ...}` (`0`=正常, `1`=警告, `2`=冻结)

-   **标记分享**
    -   `POST /api/admin/share/mark`
    -   **功能**: 对分享进行官方标记（优质/差）或标记为违法。
    -   **请求体**: `{"shareId": ..., "officialMark": ..., "isIllegal": ...}`

-   **获取举报列表**
    -   `GET /api/admin/reports`
    -   **功能**: 查看待处理、已处理的举报列表。
    -   **请求参数**: `status` (`0`=待处理, `1`=有效, `2`=无效)

-   **处理举报**
    -   `POST /api/admin/report/process`
    -   **功能**: 将一条待处理的举报标记为有效或无效。
    *   **请求参数**: `reportId`, `status`

### 系统配置管理 (CRUD)

以下所有配置项均提供了完整的 `GET (List)`, `POST (Save/Update)`, `DELETE` 接口，并且在修改后会**自动刷新缓存**，即时生效。

-   **等级定义管理**
    -   `GET /api/admin/config/levels`
    -   `POST /api/admin/config/level`
    -   `DELETE /api/admin/config/level/{id}`

-   **积分规则管理**
    -   `GET /api/admin/config/points-rules`
    -   `POST /api/admin/config/points-rule`
    -   `DELETE /api/admin/config/points-rule/{id}`

-   **奖章定义管理**
    -   `GET /api/admin/config/medals`
    -   `POST /api/admin/config/medal`
    -   `DELETE /api/admin/config/medal/{id}`

-   **标签定义管理**
    -   `GET /api/admin/config/tags`
    *   `POST /api/admin/config/tag`
    *   `DELETE /api/admin/config/tag/{id}`

-   **褪色规则管理**
    -   `GET /api/admin/config/fade-configs`
    -   `POST /api/admin/config/fade-config`
    -   `DELETE /api/admin/config/fade-config/{id}`
