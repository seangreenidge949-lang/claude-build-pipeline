---
description: "Build Pipeline Stage 4: 产品方案。调用 product-doc skill 作为主体生成产品方案文档，自身只负责 build 流水线的上下文注入和 manifest 管理。"
---

# Stage 4: 产品方案 (Plan)

## Stage Contract
- **requires**: `.build/01-specify.md`
- **optional**: `.build/02-research.md`, `.build/03-value.md`
- **produces**: `.build/04-plan.md`
- **precondition**: specify 阶段已 completed；若 03-value.md 存在，方案必须对齐其优先级结论

## 执行模式说明

> 本阶段将 `product-doc` skill 作为主体引擎执行文档写作。
> 本文件只负责三件事：**上下文准备 → 调用 product-doc → 收尾交接**。
> 文档内容的完整写作逻辑、HTML 原型、审查机制均由 `product-doc` 承担。

## Complexity 覆盖规则

> 从 `_manifest.json` 的 `complexity` 字段读取。以下规则在调用 `product-doc` 时作为覆盖指令传入。
> **核心原则**：低复杂度砍的是**深度审查和穷举**，不砍**结构完整性**。

| 行为 | large | medium | small |
|------|-------|--------|-------|
| HTML 原型（Step 1c） | 生成 | 生成 | **跳过** |
| 逐功能详细展开（Step 2b） | 所有维度 | 所有维度 | **仅主流程+异常边界** |
| plan-reviewer（Step 3） | standard | standard | **跳过，主 agent 自审** |
| Step 4 反思沉淀 | 执行 | 执行 | **跳过** |
| 任务拆分（合并 code-plan 内容）| 否 | 否 | **是**（code-plan 将被跳过）|

**small 特殊规则**：产出的 `04-plan.md` 需同时包含方案 + 任务列表（格式与 code-plan 阶段一致：Phase/Task/Files/Do/Verify）。

## 前置检查

运行前置检查脚本：
```bash
~/.claude/scripts/check-build-prerequisites.sh plan --json
```

解析 JSON 输出。如果脚本返回非零退出码（specify 未完成），停止执行并告知用户。

从 `available_docs` 读取所有可用的前序文件：`01-specify.md`（必读）、`02-research.md`（如有）、`03-value.md`（如有）。

如果 `03-value.md` 存在，在注入上下文时告知 `product-doc`：被 value 标记为"无差异"或"反向型"的功能不应出现在方案中，如果方案中包含了被标记为低优先级的功能，需要向用户确认是否保留。

## 必读经验

进入本阶段前，读取：
- `~/.claude/memory/details/plan/product-doc-lessons.md` — 产品文档评审高频问题（如文件存在）

## 执行流程

### Step 1: 准备上下文

从前序阶段产出文件中提取并整理信息，作为 `product-doc` Step 1a 的"已有文档"输入：

从 `01-specify.md` 提取：
- 产品名称 + 一句话定位 + 目标平台
- 功能清单 + 非目标边界
- 技术约束（API、SDK 版本限制等）
- 文档类型（PRD / 功能设计文档 / 产品提案 / 完整产品）
- 成功标准 + 开放问题列表

从 `02-research.md`（如有）提取：
- 竞品对比结论
- 用户痛点 + 未被满足的需求
- 对 plan 阶段的建议（如有）

从 `03-value.md`（如有）提取：
- 确认的产品方向
- 差异化定位
- 功能优先级建议
- 被标记为低优先级 / 不做 的功能列表

### Step 2: 调用 product-doc（主体）

📋 使用 skill: product-doc

以如下规则覆盖 `product-doc` 的默认行为：

**输入注入（覆盖 Step 1a）**
- 直接使用 Step 1 整理的上下文作为"已有需求简报"
- `product-doc` Step 1a 走"已有"分支，**不重新向用户收集需求**
- 整理后的上下文应等价于 `product-doc` Step 1a 所需的四件事（产品名称+定位+平台 / 功能清单 / 不做什么 / 技术约束）
- 向用户说明："已从前序阶段文档自动导入需求，如有需要调整请直接指出"

**输出路径（覆盖 Step 1b）**
- `product-doc` 的所有文档写入动作改为写入 `.build/04-plan.md`
- HTML 原型生成路径改为 `.build/04-plan-prototype.html`
- `product-doc` 的 `references/04-reflection.md` 相对路径不变（仍指向 skill 目录下的文件）

**Complexity 覆盖**
- 按「Complexity 覆盖规则」表执行，覆盖 `product-doc` 的默认详细程度
- small 模式下在文档末尾追加任务拆分（Phase/Task/Files/Do/Verify 格式）

**plan-reviewer 参数注入（覆盖 product-doc Step 3）**
- `spec_path`: `.build/01-specify.md`
- `other_docs`: 所有可用的前序文件路径列表
- `mode`: 从 `_manifest.json` 读取（standard / quick）
- `known_pitfalls`: 读取 `~/.claude/memory/details/plan/product-doc-lessons.md`（如文件存在）

### Step 3: 收尾交接

`product-doc` 完成后执行：

1. 确认 `.build/04-plan.md` 已写入
2. 更新 `_manifest.json`：
   ```json
   "plan": { "status": "completed", "output": "04-plan.md", "completed_at": "<时间戳>" }
   ```
3. 向用户展示方案摘要 + 审查结果（裁决 + 通过轮次）
4. 根据文档末尾"需要设计稿"字段决定下一步：
   - 需要设计稿 = 是 → 进入**设计稿阶段**
   - 需要设计稿 = 否 → 跳过设计，进入**代码计划**
   - 如果 `stop_after == "plan"` → 生成交付摘要
5. 交回编排器控制权
