#!/usr/bin/env bash
# install.sh — 安装 Claude Build Pipeline 到用户的 ~/.claude/
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
INSTALLED_FILES=()
SKIPPED_FILES=()

# --- 参数解析 ---
INSTALL_DESIGN=true
INSTALL_FEISHU=true
UPGRADE_MODE=false

for arg in "$@"; do
    case "$arg" in
        --no-design) INSTALL_DESIGN=false ;;
        --no-feishu) INSTALL_FEISHU=false ;;
        --upgrade) UPGRADE_MODE=true ;;
        --help|-h)
            echo "用法: install.sh [OPTIONS]"
            echo ""
            echo "选项:"
            echo "  --no-design   跳过设计阶段相关组件（Pencil MCP 不可用时）"
            echo "  --no-feishu   跳过飞书相关组件"
            echo "  --upgrade     升级模式（覆盖已有的 commands/agents/skills/scripts/hooks）"
            echo "  --help, -h    显示帮助"
            exit 0
            ;;
    esac
done

# --- 前置检查 ---
echo "🔍 检查前置条件..."
echo ""

if [ ! -d "$CLAUDE_DIR" ]; then
    echo "❌ 未找到 ~/.claude/ 目录。请先安装 Claude Code。"
    exit 1
fi
echo "  ✓ ~/.claude/ 存在"

if ! command -v python3 >/dev/null 2>&1; then
    echo "  ✗ python3 未安装（check-build-prerequisites.sh 需要）"
    echo "    安装方式: brew install python3"
    exit 1
fi
echo "  ✓ python3 $(python3 --version 2>&1 | cut -d' ' -f2)"

if command -v claude >/dev/null 2>&1; then
    echo "  ✓ Claude Code CLI 已安装"
else
    echo "  ⚠ Claude Code CLI 未检测到（可能使用其他方式启动）"
fi

echo ""

# --- 辅助函数 ---
copy_file() {
    local src="$1"
    local dst="$2"
    local dst_dir="$(dirname "$dst")"

    mkdir -p "$dst_dir"

    if [ -f "$dst" ] && [ "$UPGRADE_MODE" = false ]; then
        SKIPPED_FILES+=("$dst")
        return
    fi

    # 路径适配：替换 {{HOME}} 和 ~ 为实际路径
    if [[ "$src" == *.json ]]; then
        sed "s|{{HOME}}|$HOME|g" "$src" > "$dst"
    else
        cp "$src" "$dst"
    fi

    INSTALLED_FILES+=("$dst")
}

copy_file_no_overwrite() {
    local src="$1"
    local dst="$2"
    if [ -f "$dst" ]; then
        SKIPPED_FILES+=("$dst (memory，已存在不覆盖)")
        return
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    INSTALLED_FILES+=("$dst")
}

# --- 1. Commands ---
echo "📋 安装 commands..."
for f in "$REPO_DIR"/commands/build*.md; do
    copy_file "$f" "$CLAUDE_DIR/commands/$(basename "$f")"
done

