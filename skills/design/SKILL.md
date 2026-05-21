---
name: design
description: AI 设计工作流。从需求到高保真 Pencil 设计稿的完整流程。支持 --explore（专业模式，3个并行概念方向+深度审查+记忆库更新）和 --fast（快速模式，1个方向+1轮审查）。用法：/design --explore 设计一个 iOS 记账 App，/design --fast 优化这个登录页
---

# UI Master 设计工作流

## 解析入口参数

用户输入格式：`/design --explore <需求描述>` 或 `/design --fast <需求描述>`

- 提取 `mode`：explore 或 fast
- 提取 `request`：需求描述文字
- 提取 `build_context`：是否携带 `--build-context` flag（由 build.design 注入时携带，独立运行时无此 flag）

如果 `mode` 未提供：
- 检查当前目录的 `_manifest.json` 是否存在 `complexity` 字段，按以下规则推断：
  - `small` → fast
  - `medium` / `large` → explore
- 若无 manifest 或无法推断，询问用户选择 explore 或 fast

## Step 1：需求确认

### Step 1.0 — 产品文档检测

在开始对话确认之前，先检查是否存在现有产品文档：

1. 检查 `.build/04-plan.md`（build 流水线的产品方案）
2. 检查 `.build/01-specify.md`（build 流水线的需求规格）
3. 检查用户提及的其他产品文档路径

**如果找到产品文档**：
- 读取文档内容，自动提取 product_description、target_users、platform、page_list、main_flow_pages
- 将文档路径记录到 `brief.json` 的 `product_doc_path` 字段
- 向用户展示提取结果，仅确认缺失项或需要修正的信息
- 告知用户：「检测到产品文档 {path}，已自动提取需求信息。以下是提取结果，请确认或补充：[展示]」

**如果未找到产品文档**：
- 进入标准的多轮对话确认流程（见下方）

### Step 1.1 — 需求对话确认

通过对话确认以下**功能性信息**（可多轮）。注意：**不问调性/风格/审美偏好**——用户在没看到任何参考之前无法给出有效的审美判断，调性会在 Step 2 用户看完研究成果后自然形成。

```
必须确认：
- product_description（这是什么产品，做什么用的）
- target_users（目标用户描述）
- platform（iOS / Android / Web / Mac / Windows）
- page_list（页面清单，用户可以说"你来推断"）

可选确认：
- main_flow_pages（主链路 3-5 张，用户有产品方案就用，没有则留空由 researcher 自动推断最简主链路）
- constraints.brand_rules（品牌规范）
- constraints.forbidden（禁忌）
- constraints.existing_design_system（已有设计系统）
```

确认完成后，在当前项目目录创建 `.design/` 并写入 `brief.json`：

```json
{
  "product_description": "",
  "target_users": "",
  "platform": "",
  "page_list": [],
  "main_flow_pages": [],
  "tone": [],
  "product_doc_path": null,
  "constraints": {
    "brand_rules": null,
    "forbidden": [],
    "existing_design_system": null
  },
  "mode": "explore 或 fast"
}
```

**注意**：`tone` 字段此时留空 `[]`，将在 Step 2 用户形成审美偏好后写入。`main_flow_pages` 如果用户未提供则留空 `[]`，由 researcher 在 Step 2 基于产品描述自动推断。

告知用户：「需求已记录，开始研究设计方向...」

## Step 2：设计研究 + 用户形成审美偏好

这一步的核心目标不只是收集素材，而是**帮助用户形成审美判断**。用户在 Step 1 只提供了功能性信息，对设计方向没有概念。通过展示案例和概念联想，让用户第一次「看到」可能的方向，然后表达偏好。

### explore 模式

#### Step 2.1 — 生成搜索计划

Skill 自己根据 brief.json 中的 `product_description`、`platform`、`target_users` 生成搜索计划，写入 `.design/search-plan.json`：

```json
{
  "case_group_1": ["关键词1", "关键词2", "关键词3"],
  "case_group_2": ["关键词4", "关键词5", "关键词6"],
  "concepts": ["概念词1", "概念词2", "概念词3"],
  "fallback_products": ["具体产品名1", "产品名2", "产品名3", "产品名4"]
}
```

