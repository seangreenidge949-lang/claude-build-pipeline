---
description: "Build Pipeline Stage 7: 代码实施。按代码计划中的任务列表逐项执行实现。"
---

# Stage 7: 代码实施 (Implement)

## Stage Contract
- **requires**: `.build/06-code-plan.md`
- **optional**: `.build/04-plan.md`, `.build/05-design.md`
- **produces**: `.build/07-implement-log.md`
- **precondition**: specify 和 code-plan 阶段已 completed

## 前置检查

运行前置检查脚本：
```bash
~/.claude/scripts/check-build-prerequisites.sh implement --json
```

解析 JSON 输出。如果脚本返回非零退出码（specify 或 code-plan 未完成），停止执行并告知用户。
从 `available_docs` 读取：`06-code-plan.md`（必读，任务列表+设计规格表）、`04-plan.md`（如有，产品方案对照）、`05-design.md`（如有，设计稿参考）。

## 执行流程

### Step 0: 选择执行模式

使用 AskUserQuestion 让用户选择执行模式：

- **手动模式（默认）**：由当前 agent 逐 Task 执行，适合 Task 数量少（≤5）或任务间耦合紧密的情况
- **Subagent 模式**：每个 Task 派遣独立 subagent 执行，附带两阶段 review（spec compliance → code quality）。适合 Task 数量多（≥5）且大部分任务独立的情况。使用 `superpowers:subagent-driven-development` skill 的流程

> 建议：Task ≤ 5 且大部分有依赖关系 → 手动模式；Task ≥ 5 且标记了 [P] 的较多 → Subagent 模式

**如果用户选择 Subagent 模式**：
1. 加载 `superpowers:subagent-driven-development` skill
2. Step 0.5 的踩坑经验 → 压缩为 `## 已知陷阱` 注入每个 subagent prompt
3. 涉及 UI 的 Task → 将 `Design spec:` 字段完整注入 subagent prompt
4. 每个 Task subagent 指定 `model: "sonnet"`
5. Phase 编译验证铁律 + Phase review（`implement-reviewer` agent）仍适用
6. subagent 返回的 4 种状态按 superpowers skill 规则处理

**如果用户选择手动模式**：继续下方的 Step 0.5 → Step 1-5。

### Step 0.5: Memory 预加载（两种模式都必须执行）

1. 读取 `~/.claude/memory/details/implement/INDEX.md`，浏览其中的文件列表和关键词列
2. 对照 `06-code-plan.md` 的技术栈、任务描述、涉及模块，判断哪些文件与本次实施相关
3. 读取所有相关文件，把其中的踩坑规则纳入后续执行的注意事项

> 判断标准：宽松优于严格。有 20% 的关联可能就读取，避免遗漏。读取成本低，踩坑成本高。

**Subagent 模式额外操作**：将读取到的相关内容压缩为 `## 已知陷阱` 段落，注入每个 subagent 的 prompt。

### Step 0.6: 设计规格确认（当有设计稿时）

快速检查 `06-code-plan.md` 中的 UI Task 是否包含 `**Design spec:**` 字段：
- **有**：规格已内嵌，无需额外操作
- **没有**（旧版 code-plan 产出）：从 `05-design.md` 的代码级规格表中，为每个 UI Task 手动补充 Design spec 字段

### Step 1: 加载任务列表

从 `06-code-plan.md` 解析任务列表：
- 提取所有 Phase 和任务
- 识别依赖关系和并行标记 [P]
- 确认当前完成状态（之前可能部分完成）

### Step 2: 按 Phase 执行

对每个 Phase：

