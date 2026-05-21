---
description: "Build Pipeline Stage 5: 交互/设计稿。调用 design skill 完整流程，基于产品方案创建高保真设计稿。"
---

# Stage 5: 交互/设计稿 (Design)

## Stage Contract
- **requires**: `.build/01-specify.md`, `.build/04-plan.md`
- **optional**: —
- **produces**: `.build/05-design.md`
- **precondition**: specify 和 plan 阶段已 completed
- **side-effects**: `.design/`（设计工作区），`~/projects/美学参考/`（可选知识沉淀）

## 前置检查

运行前置检查脚本：
```bash
~/.claude/scripts/check-build-prerequisites.sh design --json
```

解析 JSON 输出。如果脚本返回非零退出码（specify 或 plan 未完成），停止执行并告知用户。

## Mode 决策

读取 `_manifest.json` 的 `complexity` 字段，按以下规则确定模式：

| complexity 值 | design skill 模式 |
|-------------|----------------|
| `small`     | `--fast`        |
| `medium`    | `--explore`     |
| `large`     | `--explore`     |
| 未定义 / 其他 | 询问用户选择     |

**当 complexity 未定义时**，向用户说明：

「当前项目未设置复杂度，请选择设计模式：
- **explore**（推荐）：3 个并行概念方向 + 深度美学审查 + 记忆库更新，适合有设计质量要求的项目
- **fast**：1 个方向 + 1 轮审查，适合快速原型验证」

## 执行设计

确定 mode 后，调用 design skill：

```
/design --{mode} --build-context
```

说明：
- `--{mode}` 替换为 `--explore` 或 `--fast`
- `--build-context` 告知 design skill 当前在 build 流水线中，design skill 将在完成时自动写入 `.build/05-design.md` 并更新 `_manifest.json`
- design skill 的 Step 1.0 会自动检测并读取 `.build/04-plan.md`，无需额外传递需求信息

design skill 将执行完整流程（需求提取 → 研究 → 概念生成 → 审查 → 完整稿 → 规格表 → 知识沉淀），并在最终交付时自动完成 build context 交付。

## 完整性验证（HARD-GATE）

design skill 完成后，验证：

<HARD-GATE>
MUST 验证 `.build/05-design.md` 存在，且包含「## 代码级规格表」章节，至少有 1 个页面级规格表（`### 页面名`）。
如果缺失 → 告知用户 design skill 未完成 build context 交付，建议重新运行或检查 `.design/deliverables/code-spec.md`。
没有规格表 = implement 只能凭感觉猜数值 = 还原度必然差。
</HARD-GATE>

## 交接

本阶段完成后：
1. `_manifest.json` 已由 design skill 更新（`design.status = "completed"`）
2. 向用户展示设计成果摘要（含「代码级规格表已生成 X 个页面」）
3. 下一步建议：进入**代码计划阶段**，规划技术实现
4. 交回编排器控制权