# --- 2. Agents ---
echo "🤖 安装 agents..."
# core（必需）
for f in "$REPO_DIR"/agents/core/*.md; do
    [ -f "$f" ] && copy_file "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
done

# design（可选）
if [ "$INSTALL_DESIGN" = true ]; then
    for f in "$REPO_DIR"/agents/design/*.md; do
        [ -f "$f" ] && copy_file "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
    done
fi

# browser
for f in "$REPO_DIR"/agents/browser/*.md; do
    [ -f "$f" ] && copy_file "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
done

# feishu（可选）
if [ "$INSTALL_FEISHU" = true ]; then
    for f in "$REPO_DIR"/agents/optional/*.md; do
        [ -f "$f" ] && copy_file "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
    done
fi

# --- 3. Skills ---
echo "🎯 安装 skills..."
if [ "$INSTALL_DESIGN" = true ] && [ -d "$REPO_DIR/skills/design" ]; then
    mkdir -p "$CLAUDE_DIR/skills/design/references"
    for f in "$REPO_DIR"/skills/design/SKILL.md "$REPO_DIR"/skills/design/references/*; do
        [ -f "$f" ] && copy_file "$f" "$CLAUDE_DIR/skills/design/${f#$REPO_DIR/skills/design/}"
    done
fi
if [ -d "$REPO_DIR/skills/product-doc" ]; then
    mkdir -p "$CLAUDE_DIR/skills/product-doc/references"
    for f in "$REPO_DIR"/skills/product-doc/SKILL.md "$REPO_DIR"/skills/product-doc/references/*; do
        [ -f "$f" ] && copy_file "$f" "$CLAUDE_DIR/skills/product-doc/${f#$REPO_DIR/skills/product-doc/}"
    done
fi
if [ -d "$REPO_DIR/skills/web-research" ]; then
    mkdir -p "$CLAUDE_DIR/skills/web-research"
    for f in "$REPO_DIR"/skills/web-research/SKILL.md; do
        [ -f "$f" ] && copy_file "$f" "$CLAUDE_DIR/skills/web-research/$(basename "$f")"
    done
fi

# --- 4. Scripts ---
echo "⚙️  安装 scripts..."
copy_file "$REPO_DIR/scripts/check-build-prerequisites.sh" "$CLAUDE_DIR/scripts/check-build-prerequisites.sh"
chmod +x "$CLAUDE_DIR/scripts/check-build-prerequisites.sh"
copy_file "$REPO_DIR/scripts/search.py" "$CLAUDE_DIR/scripts/search.py"
chmod +x "$CLAUDE_DIR/scripts/search.py"
[ -f "$REPO_DIR/scripts/scrape.py" ] && copy_file "$REPO_DIR/scripts/scrape.py" "$CLAUDE_DIR/scripts/scrape.py" && chmod +x "$CLAUDE_DIR/scripts/scrape.py"

# --- 5. Hooks ---
echo "🪝 安装 hooks..."
if [ "$INSTALL_DESIGN" = true ] && [ -f "$REPO_DIR/hooks/pencil-guard.sh" ]; then
    copy_file "$REPO_DIR/hooks/pencil-guard.sh" "$CLAUDE_DIR/hooks/pencil-guard.sh"
    chmod +x "$CLAUDE_DIR/hooks/pencil-guard.sh"
fi
if [ -f "$REPO_DIR/hooks/playwright-route-guard.sh" ]; then
    copy_file "$REPO_DIR/hooks/playwright-route-guard.sh" "$CLAUDE_DIR/hooks/playwright-route-guard.sh"
    chmod +x "$CLAUDE_DIR/hooks/playwright-route-guard.sh"
fi

# --- 6. Memory（种子知识，不覆盖） ---
echo "🧠 安装 memory（种子知识）..."
mkdir -p "$CLAUDE_DIR/memory/details/"{research,design,plan,review,implement}
for subdir in research design plan review implement; do
    for f in "$REPO_DIR"/memory/"$subdir"/*; do
        [ -f "$f" ] && copy_file_no_overwrite "$f" "$CLAUDE_DIR/memory/details/$subdir/$(basename "$f")"
    done
done
# platform-specs（design 阶段 UX 审查用）
if [ "$INSTALL_DESIGN" = true ] && [ -d "$REPO_DIR/memory/design/platform-specs" ]; then
    mkdir -p "$CLAUDE_DIR/memory/design/platform-specs"
    for f in "$REPO_DIR"/memory/design/platform-specs/*.md; do
        [ -f "$f" ] && copy_file_no_overwrite "$f" "$CLAUDE_DIR/memory/design/platform-specs/$(basename "$f")"
    done
fi

# --- 7. Merge settings.json ---
echo "⚙️  合并 settings.json..."
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.bak"
    python3 - "$CLAUDE_DIR/settings.json" "$REPO_DIR/config" "$HOME" <<'PYEOF'
import json, sys, os

settings_path = sys.argv[1]
config_dir = sys.argv[2]
home = sys.argv[3]

with open(settings_path) as f:
    settings = json.load(f)

# Merge permissions.allow
allow_file = os.path.join(config_dir, "permissions-allow.json")
if os.path.exists(allow_file):
    with open(allow_file) as f:
        new_allow = json.load(f)
    new_allow = [entry.replace("{{HOME}}", home) for entry in new_allow]
    existing = settings.setdefault("permissions", {}).setdefault("allow", [])
    for entry in new_allow:
        if entry not in existing:
            existing.append(entry)
            print(f"  + allow: {entry[:60]}...")

# Merge permissions.deny
deny_file = os.path.join(config_dir, "permissions-deny.json")
if os.path.exists(deny_file):
    with open(deny_file) as f:
        new_deny = json.load(f)
    existing_deny = settings.setdefault("permissions", {}).setdefault("deny", [])
    for entry in new_deny:
        if entry not in existing_deny:
            existing_deny.append(entry)
    print(f"  + deny: {len(new_deny)} playwright 隔离规则")

# Merge hooks
hooks_file = os.path.join(config_dir, "hooks.json")
if os.path.exists(hooks_file):
    with open(hooks_file) as f:
        new_hooks = json.load(f)
    existing_hooks = settings.setdefault("hooks", {})
    for event, entries in new_hooks.items():
        event_hooks = existing_hooks.setdefault(event, [])
        for entry in entries:
            matcher = entry.get("matcher", "")
            already_exists = any(
                h.get("matcher", "") == matcher and
                any(hook.get("command", "") == entry_hook.get("command", "")
                    for hook in h.get("hooks", [])
                    for entry_hook in entry.get("hooks", []))
                for h in event_hooks
            )
            if not already_exists:
                event_hooks.append(entry)
                print(f"  + hook[{event}]: matcher={matcher[:40]}")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")

print("  settings.json 更新完成（备份: settings.json.bak）")
PYEOF
else
    echo "  ⚠ settings.json 不存在，跳过合并"
fi

# --- 8. 写安装清单 ---
MANIFEST="$CLAUDE_DIR/.build-pipeline-installed"
cat > "$MANIFEST" <<EOF
version=$(cat "$REPO_DIR/VERSION")
installed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
source=$REPO_DIR
files_count=${#INSTALLED_FILES[@]}
options=design=$INSTALL_DESIGN,feishu=$INSTALL_FEISHU
EOF

# --- 完成报告 ---
echo ""
echo "═══════════════════════════════════════"
echo "✅ 安装完成！"
echo ""
echo "  已安装: ${#INSTALLED_FILES[@]} 个文件"
if [ ${#SKIPPED_FILES[@]} -gt 0 ]; then
    echo "  已跳过: ${#SKIPPED_FILES[@]} 个文件（已存在）"
fi
echo ""
echo "使用方式: 在 Claude Code 中输入 /build <你要做的功能>"
echo ""
echo "卸载: bash $(dirname "$0")/uninstall.sh"
echo "═══════════════════════════════════════"