**关键词生成规则**：
- case_group_1：侧重品类直接竞品（如 `expense tracker app {platform} UI design`）
- case_group_2：侧重相关品类或差异化设计（如 `personal finance {platform} clean minimal UI`）
- concepts：从产品核心体验（不是功能）出发提炼 2-3 个抽象概念词（如记账→「掌控感」→「精准」）
- fallback_products：4-6 个已知的具体产品名

展示给用户（不等待确认，同时启动 agent）：

「🔍 搜索计划已生成，开始并行研究...
- 案例搜索 A：{case_group_1 摘要}
- 案例搜索 B：{case_group_2 摘要}
- 概念联想：{concepts 列表}
- 记忆库：过滤相关经验」

#### Step 2.2 — 并行派发 4 个 Agent

同时创建各 agent 的分片输出文件占位（避免写入冲突），然后并行派发：

```
Agent A: design-researcher（案例搜索组 1）
  prompt: "读取 .design/brief.json 和 search-plan.json。
           task: cases。使用 case_group_1 中的关键词搜索 3 个案例。
           按 9 维框架提炼，截图保存到 .design/screenshots/。
           输出写入 .design/research-cases-1.md。
           如果用户未提供 main_flow_pages（brief.json 中为空数组），
           基于 product_description 推断最简主链路并写入 brief.json。"

Agent B: design-researcher（案例搜索组 2）
  prompt: "读取 .design/brief.json 和 search-plan.json。
           task: cases。使用 case_group_2 中的关键词搜索 3 个案例。
           按 9 维框架提炼，截图保存到 .design/screenshots/。
           输出写入 .design/research-cases-2.md"

Agent C: design-researcher（概念联想）
  prompt: "读取 .design/brief.json 和 search-plan.json。
           task: concepts。使用 concepts 中的概念词做联想展开+视觉参考搜索。
           输出写入 .design/research-concepts.md"

Agent D: design-librarian
  prompt: "读取 .design/brief.json，action: read，从美学参考库 ~/projects/美学参考/index.md 过滤相关经验，
           输出写入 .design/research-library.md"
```

#### Step 2.3 — 合并结果

4 个 Agent 全部完成后，Skill 执行合并：

1. **合并 direction-brief.md**：读取 research-cases-1.md + research-cases-2.md + research-concepts.md + research-library.md，按以下结构合并写入 `.design/direction-brief.md`：

```markdown
# 方向简报

## 案例研究摘要
[research-cases-1.md 内容]
[research-cases-2.md 内容]

## 设计概念联想
[research-concepts.md 内容]

## 记忆库相关经验
[research-library.md 内容]
```

2. **生成 moodboard.html**：基于合并后的 direction-brief.md 生成可视化情绪板。HTML 结构要点：
   - 深色背景（#0a0a0a），简洁排版，最大宽度 1200px
   - **案例区**：3 列网格，每张卡片包含截图（img 标签 + onerror 降级）、产品名+定位、风格标签、组件洞察、核心意图
   - **概念区**：每个概念一个宽卡片，包含概念词+推导逻辑、联想链、视觉参考图、9 维设计语言描述

3. **归档研究洞察**：派发 design-librarian 把 researcher 发现的优秀组件洞察即时存入记忆库：
   ```
   Agent: design-librarian
     prompt: "读取 .design/direction-brief.md。action: archive-research。
              把值得跨项目迁移的设计洞察提炼后写入记忆库"
   ```

4. **展示情绪板**：将 `.design/moodboard.html` 在浏览器中展示给用户（或用 Playwright 截图展示）

5. **引导用户形成偏好**：
   「研究完成，请查看设计情绪板。包含 {N} 个同类产品案例和 {M} 个设计概念方向。

   看完后告诉我你的感受：
   - 哪个案例的感觉最接近你想要的？
   - 哪个概念方向最打动你？
   - 或者描述你想要的感觉（如"案例3的配色+概念2的空间感"）

   也可以说"跳过"让 designer 自由发挥。」

6. **记录用户偏好**：将用户的审美判断写入 `brief.json` 的 `tone` 字段（提炼为关键词），以及更新 `.design/user-preference.md` 记录用户原话。

**用户取消/跳过处理**：
- 用户要求补充信息或重新搜索 → 更新 search-plan.json，重新派发对应 agent
- 用户说"跳过" → tone 留空，进入 Step 3，designer 基于 brief.json 和 direction-brief 自由发挥

