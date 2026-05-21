---
tags: [Scrapling, 爬虫, 反检测, 登录态, Patchright, Playwright, TLS指纹, search.py, 搜索体系]
triggers: [抓取网页失败时, WebFetch被拦截时, 需要登录态爬取时, Cloudflare保护时, 搜索调研时]
related: [search-strategy.md]
source: 2026-03-17~18 Scrapling 集成 + search.py 统一搜索引擎
---

# Scrapling + 搜索体系经验

## 架构总览

```
web-research (skill) — 触发器，解析需求→构建参数→派遣 subagent→汇总结果
    ↓
web-collector (agent) — 独立上下文执行层，自主规划+搜索+验证+回传
    ↓
search.py — 统一搜索引擎（16 adapter + --site 通用 + --comments 评论）
scrape.py — 定向抓取（反检测/登录态/Cloudflare）
```

## 环境
- 虚拟环境：`~/scrapling-env/`（Python 3.14 + Scrapling 0.4.2 全功能）
- search.py：`~/.claude/scripts/search.py`（搜索）
- scrape.py：`~/.claude/scripts/scrape.py`（抓取）
- Profile 目录：`~/.claude/browser-profiles/<domain>/`
- 已配置 profile：weibo.com、zhihu.com、xiaohongshu.com、taobao.com

## 关键踩坑

### Patchright headful 模式在 macOS 上不弹窗
- **现象**：`StealthySession(headless=False)` 运行成功但用户看不到浏览器窗口
- **根因**：Patchright 安装的 Chromium 二进制与 Playwright 的不同，GUI 渲染有问题
- **解决**：登录流程改用 Playwright 原生 `sync_playwright().chromium.launch_persistent_context()`，抓取仍用 Patchright StealthySession
- **profile 兼容性**：Playwright 和 Patchright 共享同一个 `user_data_dir`，格式互相兼容

### 微博登录 URL 选择
- ❌ `https://weibo.com/` → 跳转到 `passport.weibo.com/visitor/visitor`（游客验证页，无二维码）
- ✅ `https://passport.weibo.com/sso/signin?entry=miniblog&source=miniblog` → 标准登录页，有二维码

### SPA 虚拟列表渲染不完整
- **affected**：小红书 feed、掘金热榜、抖音热搜
- **原因**：这些平台的内容通过 JS 虚拟列表渲染，`network_idle` 判定时 DOM 还没完成渲染。内容不在初始 DOM 中
- **绕不过**：这不是反爬问题，是前端框架层面的限制。需要滚动触发或等更久

## 平台可达性实测汇总（2026-03-17）

| 平台 | HTTP 模式 | Stealth 无登录 | Stealth+登录态 |
|------|----------|--------------|---------------|
| Product Hunt | ❌ Cloudflare | ✅ 自动绕过 | N/A |
| 微博热搜 | ❌ 403 | ✅ 52条热搜 | ✅ 完整内容+搜索量 |
| 知乎热榜 | ❌ 超时 | ❌ 登录墙 | ✅ 完整热榜+热度+摘要 |
| 淘宝搜索 | ❌ 空 | ❌ 登录页 | ✅ 商品名+价格+销量 |
| 小红书 | ❌ 空 | ❌ 登录页 | ⚠️ 登录成功但feed虚拟列表不完整 |
| B站排行榜 | ❌ 空 | ✅ 完整排行榜 | N/A |
| Stack Overflow | ✅ 1.1s | N/A | N/A |
| CSDN | ✅ 4.8s | N/A | N/A |
| 掘金 | ❌ 451→空 | ⚠️ 只有JS | N/A |
| 抖音 | ❌ 超时 | ⚠️ 只有页脚 | N/A |

## auto-escalate 注意事项
- profile 检测不应限制在 stealth 模式——http 模式 auto-escalate 到 stealth 时也需要 profile
- `s.taobao.com`、`search.jd.com` 等搜索子域名要加入 STEALTH_DOMAINS 列表

## search.py 实测经验（2026-03-18）

### 平台搜索验证

| 平台 | 状态 | 方式 | 耗时 |
|------|------|------|------|
| weibo | ✅ | Scrapling stealth + DOM | 7s |
| xiaohongshu | ✅ | Playwright API 拦截 | 19s |
| zhihu | ✅ | Scrapling stealth + DOM | 8s |
| taobao | ✅ | Scrapling stealth + href 过滤 | 14s |
| bilibili | ✅ | Scrapling stealth + video 链接 | 7s |
| reddit | ✅ | curl JSON API | 1.3s |
| twitter | ✅ | xreach CLI（需 cookies 有效） | 3s |
| exa | ✅ | mcporter（文本格式解析，非 JSON） | 12s |
| csdn | ✅ | HTTP→stealth fallback | 59s |
| stackoverflow | ✅ | 验证码→Exa site: 降级 | 15s |
| producthunt | ✅ | Exa site: 降级（SPA 无 DOM） | 12s |
| coolapk/heimao/smzdm | ✅ | Exa site: 降级 | 7-11s |
| jina | ⚠️ | 需要 JINA_API_KEY | - |
| 中文 Top50 --site | 49/50 ✅ | Exa site: 通用搜索 | 5-14s |

### 关键踩坑

- **mcporter exa 输出是文本格式不是 JSON**：需要按 `Title:/URL:/Text:` 行解析
- **xreach 返回 JSON 的 items 字段**：不是直接列表，是 `data.items[]`
- **淘宝商品 DOM 类名是动态的**：不能用 CSS class 选择器，改用 `a[href*="item.taobao"]` 过滤 + 正则提取价格
- **B 站搜索结果视频链接无 class**：用 `a[href*="/video/"]` 过滤，跳过"稍后再看"文本
- **SO/PH/酷安/黑猫/SMZDM 的搜索页都是 SPA**：DOM 里没内容，统一降级 Exa `site:xxx.com`
- **CSDN HTTP 在你网络下超时**：加了 stealth fallback，59s 但能成功

### 评论获取

三层策略：
1. **API 拦截**（已知端点）：抖音 `comment/list`、B 站 `api.bilibili.com/x/v2/reply`
2. **DOM 选择器**（通用）：`[class*="comment-content"]` 等
3. **启发式文本**（兜底）：滚动后提取短文本，去重去噪

- 快手评论在 DOM 里（服务端渲染），不需要 API 拦截
- 知乎回答内容在 DOM 中（290 条文本），但评论需要点击"展开"
- 36 氪评论区不需要登录，但很多文章 0 评论

### --site 通用搜索

`search.py --site <domain> --query "xxx"` 通过 Exa `site:` 语法搜索任意网站，中文 Top 50 信息网站测试 49/50 通过（天涯已关站）。不需要为每个网站写 adapter。
