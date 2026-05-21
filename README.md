# Claude Build Pipeline

一套基于 Claude Code 的 **9 阶段产品构建流水线**，从需求明确到部署验收全覆盖。

## 它能做什么

在 Claude Code 中输入 `/build 我要做一个记账 App`，系统自动引导你完成：

```
Stage 1: 需求明确 (specify)     ← 与你对齐需求规格
Stage 2: 调研 (research)        ← 搜索竞品、用户反馈、技术方案
Stage 3: 价值判断 (value)       ← 评估 ROI 和优先级
Stage 4: 产品方案 (plan)        ← 生成完整产品文档
Stage 5: 交互设计 (design)      ← 生成 UI 设计稿
Stage 6: 代码计划 (code-plan)   ← 拆解任务、分配依赖
Stage 7: 代码实施 (implement)   ← 多 agent 并行写代码
Stage 8: 部署 (deploy)          ← 自动检测技术栈并配置部署
Stage 9: 验收 (review)          ← 对照需求逐项检查
```

每个阶段可跳过，支持回环迭代，复杂度自适应。

## 快速开始

```bash
git clone <this-repo> claude-build-pipeline
cd claude-build-pipeline
bash install.sh
```

然后在 Claude Code 中：
```
/build 我要做一个 XX 功能
```

## 安装选项

```bash
bash install.sh              # 完整安装
bash install.sh --no-design  # 跳过设计阶段（无 Pencil MCP 时）
bash install.sh --no-feishu  # 跳过飞书相关组件
bash install.sh --upgrade    # 升级（覆盖已有文件）
```

## 卸载

```bash
bash uninstall.sh
```

## 前置依赖

| 依赖 | 必需？ | 用途 |
|------|--------|------|
| [Claude Code](https://claude.ai/code) | ✅ 必需 | 运行环境 |
| Python 3.10+ | ✅ 必需 | 前置检查脚本 |
| [Pencil MCP](https://pencil.li) | 设计阶段必需 | 生成 UI 设计稿 |
| Playwright MCP | 可选 | 浏览器自动化验证 |

## 架构

详见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

核心设计：
- **Manifest 驱动**：`_manifest.json` 是流程状态唯一源
- **文件契约**：阶段间通过产出文件传递数据，不依赖对话上下文
- **复杂度自适应**：small/medium/large 三档，影响每阶段执行深度
- **多 agent 协作**：research、design、implement 阶段可并行派发多个 subagent

## 定制

详见 [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md)

## License

MIT