### fast 模式

**先由 Skill 创建仅含记忆库章节的 direction-brief.md 模板**：

```markdown
# 方向简报（快速模式）

## 记忆库相关经验
<!-- librarian 写入此章节 -->
```

仅派发 design-librarian：
```
Agent: design-librarian
  prompt: "读取 .design/brief.json，action: read，从记忆库过滤相关经验，
           写入 .design/direction-brief.md 的「记忆库相关经验」章节"
```

展示给用户确认，同样支持跳过选项。

**降级**：若记忆库无匹配记录，告知用户「未找到相关历史经验，designer 将基于需求自由发挥」，直接进入 Step 3。

## Designer 约束注入（所有 designer 调用必须遵守）

每次派发 design-designer 时，prompt 中 MUST 包含以下指令块（复制粘贴，不得省略）：

```
【必读约束文件 — 文件存在时必须读取，不存在则跳过】
- ~/.claude/skills/design/references/design-vs-doc.md
  → 设计稿与产品文档的关系铁律（元素有无 follow 产品文档；产品文档 > 设计规范 > 设计直觉）
  → 设计时：严格对照产品文档，不得基于"设计常识"自行增删元素
- ~/.claude/skills/design/references/reflection.md
  → 历史审查积累的失败模式（AI 陷阱命中记录）与有效定制决策
  → 设计时：主动规避失败模式；参考已验证的成功决策
```

> 这是跨会话的设计记忆注入点。每次成功设计后，Step 7.5 会自动更新此文件，形成持续学习飞轮。

---

## Step 3：概念方向生成 + 用户选方向

### explore 模式

并行派发三个 designer agent：

```
Agent 1: design-designer
  prompt: "不需要确认计划，直接执行。读取 .design/brief.json、direction-brief.md 和 user-preference.md（如存在）。执行「Designer 约束注入」章节中的必读约束文件。role: concept, direction: A（学习型）。所有设计决策自行判断，产出样张和 concept-A.md"

Agent 2: design-designer
  prompt: "不需要确认计划，直接执行。读取 .design/brief.json、direction-brief.md 和 user-preference.md（如存在）。执行「Designer 约束注入」章节中的必读约束文件。role: concept, direction: B（创新型）。所有设计决策自行判断，产出样张和 concept-B.md"

Agent 3: design-designer
  prompt: "不需要确认计划，直接执行。读取 .design/brief.json、direction-brief.md 和 user-preference.md（如存在）。执行「Designer 约束注入」章节中的必读约束文件。role: concept, direction: C（经验型）。所有设计决策自行判断，产出样张和 concept-C.md"
```

三个 Agent 完成后，用 Pencil MCP 截取三个方向的样张，**直接展示给用户选择**（不经过 critic，让用户先看原始结果）：

「三个概念方向已完成，请查看 Pencil 编辑器中的 Concept-A/B/C：
- A（学习型）：[设计理念核心主张]
- B（创新型）：[设计理念核心主张]
- C（经验型）：[设计理念核心主张]

请选择方向（A/B/C），或描述你的偏好（如"A 的配色 + B 的排版风格"）。
如果三个方向都不满意，说明追加约束，我会重新生成。」

**用户对三个方向均不满意**：收集追加约束 → 更新 brief.json 的 constraints 字段 → 重新并行派发三个 designer（不限次数）。

### fast 模式

仅派发一个 designer（创新型），完成后直接展示给用户确认：
```
Agent: design-designer
  prompt: "读取 .design/brief.json、direction-brief.md 和 user-preference.md（如存在）。执行「Designer 约束注入」章节中的必读约束文件。role: concept, direction: B（创新型）。产出样张和 concept-B.md"
```

### 用户确认选定方向后

写入 `.design/selected-concept.json`：
```json
{ "direction": "B", "concept_file": "concept-B.md", "notes": "用户备注" }
```

然后进入 Step 4 aesthetic-critic 审查。

---

## Step 4：美学审查循环（explore 模式必须，fast 模式跳过）

**fast 模式**：跳过，直接进入 Step 5。

**explore 模式**：**无强制轮数，事件驱动**，只审查用户选定的方向。有 must_fix 则自动继续；must_fix 为空则交给用户决定是否继续。

