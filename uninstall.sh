#!/usr/bin/env bash
# uninstall.sh — 卸载 Claude Build Pipeline
set -e

CLAUDE_DIR="$HOME/.claude"
MANIFEST="$CLAUDE_DIR/.build-pipeline-installed"

if [ ! -f "$MANIFEST" ]; then
    echo "❌ 未找到安装记录（~/.claude/.build-pipeline-installed）"
    echo "   Build Pipeline 可能未安装，或已手动卸载。"
    exit 1
fi

echo "🗑️  卸载 Claude Build Pipeline..."
echo ""

REMOVED=0

# --- 1. 删除 commands ---
echo "→ 移除 commands..."
for f in "$CLAUDE_DIR"/commands/build*.md; do
    [ -f "$f" ] && rm "$f" && ((REMOVED++))
done

# --- 2. 删除 agents ---
echo "→ 移除 agents..."
BUILD_AGENTS=(
    web-collector info-analyst plan-reviewer implement-reviewer
    product-doc-reviewer solution-critic strategic-planner
    design-aesthetic-critic design-designer design-librarian
    design-researcher design-ux-critic ui-design-master
    browser-executor feishu-researcher
)
for agent in "${BUILD_AGENTS[@]}"; do
    [ -f "$CLAUDE_DIR/agents/$agent.md" ] && rm "$CLAUDE_DIR/agents/$agent.md" && ((REMOVED++))
done

# --- 3. 删除 skills ---
echo "→ 移除 skills..."
[ -d "$CLAUDE_DIR/skills/design" ] && rm -rf "$CLAUDE_DIR/skills/design" && ((REMOVED++))
[ -d "$CLAUDE_DIR/skills/product-doc" ] && rm -rf "$CLAUDE_DIR/skills/product-doc" && ((REMOVED++))

# --- 4. 删除 scripts ---
echo "→ 移除 scripts..."
[ -f "$CLAUDE_DIR/scripts/check-build-prerequisites.sh" ] && rm "$CLAUDE_DIR/scripts/check-build-prerequisites.sh" && ((REMOVED++))

# --- 5. 删除 hooks ---
echo "→ 移除 hooks..."
[ -f "$CLAUDE_DIR/hooks/pencil-guard.sh" ] && rm "$CLAUDE_DIR/hooks/pencil-guard.sh" && ((REMOVED++))
[ -f "$CLAUDE_DIR/hooks/playwright-route-guard.sh" ] && rm "$CLAUDE_DIR/hooks/playwright-route-guard.sh" && ((REMOVED++))

# --- 6. Memory 不删除 ---
echo "→ memory/ 保留（用户数据不删除）"

# --- 7. 恢复 settings.json ---
echo "→ settings.json..."
if [ -f "$CLAUDE_DIR/settings.json.bak" ]; then
    echo "  发现安装前备份，是否恢复？(y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        cp "$CLAUDE_DIR/settings.json.bak" "$CLAUDE_DIR/settings.json"
        rm "$CLAUDE_DIR/settings.json.bak"
        echo "  ✓ 已恢复 settings.json"
    else
        echo "  ⚠ 跳过。请手动移除 build 相关的 permissions/hooks 条目"
    fi
else
    echo "  ⚠ 未找到备份，请手动移除 build 相关的 permissions/hooks 条目"
fi

# --- 8. 删除清单 ---
rm "$MANIFEST"

echo ""
echo "═══════════════════════════════════════"
echo "✅ 卸载完成！已移除 $REMOVED 个文件/目录"
echo "   memory/ 下的经验文件已保留"
echo "═══════════════════════════════════════"
