---
tags: [Pencil, 设计, 文字换行, 布局, snapshot_layout, pen文件, fill, gradient, 属性限制, emoji, 真机渲染, 移动端]
triggers: [使用Pencil设计, 文字排版问题, pen文件操作, Pencil颜色, Pencil渐变, 移动端设计, emoji布局, 卡片设计]
related: []
source: MEMORY.md#经验教训索引
---

# Pencil 设计工具经验

## 文字换行（关键）

Pencil 文本节点 **不支持自动换行**。`width`、`fill_container` 对文字回流无效。

### 正确做法：手动 `\n` + snapshot_layout 迭代

1. 先写一版 `\n` 断行（粗略估算）
2. `snapshot_layout` 检查每个文字节点的实际 `width` vs 容器 `width`
3. 根据差距微调断行位置（溢出 = partially clipped 警告）

### 错误做法（都试过，无效）
- `width: "fill_container"` → 不影响文字回流
- `width: 460`（固定像素）→ 同样不影响
- 理论计算（容器宽 ÷ 字号）→ 偏差大，中英混排/标点宽度不一

### 宽度估算参考（仅作初始猜测）
- fontSize 14 中文：实际约 15px/字（含间距）
- fontSize 13 中文：实际约 14px/字
- 英文/数字/空格约占中文字宽的 50-70%

## 布局注意事项

- 大容器用 `layout: "vertical"` 避免水平溢出导致 "fully clipped"
- 设计稿中多个状态并排时，主 frame 高度要足够容纳所有子 panel
- `snapshot_layout` 的 `problems` 字段是检测溢出的关键信号

## batch_design 注意事项
- 每次最多 25 个操作，大设计分多次调用
- 不要手写 id，系统自动生成
- Copy(C) 后不能 Update(U) 子节点（ID 会变），用 Copy 的 descendants 参数
- 每个 I/C/R 操作必须有绑定名（foo=I(...)）
- `document` 是预定义绑定指向根节点，仅用于创建顶层 screen
- `placeholder: true` 标记容器 frame，方便后续插入子内容

## 组件使用要点
- 用设计变量引用颜色，不要硬编码（通过 get_variables / set_variables 管理）
- .pen 文件没有自动保存，完成后提醒用户 Cmd+S
- 组件的 slot 属性标识插槽，往里插入子内容用路径：instanceId/slotId
- 隐藏不需要的 slot：U(instance+"/slotId", { enabled: false })
- 没有独立的 image 节点类型，图片必须填充到 frame/rectangle 上（用 G 操作）
- .pen 文件内容加密，不能用 Read/Grep 工具读取，必须用 Pencil MCP 工具

## 属性限制（关键）

### `fill` 不支持渐变
- Pencil 的 `fill` 属性**只接受纯色**（如 `#FF6B35`），不支持 CSS `linear-gradient()` 语法
- 写入渐变值不会报错，但**静默失败**：节点渲染为无背景/透明
- 需要渐变效果时，只能用纯色近似，或拆分多个色块模拟

### `textColor` 无效
- 文本节点的颜色属性是 `fill`，不是 `textColor`
- 使用 `textColor` 会报错：`Property 'textColor' is invalid on text nodes. Use 'fill' instead.`
- 所有文本颜色统一用 `fill: "#颜色值"` 设置

### badge/pill 自适应宽度
- 徽章类元素用 `width: "fit_content(0)"` 实现文字自适应宽度
- 不要用固定宽度，否则短文字留空、长文字溢出

### `verticalAlign` / `horizontalAlign` 无效
- 这两个属性名均为无效属性，写入会报 "unexpected property" 错误
- 统一使用 `alignItems`（交叉轴对齐）和 `justifyContent`（主轴分布/对齐）
- 规则：`alignItems:"center"` 控制交叉轴居中，`justifyContent:"center"` 控制主轴居中，无论 layout 方向

### FAB 绝对定位（移动端）
- 在 `layout:"vertical"` 的 screen frame 内，FAB 必须设置 `layoutPosition:"absolute"` + 显式 `x`/`y`
- 漏掉 `layoutPosition:"absolute"` 后，FAB 被当作 flex 子元素，宽度 56px 左对齐流入布局末尾
- **坐标公式**（含 TabBar 的页面）：
  - `x = screenWidth - fabSize - margin`（右边距，推荐 16px）
  - `y = screenHeight - tabBarHeight - margin - fabSize`（TabBar 上方留 margin）
  - 示例：375 宽、812 高、62px TabBar、56px FAB、16px margin → `x=303, y=678`
  - ⚠️ `y = screenHeight - tabBarHeight - fabSize`（无 margin）会让 FAB 零间距贴着 TabBar

## 构建方法论

### 最小可验证单元优先
复杂设计（如多行表格）不要一次性构建全部行：
1. 先构建 header + 1 行数据（最小可验证单元）
2. `get_screenshot` 验证布局、颜色、间距是否正确
3. 确认无误后再批量复制/构建剩余行

### 截图审计必须诚实
- 看到 `get_screenshot` 返回后，逐区域检查（header → body → footer）
- **禁止**在颜色明显不对时声称"渐变效果正常"——这是自欺欺人
- 发现异常立即排查 `fill` 值，不要在错误基础上继续构建

## 设计稿 vs 真机渲染差异（关键）

Pencil/设计工具中"看起来没问题" ≠ 真机没问题。

**踩坑案例**：卡片用 100dp 固定高度 + 纵向堆叠（emoji + 名称 + 件数），Pencil 中 emoji 渲染为小方块放得下，安卓系统 emoji 是大彩图导致件数被裁切。

**规则**：
- 移动端设计中 emoji/图标的尺寸必须按真机渲染估算，不信任设计工具中的显示
- 固定高度容器 + 可变尺寸内容 = 必须留 20%+ 余量，或改用 fit_content
- 涉及 emoji 的布局优先用横向排列（Row），避免纵向空间不够
