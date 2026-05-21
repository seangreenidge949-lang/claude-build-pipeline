# iOS Human Interface Guidelines 关键规范摘要

## 布局
- 安全区域（Safe Area）：必须尊重，内容不能进入 Home Indicator 区域
- 标准间距：8pt 网格系统
- 屏幕尺寸参考：iPhone 15 Pro = 393×852pt

## 导航
- 导航栏高度：44pt（不含状态栏）
- Tab Bar 高度：49pt（不含 Home Indicator）
- 最多 5 个 Tab

## 触控
- 最小触控区域：44×44pt
- 推荐主操作按钮高度：50pt

## 字体
- 系统字体：SF Pro（Display/Text/Rounded）
- 最小正文字号：17pt（Regular）
- 动态字体：支持 Dynamic Type

## 色彩
- 系统色彩：使用语义颜色（systemBackground, label, secondaryLabel）
- 深色模式：必须同时支持 Light/Dark

## 组件规范
- Modal：圆角 10pt，有 drag handle
- Sheet：从底部滑出，高度可变
- Alert：系统样式，不自定义
