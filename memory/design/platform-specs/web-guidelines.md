# Web Interface Guidelines 关键规范摘要

## 布局
- 最大内容宽度：1280px（建议），1440px（宽屏）
- 标准栅格：12列，间距 24px
- 移动端断点：768px / 1024px / 1280px

## 可访问性
- 色对比度：正文 ≥ 4.5:1（WCAG AA），大字 ≥ 3:1
- 焦点环：可见，不得用 outline:none 移除
- Alt 文字：所有有意义的图片必须有
- 键盘导航：Tab 顺序与视觉顺序一致

## 触控/点击
- 最小点击区域：44×44px（移动端）
- cursor: pointer 应用于所有可点击元素

## 字体
- 最小正文字号：16px（移动端）
- 行高：1.5-1.75（正文）
- 每行字符数：65-75（最佳可读性）

## 性能
- 图片：WebP 格式，srcset 响应式，lazy loading
- 预留加载空间，避免 CLS（内容偏移）

## 动效
- 微交互时长：150-300ms
- 使用 transform/opacity，不用 width/height 做动画
- 尊重 prefers-reduced-motion
