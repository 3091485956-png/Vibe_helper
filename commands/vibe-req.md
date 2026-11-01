---
description: 需求分层：MoSCoW + Gherkin 验收场景（AI 类挂评测引用）+ RICE 排序
argument-hint: [功能清单文本，或产品目录路径]
---

使用 **requirements-layering** skill 完成：$ARGUMENTS

执行要求：

- 给的是目录路径则读取其中的 02-brief.md / 03 / 04（存在哪个用哪个）；给的是文本则直接作为功能清单
- 每条 Must 写成用户故事 + ≥2 个 Given/When/Then 场景（至少一个非正常路径），带稳定 ID（M-F1…）与类型（常规 / AI）
- AI 类 Must 的输出质量不写 Gherkin，改写评测引用（"见 08-评测方案.md 环节 X，通过线 N%"）
- Won't have 明确列出；Must 内部用 RICE 排序，信心分挂钩调研证据（只有 C 级支撑的最高打 1）
- 先读 00-状态.md（缺失/过期先组装）；⛔ 确认后同一步刷新 00 的 Must/Won't 并 bump 版本
- ⛔ Must 范围必须给用户过目确认后才落盘（委托模式给决策回执）
