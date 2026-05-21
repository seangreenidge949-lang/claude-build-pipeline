# 架构说明

## 9 阶段流水线

```
specify → research → value → plan → design → code-plan → implement → deploy → review
   │                                  │                       │
   └──────── HARD-GATE ──────────────┘    HARD-GATE ────────┘
```

### HARD-GATE（不可绕过的门禁）
1. **specify → 后续阶段**：需求规格必须经用户确认
2. **code-plan → implement**：代码计划必须经用户确认

### 可跳过阶段
除 specify 和 implement 外，其余 7 个阶段均可根据项目复杂度跳过。

## 状态管理

### Manifest (`_manifest.json`)
每个项目在 `.build/` 目录下有一个 manifest，是流程状态的唯一真实来源：

```json
{
  "feature": "my-app",
  "complexity": "medium",
  "stages": {
    "specify": { "status": "completed", "output": "01-specify.md" },
    "research": { "status": "pending" }
  }
}
```

### 文件契约
阶段间通过产出文件传递数据：
- `01-specify.md` → `02-research.md` → ... → `09-review.md`
- 下游阶段读取上游产出文件获取输入，不依赖对话上下文

## 复杂度自适应

| 维度 | small | medium | large |
|------|-------|--------|-------|
| 阶段推荐 | 跳过 research/value | 全执行 | 全执行+深度 review |
| design 模式 | fast（1 方向） | explore（3 方向） | explore（3 方向） |
| implement 模式 | 手动 | 可选 subagent | subagent 并行 |

## 多 Agent 协作

### Research 阶段
- `web-collector`：互联网搜索
- `feishu-researcher`：飞书内部文档（可选）
- `info-analyst`：信息整合分析

### Design 阶段（委托给 design skill）
- `design-researcher`：设计案例研究
- `design-designer`：概念设计生成
- `design-ux-critic`：交互审查
- `design-aesthetic-critic`：美学审查
- `ui-design-master`：代码级规格提取

### Implement 阶段
- 手动模式：主 agent 逐 task 执行
- subagent 模式：每 task 派一个 subagent 并行
- `implement-reviewer`：Phase 级代码审查

## 目录结构

```
项目根/
├── .build/
│   ├── _manifest.json      # 状态唯一源
│   ├── 01-specify.md       # 需求规格
│   ├── 02-research.md      # 调研结果
│   ├── 03-value.md         # 价值判断
│   ├── 04-plan.md          # 产品方案
│   ├── 05-design.md        # 设计规格
│   ├── 06-code-plan.md     # 代码计划
│   ├── 07-implement-log.md # 实施记录
│   ├── 08-deploy.md        # 部署配置
│   └── 09-review.md        # 验收报告
├── .design/                 # Pencil 设计文件
│   └── *.pen
└── src/                     # 实际代码
```