### 版本迭代规则（HARD-GATE，贯穿所有审查轮次）

<HARD-GATE>
每次派发 designer 修改时，MUST 新建版本 frame，禁止在原 frame 上覆盖：
- 第 1 轮（初始稿）：frame 命名为 `concept-{X}-v1`，同时写入 `.design/version-map.json` 记录 nodeId
- 第 N 轮修改后：新建 `concept-{X}-v{N}` frame，保留所有旧版本
- 旧版本永远不删除

目的：保留完整进化轨迹，支持用户对比；reviewer 需要当前版本 nodeId 才能直接截图审查。
</HARD-GATE>

### 版本记录文件

`.design/version-map.json` 由 designer 每次创建新 frame 后写入/更新：
```json
{
  "concept-B": [
    { "version": "v1", "nodeId": "xxxx", "created_at": "..." },
    { "version": "v2", "nodeId": "yyyy", "created_at": "..." }
  ]
}
```

### 每轮执行步骤

1. 从 `.design/version-map.json` 读取当前最新版本的 nodeId
2. 派发 design-aesthetic-critic，prompt 包含：
   - 读取 `.design/brief.json`、`user-preference.md`、`concept-{X}.md`
   - **当前版本信息**：`请使用 mcp__pencil__get_screenshot(filePath=<pen文件路径>, nodeId=<当前版本nodeId>) 获取截图，这是第 {round} 轮要审查的内容`
   - 方向类型 {A/B/C}
   - 输出 `.design/aesthetic-round-{round}.json`
   - 三层审查框架：
     - 第一层：地基（→ must_fix）：视觉层次、间距系统（4/8px）、颜色系统（60-30-10）、字体层级
     - 第二层：精致感（→ must_fix）：组件一致性、图标一致性、对齐、信息密度
     - 第三层：情感（→ suggest_fix，风格严重不符 → must_fix）：风格匹配、5 秒第一印象
3. 读取审查结果，按以下条件处理：
   - **有 must_fix** → 告知用户「第 {round} 轮发现 {N} 个必须修改项，正在处理...」，派发 designer，prompt 中**直接注入**：
     ```
     被审查版本：concept-{X}-v{round}（nodeId: {nodeId}，你可以用 get_screenshot 查看这是什么样子）
     本轮 must_fix（意见针对上述版本，逐条包含：维度 + 位置/元素 + 问题 + 改法）：
     {逐条列出}
     ⚠️ 新建 concept-{X}-v{round+1} frame，写入 version-map.json，不要修改 v{round}。
     ```
     round += 1，继续下一轮
   - **must_fix 为空** → 展示当前结果摘要（总分/50 + suggest_fix 条数），询问用户：
     ```
     第 {round} 轮美学审查通过（总分 {score}/50，must_fix 为空）。
     已完成 {round} 轮审查，版本记录：concept-{X}-v1 → ... → v{round}

     请选择：
     ① 确认方向，继续出完整稿
     ② 有 suggest_fix 想调整（描述你的修改意见，我来派 designer 处理）
     ③ 再审查一轮（继续提升质量）
     ```
     - 用户选 ① → 进入 Step 4.5
     - 用户选 ② → 收集意见，派发 designer（prompt 中注入当前版本 nodeId + 用户原话 + 相关 suggest_fix 条目），round 不计入最少轮次
     - 用户选 ③ → round += 1，继续下一轮审查

## Step 4.5：概念入库提示（explore + fast 模式均执行）

在进入完整稿产出前，询问用户是否要将概念方向存入美学参考库。

### explore 模式

此时有 3 个概念方向（A/B/C），其中 1 个通过了美学审查。询问用户：

「概念稿已通过审查。是否要将设计方向存入美学参考库？存入后下次做类似项目可以直接参考或复用。

可入库的方向：
- ✅ {selected}（已审查，评分 {score}/50）— 推荐入库
- {other1}（未审查）
- {other2}（未审查）

请选择要入库的方向（可多选，如 "A和B"），或 "跳过" 不入库。」

### fast 模式

此时只有 1 个概念方向。询问用户：

「概念稿已确认。是否要将这个设计方向存入美学参考库？
- 存入：下次类似项目可直接参考或复用（含截图、源文件、设计 token）
- 跳过：不入库，直接出完整稿」

### 用户确认入库后

