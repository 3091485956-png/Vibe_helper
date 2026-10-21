---
description: 需求分层：MoSCoW + Gherkin 验收场景 + RICE 排序
argument-hint: [功能清单文本，或产品目录路径]
---

使用 **requirements-layering** skill 完成：$ARGUMENTS

执行要求：

- 给的是目录路径则读取其中的 02-brief.md / 03 / 04（存在哪个用哪个）；给的是文本则直接作为功能清单
- 每条 Must 写成用户故事 + ≥2 个 Given/When/Then 场景（至少一个非正常路径）
- Won't have 明确列出；Must 内部用 RICE 排序，信心分挂钩调研证据
- ⛔ Must 范围必须给用户过目确认后才落盘
