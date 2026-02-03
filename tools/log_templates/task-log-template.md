# {{TASK_TITLE}}

**日期**: {{DATE}}
**操作者**: {{ACTOR}}
**工作空间**: {{WORKSPACE}}
**任务类型**: {{TASK_TYPE}}
**任务 ID**: {{TASK_ID}}
**Run ID**: {{RUN_ID}}
**执行状态**: {{STATUS}}

---

## 任务概述

{{DESCRIPTION}}

---

## 执行结果

**状态**: {{STATUS}}
**结论**: {{CONCLUSION}}

{{#IF_HAS_EVIDENCE}}
---

## 证据 (Evidence)

{{EVIDENCE_LIST}}
{{/IF_HAS_EVIDENCE}}

{{#IF_HAS_RISK}}
---

## 风险 (Risk)

{{RISK_LIST}}
{{/IF_HAS_RISK}}

{{#IF_HAS_NEXT_STEPS}}
---

## 后续步骤 (Next Steps)

{{NEXT_STEPS_LIST}}
{{/IF_HAS_NEXT_STEPS}}

{{#IF_HAS_RESULT}}
---

## 任务结果详情

{{RESULT_DETAILS}}
{{/IF_HAS_RESULT}}

---

## 执行信息

- **开始时间**: {{START_TIMESTAMP}}
- **结束时间**: {{END_TIMESTAMP}}
- **任务输出文件**: {{OUTPUT_FILE}}
- **Schema 版本**: {{SCHEMA_VERSION}}

---

*此日志由 Agent 任务执行系统自动生成*