1. 记录用户选择，写入 `.design/archived-concepts.json`：
```json
{ "directions": ["B"], "timestamp": "..." }
```

2. 对每个选定方向，派发 design-librarian：
```
Agent: design-librarian
  prompt: "读取 .design/brief.json。action: archive-concepts。
           directions: [{用户选定的方向列表}]。
           为每个方向创建完整交付包（screenshot.png + source.pen + brief.md + source-info.md + tokens.json），
           存入美学参考库 ~/projects/美学参考/refs/，更新 index.md。"
```

3. Librarian 完成后，告知用户：
「已入库 {N} 个方向到美学参考库：
{列出每个 ref-id 和核心主张}
继续出完整稿...」

**用户跳过**：直接进入 Step 5。

---

## Step 5：完整设计稿产出

### Step 5.pre — 读取设计经验（HARD-GATE，不可跳过）

<HARD-GATE>
在 Step 5 的任何子步骤之前，MUST 先读取 `~/.claude/skills/design/references/` 下的设计经验文件。
这些文件包含历史踩坑经验和铁律，直接影响设计质量。未读取不得开始设计。
</HARD-GATE>

1. `Read ~/.claude/skills/design/references/design-vs-doc.md` — 设计稿与产品文档的关系铁律
2. `Read ~/.claude/memory/details/design/pencil-tips.md` — Pencil 工具经验（共享文件）
3. `Read ~/.claude/skills/design/references/reflection.md`（如存在）— 历史审查失败模式
4. 其他 `~/.claude/skills/design/references/` 下的文件（如有）

关键铁律提醒（读完后内化，贯穿整个 Step 5）：
- **元素有无 follow 产品文档**（不可缺、不可多），位置样式 follow 设计审美
- **产品文档 > 设计规范 > 设计直觉**：设计规范是通用建议，产品文档是具体决策，冲突时以产品文档为准
- **不得基于"设计常识"自行添加产品文档中不存在的元素**（如产品文档没有 Tab Bar 就不加）
- **回滚/修改后必须对照产品文档做完整性检查**，不是恢复到"上一个状态"而是恢复到"文档定义的状态"

### Step 5.0 — 页面跳转关系图（HARD-GATE，不可跳过）

<HARD-GATE>
在派发任何 designer 之前，MUST 先构建「页面跳转关系图」，明确每个页面的入口和出口。未完成不得开始设计。
</HARD-GATE>

Skill 自己根据产品文档构建跳转关系图，写入 `.design/navigation-map.md`，包含：**全局导航**（Tab Bar 出现/不出现的页面列表）；**逐页入口/出口**（每页记录：入口来源+触发元素、出口列表（触发元素→目标页面）、FAB/浮动按钮有无及位置、特殊入口组件如语音/编辑等）。

构建完成后**展示给用户确认**。

### Step 5.1 — designer prompt 模板（强制包含入口/出口检查）

派发 designer 时，每个页面的 prompt 末尾 MUST 包含以下段落（从 navigation-map.md 中提取该页面的入口/出口信息）：

```
## 入口/出口完整性检查（HARD-GATE，不可跳过）

本页面的跳转关系（摘自 navigation-map.md）：
- 入口：{入口描述}
- 出口：
  {出口1}
  {出口2}
  ...
- FAB/浮动按钮：{有/无，描述}
- 特殊入口组件：{描述}

⛔ 设计完成前 MUST 逐项检查以上每个出口元素是否已在设计中体现。
遗漏任何一个入口/出口 = 设计不合格，必须补全后才能标记完成。

自检清单（在 get_screenshot 验证时逐项确认）：
□ 所有出口按钮/FAB/图标是否都已设计？
□ 导航栏右侧的功能入口（编辑/分享/语音等）是否已体现？
□ FAB 的位置是否正确（layoutPosition: absolute + 正确的 x/y）？
□ 底部 Tab Bar 是否按 navigation-map 的规则显示/隐藏？
```

### Step 5.2 — 派发 designer

派发 design-designer：
```
Agent: design-designer
  prompt: "读取 brief.json、selected-concept.json 和 navigation-map.md。执行「Designer 约束注入」章节中的必读约束文件。role: full。加载对应平台规范。先产出 main_flow_pages 中的页面，产出完成后等待确认。
  ⚠️ 每个页面 MUST 包含 navigation-map.md 中定义的所有入口/出口元素。"
```

