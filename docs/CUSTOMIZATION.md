# 定制指南

## 跳过不需要的阶段

在 `/build` 启动时，系统会询问复杂度和终点阶段。你可以：
- 设置 `stop_after: "implement"` 跳过部署和验收
- 在流程中对可选阶段选择"跳过"

## 添加经验记录

在 `~/.claude/memory/details/` 对应目录下添加 markdown 文件：

```
implement/my-framework-tips.md  — 你常用框架的踩坑记录
research/my-search-sources.md   — 你偏好的搜索源
```

格式参考 `implement/INDEX.md`。

## 自定义 Agent

修改 `~/.claude/agents/` 下的 agent 定义文件。例如：
- 修改 `plan-reviewer.md` 调整产品方案审查标准
- 修改 `implement-reviewer.md` 调整代码审查规则

## 添加新的阶段

如需在流水线中插入自定义阶段：
1. 创建 `~/.claude/commands/build.your-stage.md`
2. 在 `build.md` 编排器中添加阶段定义
3. 在 `check-build-prerequisites.sh` 中添加依赖关系

## 修改 Settings

安装时合并到 `settings.json` 的条目：
- `permissions.allow`：build 脚本的执行权限
- `permissions.deny`：Playwright 浏览器隔离（强制走 subagent）
- `hooks`：Pencil/Playwright guard hooks

如需调整，直接编辑 `~/.claude/settings.json`。
