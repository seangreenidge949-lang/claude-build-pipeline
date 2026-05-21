#!/usr/bin/env bash
# sync-from-local.sh — 从 ~/.claude/ 同步最新 build 文件到本 repo，并做脱敏
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
USERNAME="$(whoami)"
HOME_PATH="$HOME"

echo "📦 同步 build pipeline 到 repo: $REPO_DIR"
echo "   来源: $CLAUDE_DIR"
echo ""

# --- 1. Commands ---
echo "→ commands/"
cp "$CLAUDE_DIR/commands/build.md" "$REPO_DIR/commands/"
cp "$CLAUDE_DIR/commands/build.specify.md" "$REPO_DIR/commands/"
cp "$CLAUDE_DIR/commands/build.research.md" "$REPO_DIR/commands/"
cp "$CLAUDE_DIR/commands/build.value.md" "$REPO_DIR/commands/"
cp "$CLAUDE_DIR/commands/build.plan.md" "$REPO_DIR/commands/"
cp "$CLAUDE_DIR/commands/build.design.md" "$REPO_DIR/commands/"
cp "$CLAUDE_DIR/commands/build.code-plan.md" "$REPO_DIR/commands/"
cp "$CLAUDE_DIR/commands/build.implement.md" "$REPO_DIR/commands/"
cp "$CLAUDE_DIR/commands/build.deploy.md" "$REPO_DIR/commands/"
cp "$CLAUDE_DIR/commands/build.review.md" "$REPO_DIR/commands/"

# --- 2. Agents ---
echo "→ agents/core/"
for f in web-collector info-analyst plan-reviewer implement-reviewer product-doc-reviewer solution-critic strategic-planner; do
    [ -f "$CLAUDE_DIR/agents/$f.md" ] && cp "$CLAUDE_DIR/agents/$f.md" "$REPO_DIR/agents/core/"
done

echo "→ agents/design/"
for f in design-aesthetic-critic design-designer design-librarian design-researcher design-ux-critic ui-design-master; do
    [ -f "$CLAUDE_DIR/agents/$f.md" ] && cp "$CLAUDE_DIR/agents/$f.md" "$REPO_DIR/agents/design/"
done

echo "→ agents/browser/"
[ -f "$CLAUDE_DIR/agents/browser-executor.md" ] && cp "$CLAUDE_DIR/agents/browser-executor.md" "$REPO_DIR/agents/browser/"

echo "→ agents/optional/"
[ -f "$CLAUDE_DIR/agents/feishu-researcher.md" ] && cp "$CLAUDE_DIR/agents/feishu-researcher.md" "$REPO_DIR/agents/optional/"

# --- 3. Skills ---
echo "→ skills/"
if [ -d "$CLAUDE_DIR/skills/design" ]; then
    rm -rf "$REPO_DIR/skills/design"
    cp -r "$CLAUDE_DIR/skills/design" "$REPO_DIR/skills/"
fi
if [ -d "$CLAUDE_DIR/skills/product-doc" ]; then
    rm -rf "$REPO_DIR/skills/product-doc"
    cp -r "$CLAUDE_DIR/skills/product-doc" "$REPO_DIR/skills/"
fi

# --- 4. Scripts ---
echo "→ scripts/"
cp "$CLAUDE_DIR/scripts/check-build-prerequisites.sh" "$REPO_DIR/scripts/"
chmod +x "$REPO_DIR/scripts/check-build-prerequisites.sh"

# --- 5. Hooks ---
echo "→ hooks/"
[ -f "$CLAUDE_DIR/hooks/pencil-guard.sh" ] && cp "$CLAUDE_DIR/hooks/pencil-guard.sh" "$REPO_DIR/hooks/"
[ -f "$CLAUDE_DIR/hooks/playwright-route-guard.sh" ] && cp "$CLAUDE_DIR/hooks/playwright-route-guard.sh" "$REPO_DIR/hooks/"
chmod +x "$REPO_DIR/hooks/"*.sh 2>/dev/null || true