Designer 完成主链路后，截图展示给用户：

「主链路页面（{N} 张）已完成，请查看 Pencil 编辑器。确认通过？」
- **通过** → 告知 designer 继续产出剩余页面（发送 "继续产出 page_list 中剩余页面"）
- **不通过** → 收集用户修改意见 → 告知 designer 调整 → 重新截图确认

### Step 5.3 — 入口/出口交叉验证（HARD-GATE，不可跳过）

<HARD-GATE>
所有页面产出完成后，MUST 执行入口/出口交叉验证。
验证前 MUST 先用 `export_nodes` 批量导出所有页面截图到 `.design/screenshots/verify-{page}.png`（为每个 page_list 中的页面导出一张）。
Skill 自己（不派 agent）用 Read tool 逐页读取截图，对照 navigation-map.md 确认每个出口元素在设计中可见。
发现遗漏 MUST 立即派发 designer 补全，prompt 中**直接注入交叉验证表中所有 FAIL 项**（页面名、缺失元素、对应 navigation-map 中的定义），不得进入 Step 6。
</HARD-GATE>

验证格式：
```
## 入口/出口交叉验证
| 页面 | 出口元素 | 设计中是否可见 | 状态 |
|------|---------|--------------|------|
| 01-首页 | FAB(+) → 02 | ✅ | PASS |
| 01-首页 | 卡片点击 → 04 | ✅ | PASS |
| 04-纪要 | 追问FAB(💬) → 08 | ❌ | FAIL → 需补全 |
```

所有状态为 PASS 后，确认交付包文件已写入 `.design/deliverables/`。

## Step 6：UX 交互审查循环（所有模式必须执行）

<HARD-GATE>
完整稿产出后，MUST 派发 design-ux-critic 执行跨页审查，不可跳过。
</HARD-GATE>

**无强制轮数，事件驱动**（explore / fast 模式均执行）。有 must_fix 则自动继续；must_fix 为空则交给用户决定是否继续。

### 版本迭代规则（与 Step 4 一致）

Step 5 完整稿产出时，designer 应将所有页面命名为 `{page-name}-v1`（如 `01-首页-v1`、`02-记录-v1`），同时在 `.design/version-map.json` 中登记所有页面的 nodeId：
```json
{
  "pages": {
    "01-首页": [{ "version": "v1", "nodeId": "xxxx" }],
    "02-记录": [{ "version": "v1", "nodeId": "yyyy" }]
  }
}
```
每次 UX 修改：只对涉及修改的页面新建 `{page-name}-v{N}` frame，其他页面保留原版本，旧版本永远不删除。

### 每轮执行步骤

1. 从 `.design/version-map.json` 读取所有页面当前最新版本的 nodeId 列表
2. 派发 design-ux-critic，prompt 包含：
   - 读取 `brief.json`、`navigation-map.md`
   - **当前版本 nodeId 列表**：`请使用 mcp__pencil__get_screenshot 逐页获取截图，nodeId 列表如下：{列表}`
   - 执行跨页审查 + 单页审查 + 功能可达性审查；输出 `.design/ux-round-{round}.json`
   - **功能可达性为 HARD-GATE 级别**：对照 navigation-map.md 逐页检查所有功能入口是否可达、是否存在孤岛页面、FAB/编辑/分享等触发元素是否可见——任何缺失 → must_fix，不可降级
3. 读取结果，按以下条件处理：
   - **有 must_fix** → 展示「第 {round} 轮发现 {N} 个必须修改项，正在处理...」，派发 designer，prompt 中**直接注入**：
     ```
     涉及修改的页面及当前版本（意见针对这些版本，可用 get_screenshot 确认）：
     {页面名 → nodeId 列表，只列有问题的页面}
     本轮 must_fix（逐条包含：页面名 + 元素位置 + 问题 + 改法）：
     {逐条列出}
     ⚠️ 只对涉及修改的页面新建 v{N+1} frame，更新 version-map.json，不修改其他页面。
     ```
     round += 1，继续下一轮
   - **must_fix 为空** → 展示审查结论 + suggest_fix，询问用户：
     ```
     第 {round} 轮 UX 审查通过（must_fix 为空）。已完成 {round} 轮审查。

     请选择：
     ① 确认交付，进入 Step 6.5 规格提取
     ② 有 suggest_fix 想调整（描述你的修改意见）
     ③ 再审查一轮
     ```
     - 用户选 ① → 进入 Step 6.5
     - 用户选 ② → 收集意见，派发 designer（prompt 中注入相关页面 nodeId + 用户原话 + 相关 suggest_fix 条目）
     - 用户选 ③ → round += 1，继续下一轮

