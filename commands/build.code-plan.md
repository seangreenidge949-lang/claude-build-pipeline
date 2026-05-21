---
description: "Build Pipeline Stage 6: 代码计划。拆分实现任务，规划技术架构和文件结构。"
---

# Stage 6: 代码计划 (Code Plan)

## Stage Contract
- **requires**: `.build/01-specify.md`, `.build/04-plan.md`
- **optional**: `.build/02-research.md`, `.build/05-design.md`
- **produces**: `.build/06-code-plan.md`
- **precondition**: specify 和 plan 阶段已 completed

## 前置检查

运行前置检查脚本：
```bash
~/.claude/scripts/check-build-prerequisites.sh code-plan --json
```

解析 JSON 输出。如果脚本返回非零退出码（specify 或 plan 未完成），停止执行并告知用户。
从 `available_docs` 读取所有可用的前序文件：`01-specify.md`、`04-plan.md`（必读）、`05-design.md`（如有）、`02-research.md`（如有）。

## 执行流程

### Step 0: 读取设计规格（当 05-design.md 存在时）

> 🔒 **铁律**：有设计稿时，此步骤不可跳过，任何复杂度都不跳过。
> 没有设计稿（05-design.md 不存在）时跳过整个 Step 0，进入 Step 1。

**优先从 05-design.md 读取（消除重复提取）**：

design 阶段（build.design.md Step 5）已经从 .pen 文件提取了代码级规格表并写入 `05-design.md`。code-plan 阶段不需要再做一遍。

**0.1 检查 05-design.md 是否包含规格表**

读取 `05-design.md`，搜索「代码级规格表」章节：

- **如果存在**：直接从 05-design.md 读取以下内容，引用到 06-code-plan.md 中：
  - 设计变量（颜色/间距 token）
  - 逐页面的代码级规格表
  - 组件清单和复用次数
  - 不再执行 `get_variables` / `batch_get` / `get_screenshot` 等 .pen MCP 工具调用

- **如果不存在**（兼容旧版产出或 design 阶段未提取）：
  - 从 `05-design.md` 或 `_manifest.json` 的 `external_refs.pencil` 定位 .pen 文件
  - Fallback 到完整提取逻辑：
    - `get_variables(filePath)` → 提取颜色/间距 token
    - `batch_get(filePath, readDepth=1)` → 获取页面列表
    - 对每个页面：`get_screenshot` + `batch_get(readDepth=4-5, resolveVariables=true)` → 提取规格
    - 识别复用组件
    - 标注设计 vs PRD 差异
  - 将提取结果写入 06-code-plan.md

> 原则：UI 布局/样式以设计稿为准，业务逻辑/交互行为以 PRD 为准。

---

### Step 1: 技术栈确认与架构细化

**1.1 技术栈正式确认**

从 04-plan.md 的"技术偏好"中读取已知信息。如果技术栈尚未完全确认，用 AskUserQuestion 向用户确认：语言、框架、数据库、部署方式。如用户不确定，根据项目特点给出 2-3 个组合推荐（附简要理由）。

确认后记录到 06-code-plan.md 的技术架构章节。

**1.2 数据模型代码级定义**

从 04-plan.md 的"数据模型概要"（5a）中提取概念级实体和关系，细化为**代码级完整定义**：
- 用确认的语言/框架的语法写出完整结构（字段、类型、约束、默认值）
- 补充 plan 阶段未涉及的实现细节（索引、迁移策略、ORM 映射等）
- **每个被多处读写的字段必须声明值域和上下游**：格式为 `字段名: 类型 — 值域: {枚举值/格式约束} — 写入方: [谁生成] — 消费方: [谁读取/展示/筛选]`。特别是 AI 生成的字段，prompt 中的示例值/约束必须与 UI 预设值保持一致（如 UI 用中文标签筛选，prompt 就必须约束输出中文标签）
- **对照 Step 0 的设计规格**：检查设计稿中是否有 PRD 未提及的字段（如设计稿显示了"旅程天数"字段但 PRD 数据模型中没有），补充到数据模型中

**1.3 接口完整定义**

从 04-plan.md 的"接口概要"（5b）中提取核心接口，细化为**完整签名**：
- 每个接口包含：路径、方法、请求参数（类型+校验规则）、响应结构（完整字段）
- 补充认证、限流、版本控制等实现层细节

