---
tags: [搜索, WebSearch, web-search-plus, WebFetch, 信息源]
triggers: [需要搜索外部信息, 选择搜索工具, 查找文档]
related: []
source: CLAUDE.md#问题解决
---

# 搜索工具与策略

> 需要搜索时读取。

## 搜索工具选择优先级

**按场景区分：**
- **调研/竞品分析/多平台搜集**：`web-research` skill（首选，自动路由最佳引擎）> `web-search-plus` > `WebSearch`
- **快速查单个事实/文档**：`web-search-plus`（首选）> `WebSearch` > `WebFetch`（读取特定页面）
- **Subagent 中搜索**：必须用 `web-research` skill，直接用 WebSearch 容易失败或搜不到好内容

## 信息源优先级
官方文档 > GitHub Issues/Discussions > Stack Overflow > 博客文章

## 搜索技巧
- 搜索时注意加上版本号、错误信息关键字，提高命中率
- 找到可行方案后再动手，避免盲目试错浪费时间