## Step 6.5：代码级规格表提取（所有模式必须执行）

<HARD-GATE>
UX 审查通过后、最终交付前，MUST 从 .pen 文件中提取每个页面的精确属性值。
PNG 截图是给人看的，代码级规格表是给 implement 阶段用的。缺少规格表 = implement 只能看图猜数值 = 必然不一致。
未完成规格表提取不得进入最终交付。
</HARD-GATE>

对 page_list 中的每个页面，执行：

1. 用 `batch_get(nodeIds=[页面ID], readDepth=5, resolveVariables=true)` 读取完整节点树
2. 从节点树中提取每个组件的关键属性，输出为规格表

### 必须提取的属性类型

- **布局**：padding、gap、layout（horizontal/vertical）、justifyContent、alignItems
- **尺寸**：width、height（含 fill_container）
- **样式**：fill（颜色）、cornerRadius、stroke、effect（阴影）
- **文字**：fontSize、fontWeight、fontFamily、lineHeight、color
- **图标**：对应的 icon_font name 或 SVG 路径

### 输出格式

每个页面一张规格表，写入 `.design/deliverables/spec-{page_name}.md`：

```markdown
### <页面名>（.pen node: <nodeId>）

| 组件 | 属性 | 值 | .pen 节点路径 |
|------|------|---|-------------|
| StatsCard | cornerRadius | 16 | gXuYZ |
| StatsCard | padding | 16 | gXuYZ |
| StatsCard | fill | #F8F9FA | gXuYZ |
| stat number | fontSize | 28 | qDpQa |
| stat number | fontWeight | 700 | qDpQa |
| stat number | color | #4A90D9 | qDpQa |
| bar track | height | 20 | tLTHE |
| bar track | cornerRadius | 10 | tLTHE |
| ... | ... | ... | ... |
```

同时生成汇总规格表 `.design/deliverables/code-spec.md`，将所有页面的规格表合并，并在头部添加：

```markdown
# 代码级规格表

> implement 阶段写 UI 代码时，MUST 参照此表中的精确数值，不可凭 PNG 截图目测。
> 如需查看更多细节，用 `batch_get(nodeIds=["<nodeId>"], readDepth=5, resolveVariables=true)` 读取 .pen 源文件。

## 全局设计变量
[从 get_variables 提取的全局色板、字体、间距变量]

## 逐页规格
[各页面规格表内容]
```

### 执行步骤

1. 调用 `get_variables(filePath=<pen文件>)` 提取全局设计变量
2. 逐页调用 `batch_get` 提取节点属性
3. 组装为规格表文件
4. 验证：至少每个页面产出 1 张规格表，否则回退重新提取

---

## Step 7：设计语言沉淀

### explore 模式

检查 `.design/archived-concepts.json` 是否存在：

**已入库（Step 4.5 用户选择了入库）**：直接进入最终交付，无需再次询问。

**未入库（Step 4.5 用户选择了跳过）**：做最后一次询问：

「设计已完成。你在概念阶段选择了跳过入库。现在是否要将本次设计方向存入美学参考库？
- **存入**（推荐）：截图、Pencil 源文件、设计 token 和设计理念将被保存，下次类似项目可复用
- **跳过**：不入库，直接交付」

用户选择存入 → 派发 design-librarian：
```
Agent: design-librarian
  prompt: "读取 .design/brief.json 和 .design/selected-concept.json。action: archive-concepts。
           directions: [selected direction]。
           为选定方向创建完整交付包（screenshot.png + source.pen + brief.md + source-info.md + tokens.json），
           存入美学参考库 ~/projects/美学参考/refs/，更新 index.md。"
```

用户选择跳过 → 直接进入最终交付。

### fast 模式（询问用户）

「设计已完成。是否要将本次设计经验存入美学参考库？
- **存入**（推荐，如果对设计风格满意）：下次类似项目可直接复用，包含截图、设计 token 和设计理念
- **跳过**：不入库，直接交付」

