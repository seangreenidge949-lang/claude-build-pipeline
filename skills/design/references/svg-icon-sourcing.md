---
name: SVG 图标获取方法论
description: 需要 SVG 图标时优先使用开源图标库（Iconify/SVGRepo），不要手绘路径
type: feedback
---

不要手绘 SVG 路径。先搜开源库，找不到再考虑手绘。

**Why:** 手绘 SVG 路径效果差（比例失调、细节不足）且每次都要重新推导。开源库有专业设计师打磨的成熟图标，一条路径搞定。本次教训：用手绘龙虾路径被用户否定两次，最终换成 Fluent Emoji 的单路径方案一次通过。

**How to apply:**

## 获取优先级

1. **Iconify API**（首选，MIT/Apache 许可）
   - 搜索入口：`https://iconify.design/` 或 `https://icon-sets.iconify.design/`
   - 直接获取 SVG：`https://api.iconify.design/{library}/{icon}.svg`
   - 获取带颜色：`https://api.iconify.design/{library}/{icon}.svg?color=white`
   - 例：`https://api.iconify.design/fluent-emoji-high-contrast/lobster.svg`

2. **SVGRepo**（第二选）
   - 搜索：`{关键词} icon site:svgrepo.com`
   - 可直接下载 SVG 文件，有 `fill="currentColor"` 版本

3. **手绘**（最后手段，仅限极其简单的几何图形）

## 推荐图标库

| 需求 | 推荐库 | 特点 |
|------|--------|------|
| 动物/食物/物体 emoji | `fluent-emoji-high-contrast` | Microsoft 出品，高对比度单色，MIT |
| 通用 UI 图标 | `material-symbols` | Google，海量，MIT |
| 线条风格 | `phosphor` | 多种粗细变体，MIT |
| 品牌/Logo | `simple-icons` | 仅品牌 Logo，全部 MIT |
| 彩色 emoji | `twemoji` | Twitter emoji，CC BY 4.0 |

## 在 React/Remotion 中的封装模式

```tsx
// 1. 提取 viewBox 和 path d="" 数据
// 2. 封装成接受 size + color 的组件
// 3. 用 fill={color} 控制颜色（不用 stroke）

export const MyIcon: React.FC<{ size: number; color?: string }> = ({ size, color = "#FFFFFF" }) => (
  <svg width={size} height={size} viewBox="0 0 32 32" fill="none">
    <path fill={color} d="M..." />
  </svg>
);
```

**关键注意**：
- `fill="currentColor"` 的图标可以直接用，通过父元素 `color` 属性控制
- `stroke` 类图标需要把 `fill` 改为 `stroke={color}` + `fill="none"`
- 多色图标在单色场景下需要把所有子色统一替换

## 本项目记录

- ClawDroid 龙虾图标：`fluent-emoji-high-contrast:lobster`
  - viewBox: `0 0 32 32`，单 path，MIT 许可
  - 封装在：`src/components/ClawIcon.tsx`
  - 用于：IntroScene（size=100）、ChatScene（size=22/26）、OutroScene（size=44）