# --- 6. Memory (通用经验，排除个人错题) ---
echo "→ memory/"
[ -f "$CLAUDE_DIR/memory/details/research/search-strategy.md" ] && cp "$CLAUDE_DIR/memory/details/research/search-strategy.md" "$REPO_DIR/memory/research/"
[ -f "$CLAUDE_DIR/memory/details/design/pencil-tips.md" ] && cp "$CLAUDE_DIR/memory/details/design/pencil-tips.md" "$REPO_DIR/memory/design/"
[ -f "$CLAUDE_DIR/memory/details/plan/product-doc-lessons.md" ] && cp "$CLAUDE_DIR/memory/details/plan/product-doc-lessons.md" "$REPO_DIR/memory/plan/"
[ -f "$CLAUDE_DIR/memory/details/review/user-perspective-validation.md" ] && cp "$CLAUDE_DIR/memory/details/review/user-perspective-validation.md" "$REPO_DIR/memory/review/"
[ -f "$CLAUDE_DIR/memory/details/implement/INDEX.md" ] && cp "$CLAUDE_DIR/memory/details/implement/INDEX.md" "$REPO_DIR/memory/implement/"

# --- 7. 脱敏：替换绝对路径 ---
echo "→ 脱敏处理..."
find "$REPO_DIR" -name "*.md" -o -name "*.sh" -o -name "*.json" | while read -r file; do
    # 替换绝对路径
    sed -i '' "s|$HOME_PATH|~|g" "$file" 2>/dev/null || true
    sed -i '' "s|/Users/$USERNAME|~|g" "$file" 2>/dev/null || true
done

# --- 8. 从 settings.json 提取 build 相关配置 ---
echo "→ config/ (settings 模板)"
python3 - "$CLAUDE_DIR/settings.json" "$REPO_DIR/config" <<'PYEOF'
import json, sys, os

settings_path = sys.argv[1]
config_dir = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

# 提取 build 相关的 permissions.allow
build_allow = [
    entry for entry in settings.get("permissions", {}).get("allow", [])
    if any(kw in entry for kw in ["check-build-prerequisites", "search.py", "mcp__pencil"])
]
# 路径模板化
build_allow = [entry.replace(os.environ["HOME"], "{{HOME}}") for entry in build_allow]

# 提取 playwright deny（build 的浏览器隔离策略）
build_deny = [
    entry for entry in settings.get("permissions", {}).get("deny", [])
    if "playwright" in entry
]

# 提取 build 相关 hooks（pencil-guard, playwright-route-guard）
build_hooks = {}
for event, hook_list in settings.get("hooks", {}).items():
    relevant = []
    for hook_entry in hook_list:
        matcher = hook_entry.get("matcher", "")
        hooks = hook_entry.get("hooks", [])
        for h in hooks:
            cmd = h.get("command", "")
            if any(kw in cmd or kw in matcher for kw in ["pencil-guard", "playwright-route-guard", "mcp__pencil", "mcp__plugin_playwright"]):
                relevant.append(hook_entry)
                break
    if relevant:
        build_hooks[event] = relevant

with open(os.path.join(config_dir, "permissions-allow.json"), "w") as f:
    json.dump(build_allow, f, indent=2, ensure_ascii=False)

with open(os.path.join(config_dir, "permissions-deny.json"), "w") as f:
    json.dump(build_deny, f, indent=2, ensure_ascii=False)

with open(os.path.join(config_dir, "hooks.json"), "w") as f:
    json.dump(build_hooks, f, indent=2, ensure_ascii=False)

print(f"  permissions-allow: {len(build_allow)} 条")
print(f"  permissions-deny: {len(build_deny)} 条")
print(f"  hooks: {len(build_hooks)} 个事件")
PYEOF

# --- 9. VERSION ---
echo "1.0.0" > "$REPO_DIR/VERSION"

echo ""
echo "✅ 同步完成。请检查脱敏效果："
echo "   grep -r '/Users/' $REPO_DIR --include='*.md' --include='*.sh' | head -5"