用户选择存入 → 派发 design-librarian（同 explore 模式）。
用户选择跳过 → 直接进入最终交付。

## Step 7.5：审美判断沉淀（所有模式，有审查结果时执行）

<HARD-GATE>
如果本次设计经历了 design-aesthetic-critic 审查（即存在 `.design/aesthetic-round-*.json`），MUST 在最终交付前执行审美学习提取。
目的：将这次发现的失败模式持久化，下次设计前读取，不重蹈覆辙。
</HARD-GATE>

读取所有 `.design/aesthetic-round-*.json`，提取以下信息写入 `~/.claude/skills/design/references/reflection.md`（追加模式，不覆盖历史）：

```markdown
## {产品类型} — {日期} — 方向{X}（得分 {N}/50）

### 本次命中的 AI 陷阱
- {陷阱名}：{具体表现} → {修复方式}

### 本次 must_fix 模式
- {维度}：{问题描述} → {有效修复方式}

### 成功的定制决策（通过审查的亮点）
- {设计决策}：{为什么有效}
```

写入后，下次设计时所有 designer 调用将通过「Designer 约束注入」章节自动读取此文件，形成持续学习飞轮。

## 最终交付

「设计完成！交付物：
- Pencil 设计稿：[文件路径]（请记得 Cmd+S 保存）
- 代码级规格表：.design/deliverables/code-spec.md（implement 阶段必读，精确到像素的属性值）
- 设计 Token：.design/deliverables/tokens.json
- 组件清单：.design/deliverables/components.md
- 设计理念：.design/deliverables/design-rationale.md
- 色板规范：.design/deliverables/color-typography-spec.md」

<HARD-GATE>
交付前 MUST 验证 `.design/deliverables/code-spec.md` 存在，且其中至少有 1 个页面级规格表。
如果缺失 → 回到 Step 6.5 执行提取，不可标记交付完成。
</HARD-GATE>

### Build Context 交付（仅当携带 `--build-context` flag 时执行）

完成标准交付物输出后，额外执行：

1. **组装并写入 `.build/05-design.md`**（从 `.design/` 产物中提取）：

```markdown
# <功能名> — 设计记录

## 设计概况
- **设计工具**: Pencil
- **设计源文件**: <.pen 文件路径>
- **审美风格**: <brief.json 的 tone 字段>
- **页面数量**: <page_list 长度>
- **设计模式**: <explore / fast>
- **设计方向**: <selected direction 及核心主张>

## 页面清单
（从 .design/navigation-map.md 和 .design/screenshots/ 读取）
| 页面 | 截图路径 | .pen nodeId | 状态 |
|------|---------|------------|------|

## 组件清单
（从 .design/deliverables/components.md 读取完整内容）

## 代码级规格表

> implement 阶段写 UI 代码时，MUST 参照此表中的精确数值，不可凭 PNG 截图目测。

（从 .design/deliverables/code-spec.md 完整复制）

## 视觉规范摘要
（从 .design/deliverables/tokens.json 提取主色、字体、间距）

## 设计决策
- 选定方向：<direction> — <核心主张>
- 美学审查：<通过/跳过>，最终评分 <score>/50
- UX 审查：通过，共 <N> 轮
- 知识沉淀：<已入库 ref-id: XXX> 或 <跳过>

## 遗留问题
（从 UX 审查的 suggest_fix 列表中提取未解决项）

## 中间产物索引
- 方向简报: .design/direction-brief.md
- 情绪板: .design/moodboard.html
- 页面跳转图: .design/navigation-map.md
- 各页规格表: .design/deliverables/spec-*.md
```

2. **更新 `_manifest.json`**：
```json
"design": {
  "status": "completed",
  "output": "05-design.md",
  "completed_at": "<ISO8601时间>"
}
```

3. 告知用户：「Build context 交付完成，已写入 `.build/05-design.md` 并更新 manifest。」

<HARD-GATE>
Build context 模式下，交付前 MUST 验证 `.build/05-design.md` 存在，且包含「## 代码级规格表」章节，至少有 1 个页面级规格表（`### 页面名`）。如果缺失 → 重新执行组装，不可标记交付完成。
</HARD-GATE>
