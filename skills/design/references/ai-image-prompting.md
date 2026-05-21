---
tags: [AI生图, prompt, FLUX, Bing, 赛璐璐, 角色一致性, 插画, 风格标签]
triggers: [AI生成图片, 写图片prompt, 插画生成, 角色一致性, 生图平台选择]
related: [pencil-tips.md]
source: 末日抉择项目 2026-03-20
---

# AI 生图 Prompt 方法论

## 核心原则：简洁 > 堆砌

AI 生图的 prompt **不是越专业越好**。风格标签越多，冲突概率越大。

**踩坑实证**：
- v1（简洁描述 + `digital illustration`）→ 效果好
- v2（堆砌 `matte painting, volumetric lighting, Caravaggio-style chiaroscuro, contre-jour`）→ 风格混乱，反而不如 v1
- v3（回归简洁 + `cel-shaded anime illustration`）→ 效果稳定

**规则**：风格标签控制在 3-5 个核心词，不要超过 7 个。

## 平台约束必须前置确认

写 prompt 之前先确认：
1. **字符限制**：Bing 约 480 字符，Midjourney 约 6000 字符，FLUX 无明确限制
2. **支持的参数**：negative prompt、aspect ratio、seed、CFG scale
3. **风格偏好**：有些模型对某些标签敏感度不同

**教训**：写了 800 字符的 prompt 才发现 Bing 限 480，导致多轮返工。

## 角色一致性方案（无 LoRA 条件下）

### 角色锚定标签法
为每个反复出现的角色定义**固定外貌描述词**——不增不减，所有涉及该角色的 prompt 完全复用。

```
示例：
主角锚定 = "a haggard woman with messy low ponytail in torn dirt-stained blue nurse scrubs, bandaged hands"
```

### 执行顺序
1. **先生封面/单人图**，确认角色形象满意
2. 后续 prompt 复用完全相同的锚定标签
3. 如平台支持参考图（img2img / IP-Adapter），用封面做参考
4. 角色偏差时换 seed 重新生成，**不改锚定标签**

### 状态匹配
角色的状态要匹配故事进展。末日生存 72 小时的角色不应该干干净净——`haggard, torn, dirt-stained, bandaged, scarred` 这些词必须包含。

## 赛璐璐风格的关键标签

```
正确：cel-shaded illustration, anime cel art style, clean bold outlines, flat color with sharp shadow edges
错误：anime, cartoon（太泛）; matte painting, oil painting（会拉向写实）; soft shading, gradient shadows（与赛璐璐平涂矛盾）
```

负面提示词也要排斥赛璐璐的对立面：
```
negative: photorealistic, 3D render, soft shading, gradient shadows, painterly, oil painting
```

## 批量生图的效率策略

- 统一风格后缀写成模板，逐条 prompt 只写场景差异部分
- 用 Python 脚本验证字符数（批量替换后容易超限）
- 色温随叙事递进：如末日三幕（冷蓝灰→压抑灰绿→冷白蓝+破晓金）
