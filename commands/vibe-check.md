---
description: 对产品目录跑交付包机器自检，覆盖文档齐全、决策面板、验收场景、待核实清单、AI 轨道 08 与台账、原型死链。Machine validation of the delivery package.
argument-hint: [产品目录，默认当前目录]
allowed-tools: Bash
---

对产品目录运行 Vibe_helper 套件的交付包自检。

工作语言跟随用户输入语言。

目标目录：$ARGUMENTS，为空时用当前目录 ./

步骤：

1. 定位 validate.sh：在 **Vibe_helper** skill 目录的 `scripts/` 下，依次尝试套件仓库的 `skills/Vibe_helper/scripts/validate.sh`、`~/.agents/skills/Vibe_helper/scripts/validate.sh`、`~/.claude/skills/Vibe_helper/scripts/validate.sh`；都没有则提示用户安装套件
2. 运行 `bash <validate.sh 路径> <产品目录>`；用户提到"交付"或"完成"时加 `--expect 交付包`
3. 向用户报告 PASS、FAIL、WARN 明细；FAIL 项给出对应修复建议，如缺哪份文档、哪条验收标准不合格、AI 轨道缺 08 或台账、决策面板缺失、委托未留痕
4. 提醒：FAIL 项未修复前，对应的确认门不放行
