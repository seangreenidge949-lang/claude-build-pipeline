---
description: "Build Pipeline Stage 8: 部署交付。生成 README、启动脚本和部署指南。"
---

# Stage 8: 部署交付 (Deploy)

## Stage Contract
- **requires**: `.build/07-implement-log.md`
- **optional**: `.build/06-code-plan.md`（技术栈信息）
- **produces**: `.build/08-deploy.md`
- **precondition**: implement 阶段已 completed

## 前置检查

运行前置检查脚本：
```bash
~/.claude/scripts/check-build-prerequisites.sh deploy --json
```

解析 JSON 输出。如果脚本返回非零退出码（implement 未完成），停止执行并告知用户。

## 执行流程

### Step 1: 检测技术栈和部署目标

从 `06-code-plan.md` 或 `07-implement-log.md` 中读取技术栈，自动判断部署方案：

| 技术栈 | 推荐部署方式 | 额外产出 |
|--------|------------|---------|
| Next.js/React SPA | Vercel / Netlify | vercel.json 或 netlify.toml |
| Node.js 后端 | Docker / Railway | Dockerfile + docker-compose.yml |
| Python 后端 | Docker / Fly.io | Dockerfile + requirements.txt 确认 |
| iOS App | Xcode Archive | 签名打包步骤 + 证书配置说明 |
| Android App | Gradle Build | 签名打包步骤 + keystore 说明 |
| CLI 工具（npm） | npm publish | package.json bin 字段确认 + 发布步骤 |
| CLI 工具（Python） | pip / brew | setup.py/pyproject.toml 确认 + 发布步骤 |
| 静态站点 | GitHub Pages / Vercel | 部署配置文件 |
| macOS 桌面 | DMG / App Store | 打包 + 公证步骤 |
| Swift Package | Swift Package Registry | Package.swift 确认 + 发布步骤 |

向用户展示检测结果并确认。

### Step 2: 生成 README.md

在项目根目录生成（或更新）README.md，包含：

- **项目名 + 一句话描述**（从 01-specify.md 提取）
- **功能特性**（从 04-plan.md 提取核心功能列表）
- **快速开始**：环境要求 + 安装命令 + 运行命令
- **项目结构**（从 06-code-plan.md 提取关键目录说明）
- **技术栈**（语言、框架、版本）
- **开发指南**：本地开发 + 测试命令
- **部署**：简要步骤或链接到 .build/08-deploy.md
- **License**：默认 MIT

### Step 3: 生成启动脚本（如适用）

根据技术栈生成便捷脚本：

- **Web 项目**：`start.sh`（生产启动）和 `dev.sh`（开发模式）
- **CLI 项目**：确保 `npm link` 或 `pip install -e .` 可用
- **桌面应用**：打包脚本（如 `build.sh`）
- **移动应用**：不生成脚本，在部署指南中说明

### Step 4: 生成部署指南

写入 `.build/08-deploy.md`：

```markdown
# <项目名> — 部署指南

## 部署方式
<推荐的部署方式及选择理由>

## 前置条件
- <需要的账号（如 Vercel 账号、Apple Developer 账号）>
- <需要的密钥/证书>
- <需要的环境变量>

## 部署步骤

### 方式一：<推荐方式>
1. <具体步骤>
2. <具体步骤>
3. <具体步骤>

### 方式二：<备选方式>（可选）
1. <具体步骤>

## 环境变量
| 变量名 | 用途 | 必填 | 默认值 | 示例 |
|--------|------|------|--------|------|
| <变量> | <用途> | <是/否> | <默认值> | <示例值> |

## 构建产物
- <构建命令>
- <产出路径>
- <产物大小预估>

## 常见问题
- Q: <常见问题 1>
  A: <解答>

## 监控与运维（如适用）
- 健康检查端点：<URL>
- 日志查看方式：<命令/链接>
- 重启方式：<命令>
```

### Step 5: 验证

- 确认 README.md 中的安装/运行命令可直接执行（实际运行验证）
- 确认部署指南中列出的环境变量与代码中使用的一致（grep 验证）
- 确认生成的启动脚本可执行（`chmod +x` 已设置）

## 交接

本阶段完成后：
1. 将部署指南写入 `.build/08-deploy.md`
2. 将 README.md 写入项目根目录
3. 更新 `_manifest.json`：`deploy.status = "completed"`，`deploy.output = "08-deploy.md"`，`deploy.completed_at = "<时间>"`
4. 向用户展示部署摘要（推荐方式 + README 已生成）
5. 下一步建议：进入 **验收检查阶段**
6. 交回编排器控制权