**1.4 项目结构**

1. **目录规划、模块划分**（新项目从零设计；已有项目先 Explore 现有代码结构，标注哪些是新增、哪些是修改）
2. **补充技术细节**：构建工具、测试框架、lint 配置等
3. **组件文件映射**：将 Step 0 提取的组件规格表映射到具体文件路径，确保每个设计组件都有对应的代码文件

### Step 1.5: 规格表拆解（当有设计规格时 MUST 执行）

> 目的：把完整规格表按页面/组件拆成碎片，后续 Step 2 中每个 UI Task 只注入相关碎片，而非整张表。

**拆解规则**：

```
规格表内容                       注入到哪些 Task
────────────────                ──────────────
全局规范（颜色/字体/间距系统）    → 所有 UI Task 的 Design spec 字段（压缩为 1-2 行摘要）
                                  格式："全局：主背景 #xxx, 卡片 #xxx, 主色 #xxx, 主文字 #xxx, 次文字 #xxx"

页面级规格（### 主页）           → 匹配到的 Screen Task（如 T012 HomeScreen）
                                  匹配方式：Task Files 字段中的文件名含 XxxScreen → 匹配 ### Xxx页

共享组件规格（Tab Bar、状态栏等） → 组件 Task（如 T009 实现 Tab Bar）
                                  从组件清单中识别，取首次出现页面中的属性
```

**执行方式**：在脑中完成映射，不生成独立文档。在 Step 2 写每个 UI Task 时直接填入 Design spec 字段。

### Step 2: 任务拆分

将实现拆分为有序任务列表，格式如下：

```markdown
> 执行方式：通过 `/build.implement` 按 Phase 顺序执行以下任务列表。

## Phase 1: 项目初始化

### T001 创建项目结构和配置文件
**Files:** package.json, tsconfig.json, 目录结构
**Do:**
- 创建项目根目录和子目录
- 初始化 package.json 和 tsconfig.json
**Verify:**
- `ls -la` 确认目录结构正确

### T002 安装依赖
**Files:** package.json, package-lock.json
**Do:**
- 安装运行时依赖和开发依赖
**Verify:**
- `npm install` 无报错
- `node -e "require('./package.json')"` 通过

## Phase 2: 核心功能

### T003 [P] 功能模块 A
**Files:** src/features/a/index.ts, src/features/a/utils.ts
**Design spec:** TD-01 TripCard — h200 r20, 全宽 Image + 渐变 overlay, 标题 f22 w700 white
**Do:**
- 实现 XX 函数（参数、返回值）
- 处理边界情况
**Verify:**
- `npm test -- --filter=a` 通过
- 或：手动验证 XX 行为正常
```

**任务格式**：
- 每个 Task 用 `### T00X` 开头
- 必须包含 `**Files:**`、`**Do:**`、`**Verify:**` 三个字段
- 🔒 **涉及 UI 的 Task 必须增加 `**Design spec:**` 字段**（Step 1.5 已完成拆解，直接填入）：
  - 第 1 行：全局规范摘要（1 行，颜色/字体 token）
  - 后续行：该 Task 对应页面/组件的规格表（从 Step 0 规格表中精准切出，只包含该 Task 涉及的组件）
  - 判断标准：Task 的 Files 包含 Screen/Component 文件，或 Do 提到页面/布局/交互
  - ⛔ 禁止写"参见 05-design.md"——implement 阶段不应该再去翻其他文件找数值
- `[P]` 标记可并行任务
- `**Verify:**` 必须是可直接粘贴到终端运行的命令

**任务粒度标准**：
- 每个 Task 应在 2-5 分钟内可完成
- 单个 Task 修改不超过 2-3 个文件
- 如果一个 Task 描述超过 5 行，它可能需要拆分

**拆分原则**：
- 按依赖关系排序
- 测试任务放在实现任务之后（除非用户要求 TDD）
- 同文件的任务必须串行
- 每个 Phase 应是可独立验证的增量

### Step 3: 风险识别

- 技术风险：不确定的 API、性能瓶颈
- 依赖风险：第三方服务稳定性
- 范围风险：可能膨胀的需求点
- **设计还原风险**：设计稿中使用了框架不直接支持的效果（如 RN 不支持 CSS gradient，需要记录替代方案）

### Step 4: 自动 Plan Review [快捷模式: 跳过]

