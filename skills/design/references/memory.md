# Design Skill — Memory Integration

## 文件清单

| 文件 | 位置 | 用途 | 读取时机 | 写入时机 |
|------|------|------|---------|---------|
| `aesthetic-learnings.md` | `references/` | 历史审查失败模式 + 有效定制决策 | 所有 designer 调用前（约束注入） | Step 7.5 设计完成后 |
| `design-vs-doc.md` | `references/` | 设计稿与产品文档的关系铁律 | Step 5.pre | 手动维护 |
| `ai-image-prompting.md` | `references/` | AI 生图 prompt 经验 | Step 5.pre（如涉及生图） | 手动维护 |
| `svg-icon-sourcing.md` | `references/` | SVG 图标获取方法论 | Step 5.pre（如涉及图标） | 手动维护 |
| `pencil-tips.md` | `~/.claude/memory/details/design/` | Pencil 工具踩坑经验（共享） | Step 5.pre | 手动维护 |

> `references/` = `~/.claude/skills/design/references/`

---

## Designer 约束注入规范

每次派发 design-designer 时，prompt 中 MUST 包含以下指令块：

```
【必读约束文件 — 文件存在时必须读取，不存在则跳过】
- ~/.claude/skills/design/references/aesthetic-learnings.md
  → 历史审查积累的失败模式（AI 陷阱命中记录）与有效定制决策
  → 设计时：主动规避失败模式；参考已验证的成功决策
```

> 这是跨会话的设计记忆注入点。每次成功设计后，Step 7.5 会自动更新此文件，形成持续学习飞轮。

---

## Step 5.pre 读取规范

Step 5 开始前，MUST 按顺序读取：

1. `~/.claude/skills/design/references/design-vs-doc.md` — 设计稿与产品文档的关系铁律
2. `~/.claude/memory/details/design/pencil-tips.md` — Pencil 工具经验（共享文件，保留原路径）
3. `~/.claude/skills/design/references/aesthetic-learnings.md`（如存在）— 历史审查失败模式与有效定制决策
4. 其他 `~/.claude/skills/design/references/` 下的文件（如有）

---

## 审美判断沉淀格式（Step 7.5）

完成设计后，从 `.design/aesthetic-round-*.json` 提取内容，**追加**写入 `~/.claude/skills/design/references/aesthetic-learnings.md`（不覆盖历史）：

```markdown
## {产品类型} — {日期} — 方向{X}（得分 {N}/50）

### 本次命中的 AI 陷阱
- {陷阱名}：{具体表现} → {修复方式}

### 本次 must_fix 模式
- {维度}：{问题描述} → {有效修复方式}

### 成功的定制决策（通过审查的亮点）
- {设计决策}：{为什么有效}
```

写入后，下次设计时所有 designer 调用将通过「Designer 约束注入规范」自动读取此文件。
