---
name: requirements-layering
description: 用 MoSCoW 把功能清单切成 MVP、二期与远期，每条 Must 写成用户故事并配 Gherkin 即 Given/When/Then 的验收场景，Must 内部用 RICE 排出开发先后，Won't have 明确防范围蔓延。当用户说"帮我做需求分层"、"把这些功能排个优先级"、"哪些进 MVP"、"帮我写用户故事和验收标准"、"做个 PRD 需求清单"时使用。正处于 Vibe_helper 全流程时按该流程走，无需单独触发。English: slice a feature list into MoSCoW layers, write each Must as a user story with at least two Gherkin acceptance scenarios, rank Musts with RICE, and pin down the Won't-have boundary. Use when the user asks for "requirement layering", "prioritize these features", "what goes into the MVP", or "user stories and acceptance criteria"; inside the Vibe_helper pipeline it runs as part of that flow.
---

# Requirements Layering：需求分层，MoSCoW 加 Gherkin 加 RICE

语言规则：全程跟随用户语言。用户故事与 05-需求分层.md 正文用用户的语言；编号文件名与小节标题保持模板原样，Given/When/Then 关键字不译。

回答两个问题：**第一版做什么、不做什么？先做哪个？** 这是防止 MVP 越做越大的第一道防线。

在 Vibe_helper 全流程中对应 Stage 5；单独使用时本 skill 独立完成。

## 输入

- 功能清单：来自 `02-brief.md`，或用户口述、贴出来的一份功能列表
- 可选增强：`03-竞品分析.md` 提供竞品功能对比；`04-用户声音.md` 提供哪些痛点证据强，喂 RICE 的信心分
- **先读 `00-状态.md`**，规则见 `references/context-assembly.md`：存在且组装清单未过期则以它为主上下文；缺失而已有 ≥2 份文档、或已过期，先组装或重组装再干活
- 只有想法没有清单时，先让用户把脑子里的功能全部倒出来，不排序不评判，再开始分层

## 深度档位，开场确认，默认标准

| 档位 | Must 数 | 验收场景 | RICE |
|---|---|---|---|
| 快速 | ≤4 | 每故事 2 个场景 | 不打分 |
| 标准，默认 | 3–6 | 每故事 2–3 个场景 | Must 内部打分 |
| 深度 | 3–6 | 每故事 3–5 个场景 | Must 加 Should 打分，输出排序理由 |

## 步骤

1. **MoSCoW 分层**：Must 即没有它产品不成立，Should 即缺了也能跑，Could 即锦上添花，**Won't 即明确不做并写原因**。每个功能标来源：问卷、竞品或用户声音；Must 另标**类型：常规 / AI**，AI 轨道判定见 00-状态
2. **用户故事**：每条 Must 写成"作为 \<角色\>，我希望 \<动作\>，以便 \<价值\>"，标依赖
3. **Gherkin 验收场景**：每条 Must ≥2 个场景，格式与好、坏对照见 `references/requirements-layering.md`：
   ```
   - 场景：空输入提交
     - Given 输入框为空
     - When 点击"提交"
     - Then 按钮禁用并提示"请填写内容"
   ```
   规则：可观察的具体行为，不是形容词；至少一个非正常路径，含错误、空、边界、断网；Then 写用户可见结果。**AI 类 Must 的验收改造，M8**：工程路径，含提交、报错、空态、降级，照写 Gherkin；**输出质量不写 Gherkin，改写评测引用**，即"质量验收：见 08-评测方案.md 环节 X，通过线 N%"。硬拿 Then 写"摘要质量高"等于形同虚设
4. **RICE 排序**：(R 触达 × I 影响 × C 信心) / E 工作量，分数高先做。**信心分必须挂钩证据**：只有 C 级即模型推测支撑的功能，信心分最高打 1
5. **范围确认门**：展示 Must 清单，第一屏放决策面板，明确问"MVP 我建议就做这几件事，范围会不会太大或太小？有没有 Must 可以砍？"用户调整后确认，落盘 `05-需求分层.md`，版本头记"基于 00-状态@vN"，每条 Must 带稳定 ID，M-F1、M-F2 起，与类型；并在**同一步**刷新 00-状态.md，写入 Must 清单与 Won't，更新卡版本

## Common Pitfalls

- **Must 塞 10 个**：MVP 做太大是最常见死法。每加一个 Must，问"没有它产品真的不成立吗？"
- **验收场景全是 happy path**：空输入、断网、超长内容才是翻车现场
- **验收标准写形容词**："响应快、体验好"没法判断做完没
- **功能没有稳定 ID**：M-F 编号首次分配后不再改号，06/07 引用功能一律带 ID
- **确认后不刷新状态卡**：05 落盘或修改后必须同一步更新 00，否则组装清单过期，validate.sh 会拦
- **Won't 空着**：边界和 Must 一样重要，不写清楚范围必然蔓延
- **故事写成功能名**："导出功能"不是用户故事；"作为读者，我希望导出 PDF 以便打印"才是
- **RICE 信心分拍脑袋**：C 分只能来自调研证据，没证据就是 1
- **AI 功能硬写 Gherkin 质量验收**：非确定输出判不了 Then，质量一律挂 08-评测引用
- **替用户砍需求**：分层结果过确认门给用户过目，砍什么是用户的决定
- **语言不跟用户**：用户用英文仍写中文用户故事

## 输出物

- `05-需求分层.md`，带版本头与"基于 00-状态@vN"，含 RICE 排序表加 Won't have 清单，用户确认后