> ⚡ **small 复杂度**：如果 `_manifest.json` 中 `complexity == "small"`，跳过整个 Step 4，直接进入 Step 5 输出。

代码计划写完后，**必须** dispatch 一个 reviewer subagent 做自动审查：

```
使用 Agent 工具，dispatch general-purpose subagent：

prompt: |
  你是代码计划审查员。审查以下代码计划，确认其可直接交给开发执行。

  **代码计划路径**: [06-code-plan.md 的完整路径]
  **产品方案路径**: [04-plan.md 的完整路径]
  **需求规格路径**: [01-specify.md 的完整路径]

  ## 审查维度

  | 维度 | 检查项 |
  |------|--------|
  | 方案覆盖 | 04-plan.md 中的每个功能点是否都有对应的 Task？有无遗漏？ |
  | 任务可执行 | 每个 Task 是否都有 Files/Do/Verify 三个字段？Verify 命令能直接运行吗？ |
  | 依赖正确 | 任务顺序是否合理？有无循环依赖或遗漏前置？ |
  | 粒度合理 | 是否有 Task 明显过大（描述>5行、改>3文件）需要拆分？ |
  | 技术选型 | 选型是否与项目现有技术栈一致？有无不必要的新依赖引入？ |
  | 设计规格绑定 | 涉及 UI 的 Task 是否都有 Design spec 字段？规格值是否来自 .pen 提取而非猜测？ |

  ## 已知陷阱
  [从 MEMORY.md 中提取与当前技术栈相关的踩坑经验，无则留空]

  ## 校准
  只标记会导致实现阶段卡住或返工的问题。
  任务描述的措辞风格不是 issue——只关注可执行性。

  ## 输出格式
  ## 代码计划审查结果
  **状态:** Approved | Issues Found
  **Issues (如有):**
  - [Task/Section]: [具体问题] - [为什么会导致卡住]
  **建议 (不阻塞 approve):**
  - [改进建议]
```

**审查循环**：
- Issues Found → 修复问题 → 重新 dispatch reviewer
- 最多 3 轮。超过 3 轮 → 将问题列表展示给用户，由人类决定
- Approved → 进入 Step 5

### Step 5: 输出

写入 `.build/06-code-plan.md`：

```markdown
# <功能名> — 代码计划

## 技术架构
### 技术栈（引用自 04-plan.md）
| 层级 | 选择 | 理由 |
|------|------|------|
| 语言 | ... | ... |
| 框架 | ... | ... |

### 已知陷阱（从错题本）
- ...

### 补充技术细节
- 构建工具: ...
- 测试框架: ...
- Lint/格式化: ...

### 项目结构
<目录树>
<!-- 已有项目：标注 [新增] / [修改] -->

### 数据模型（引用自 04-plan.md 5a）
<实体关系描述>

## 设计变量（从 .pen 提取，如有）
<颜色/间距 token 表>

## 代码级设计规格表（从 .pen 提取，如有）
### <页面1>
| 区域 | 布局 | 尺寸 | 间距 | 圆角 | 颜色 | 字号/字重 | 特殊样式 |
|------|------|------|------|------|------|----------|---------|
| ... | ... | ... | ... | ... | ... | ... | ... |

### <页面2>
...

## 组件规格表（从 .pen 提取，如有）
### <组件名>
- 结构: ...
- Props: ...
- 关键样式值: ...

## 设计稿 vs PRD 差异（如有）
| 页面 | 差异点 | 设计稿 | PRD | 采信 |
|------|--------|--------|-----|------|
| ... | ... | ... | ... | ... |

## 任务列表
<按 Phase 组织的任务清单，UI Task 含 Design spec 字段>

## 依赖关系
<哪些任务必须在其他任务之前完成>

## 风险点
- <风险 1>：<影响> / <应对方案>

## 预估工作量
- 总任务数: <N>
- 可并行任务: <M>
```

## 交接

本阶段完成后：
1. 将产出写入 `.build/06-code-plan.md`（已在 Step 5 完成）
2. 更新 `_manifest.json`：`code-plan.status = "completed"`，`code-plan.output = "06-code-plan.md"`，`code-plan.completed_at = "<时间>"`
3. 向用户展示任务概览（总数、Phase 数、预估）+ Plan Review 结果
4. 下一步建议：进入 **代码实施阶段**（此后 implement 不可跳过）
5. 交回编排器控制权