1. **Phase 开始**：告知用户当前 Phase 名称和包含的任务数
2. **逐任务执行**：
   - 开始前告知用户："正在执行 T00X: <任务描述>"
   - 🔒 **涉及 UI 的 Task：按 Design spec 字段中的数值写代码**（快捷模式也不跳过）：
     - code-plan 阶段已将设计规格拆解并内嵌到每个 UI Task 的 `**Design spec:**` 字段
     - 直接使用该字段中的数值（padding、fontSize、color、cornerRadius、gap 等）写入 StyleSheet，**禁止凭感觉猜**
     - 如果 Design spec 字段不存在或不够详细，从 `05-design.md` 的代码级规格表中查找补充
     > ⛔ "看起来差不多"不是验收标准——cornerRadius 12 和 16 的区别用户一眼就能看出来
     > 判断是否涉及 UI：Task 的 Files 字段包含 Screen/Component 文件（.tsx/.kt/.swift/.vue 等），或 Do 字段提到页面/布局/交互
   - 按任务描述的 **Do:** 字段创建/修改文件
   - 标记 [P] 的任务可并行执行（如果 Claude 支持）
3. **Task 完成确认**：运行 **Verify:** 字段中的验证命令，通过即在 06-code-plan.md 中标记 `[x]`。
   > 代码质量、设计还原度、交互完整性等审查由 Phase 级 `implement-reviewer` agent 统一覆盖，不在 Task 级自检。
4. 🔒 **Phase 编译验证** [small: 降级为最终验证]

   > ⚡ **small 复杂度**：Phase 编译验证降级为所有 Phase 完成后一次性验证（Step 5）。Phase review 也跳过。

   <HARD-GATE>
   每个 Phase 完成后 MUST run build/test verification. Do NOT proceed to next Phase until verification passes.
   </HARD-GATE>

5. 🔍 **Phase Review**（编译通过后执行）[small: 跳过]

   Dispatch `implement-reviewer` agent 审查该 Phase 的所有 Task：

   ```
   Agent(subagent_type="implement-reviewer", model="sonnet", prompt="""
   phase_name: "<Phase 名>"
   task_list: "<该 Phase 所有 Task 的完整描述（含 Files/Design spec/Do）>"
   changed_files: "<该 Phase 变更的文件路径列表>"
   plan_path: "<04-plan.md 绝对路径>"
   code_plan_path: "<06-code-plan.md 绝对路径>"
   known_pitfalls: "<Step 0.5 读取的踩坑经验摘要>"
   """)
   ```

   - **✅ Approved** → 进入下一 Phase
   - **⚠️ Issues Found** → 修复 issue 后重新 dispatch reviewer（最多 2 轮，超过 2 轮展示给用户决定）

6. **Phase 报告**：告知用户 Phase 完成情况 + review 结果

### Step 3: 错误处理

- 任务失败：记录错误，尝试修复一次
- 连续失败 2 次：停下，报告问题，询问用户如何处理
- 不阻塞并行任务：并行任务中某个失败不影响其他任务继续

### Step 4: 实施日志

持续更新 `.build/07-implement-log.md`：

```markdown
# <功能名> — 实施日志

## 概况
- **当前状态**: <进行中/已完成>
- **已完成任务**: X / Y

## 执行记录
<!-- 每个 Phase 一个表格：| 任务 | 状态 | 变更文件 | 备注 | -->

## Phase Review 记录
<!-- 每个 Phase review 的裁决结果和修复的 issue -->

## 遇到的问题
<!-- 编号列出：问题描述 → 原因 → 解决方案 → 状态 -->

## 变更文件汇总
```

### Step 5: 完成验证

所有任务完成后：
1. 检查所有任务是否标记为 `[x]`
2. 运行项目级编译/构建验证
3. 确认所有 Phase review 结果为 Approved（或 issue 已修复）

## 交接

本阶段完成后：
1. 更新 `.build/07-implement-log.md`
2. 更新 `_manifest.json`：`implement.status = "completed"`，`implement.output = "07-implement-log.md"`，`implement.completed_at = "<时间>"`
3. 向用户展示实施概况（完成任务数、遇到问题数、变更文件数）
4. 下一步建议：进入 **验收检查阶段**
5. 交回编排器控制权
