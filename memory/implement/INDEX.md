# Implement 阶段经验索引

> 代码实施前必读。宽松匹配原则：有 20% 关联就读取对应文件。读取成本低，踩坑成本高。

## 经验文件（方法论 + 编码坑点）

| 文件 | 关键词 | 一句话 |
|------|--------|--------|
| `~/.claude/memory/details/implement/feishu-api.md` | 飞书 lark 文档写入 Sheet Bitable 副本模式 分段 update-doc create-doc block_id update_all 图片 replace_all emoji warning shield | 飞书文档操作方法论 + API 高频错误 |
| `~/.claude/memory/details/implement/process-mgmt.md` | 进程 守护 daemon PID 单实例 后台 脚本常驻 | 守护进程单实例互斥 + PID 锁文件 |
| `~/.claude/memory/details/implement/macos-overlay.md` | macOS 全屏 overlay NSEvent NSPanel SPM Swift 覆盖层 AppKit NSWindow Bundle 防锁死 | macOS 全屏覆盖防锁死方法论 + 编码坑点 |
| `~/.claude/memory/details/implement/github-actions.md` | GitHub Actions CI CD release workflow 多架构 Swift iOS Xcode archive signing DerivedData | CI/CD 方法论 + Xcode/iOS CI 构建问题 |
| `~/.claude/memory/details/implement/subagent-quality.md` | subagent 验证 curl ls 真实数据 假设 TabBar嵌套 UI结构 布局审查 | 必须用真实数据验证+审查UI嵌套结构，不能猜结构 |
| `~/.claude/memory/details/implement/change-impact-tracing.md` | 改字段 修改 grep 引用 影响矩阵 API 前端 校验 | 改字段前画影响矩阵：model→API→前端 |
| `~/.claude/memory/details/implement/ios-swiftdata.md` | SwiftData SwiftUI @Query ModelContainer @Model Predicate 枚举 白屏 onAppear | SwiftData 常见陷阱 |
| `~/.claude/memory/details/implement/android-compose.md` | Android Jetpack Compose Kotlin Gradle imePadding 键盘 输入框 | Android/Compose 编码坑点 |
| `~/.claude/memory/details/implement/ai-api.md` | AI LLM mify proxy ppio model claude anthropic 静默失败 fallback 默认值 情绪分析 JSON双引号 超时 中文引号 | AI/LLM API 接入坑点：proxy model 命名、静默失败排查、三步验证、JSON引号修复、超时设置 |
| `~/.claude/memory/details/implement/flutter-layout.md` | Flutter 布局 Row stretch IntrinsicHeight ListView 不显示 静默不渲染 空白 竖条 | Flutter 布局坑点：Row+stretch 需 IntrinsicHeight，ListView 静默不渲染排查 |
| `~/.claude/memory/details/implement/python-scraping.md` | Python Scrapling 爬虫 反检测 Patchright SPA 虚拟列表 淘宝 微博 小红书 exa xreach B站 | Python 爬虫编码坑点 |
| `~/.claude/memory/details/implement/react-native.md` | React Native RN Expo React Navigation useEffect 依赖数组 BottomTabs TabBar 图标 tabBarIcon header headerShown 双返回按钮 | RN 编码坑点：useEffect 依赖、TabBar 图标显式配置、header 双层问题 |
| `~/.claude/memory/details/implement/tauri-desktop.md` | Tauri 2 桌面应用 Rust macOS identifier 连字符 icon 编译期 generate_context workspace members panic NSApplication did_finish_launching bundle Cocoa | Tauri 2 macOS 骨架坑点：identifier 禁连字符、icon.png 编译期硬依赖、workspace 成员强校验 |
| `~/.claude/memory/details/build-and-packaging/artifact-naming.md` | 构建产物 打包 build 版本号 命名 分发 artifact | 打包后必须拷贝到项目根+版本号命名 |
