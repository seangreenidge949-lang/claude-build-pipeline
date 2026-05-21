# 前置依赖

## 必需

### Claude Code CLI
- 版本要求：最新版
- 安装：https://claude.ai/code
- 验证：`claude --version`

### Python 3.10+
- 用于 `check-build-prerequisites.sh` 解析 manifest JSON
- macOS 自带或 `brew install python3`
- 验证：`python3 --version`

## 按阶段可选

### Pencil MCP Server（design 阶段必需）
- 用途：生成和编辑 .pen 设计稿
- 安装：参考 https://pencil.li 文档
- 如果不安装：安装时使用 `--no-design` 跳过设计相关组件，design 阶段将不可用

### Playwright MCP Server（research 阶段可选）
- 用途：浏览器自动化操作（截图验证、页面交互）
- 安装：在 Claude Code MCP 配置中添加 Playwright server
- 如果不安装：research 阶段的浏览器验证功能不可用，但文本搜索正常

### Scrapling Python 环境（research 阶段可选）
- 用途：中文互联网多平台搜索（微博、知乎、小红书等 16+ 平台）
- 安装步骤：
  ```bash
  python3 -m venv ~/scrapling-env
  source ~/scrapling-env/bin/activate
  pip install scrapling
  ```
- 如果不安装：research 阶段仅使用 WebSearch（英文为主），中文平台搜索不可用

## 安装后检查

运行以下命令验证环境：
```bash
python3 --version
claude --version 2>/dev/null || echo "Claude Code: 请通过应用内验证"
```
