#!/bin/bash
# PreToolUse 路由守卫：强制 Playwright 操作走 browser-executor subagent
#
# 判定依据：PreToolUse payload 里只有 subagent 调用才带 agent_type 字段
#   - 主会话（无 agent_type）            → BLOCK
#   - agent_type == "browser-executor"  → ALLOW
#   - 其他 subagent（含未知 agent_type） → BLOCK

INPUT=$(cat)
LOG=/tmp/playwright-route-guard.log

PARSED=$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print("ALLOW|?|parse_error")
    sys.exit(0)
at = d.get("agent_type")
tn = d.get("tool_name", "?")
if at == "browser-executor":
    print("ALLOW|" + tn + "|subagent=browser-executor")
elif at:
    print("BLOCK|" + tn + "|subagent=" + str(at))
else:
    print("BLOCK|" + tn + "|main-session")
')

VERDICT=$(printf '%s' "$PARSED" | cut -d'|' -f1)
TOOL=$(printf '%s' "$PARSED" | cut -d'|' -f2)
SOURCE=$(printf '%s' "$PARSED" | cut -d'|' -f3)

echo "$(date '+%H:%M:%S') $VERDICT $TOOL source=$SOURCE" >> "$LOG"

if [ "$VERDICT" = "ALLOW" ]; then
  echo '{"decision": "allow"}'
  exit 0
fi

export GUARD_SOURCE="$SOURCE"
python3 -c '
import json, os
reason = (
    "浏览器操作（Playwright MCP 工具）已被路由到低成本 Haiku subagent。"
    "请改用 Agent(subagent_type=\"browser-executor\", prompt=\"...\") 派发，"
    "不要在主会话直接调用 mcp__plugin_playwright_playwright__* 工具。"
    "触发源=" + os.environ.get("GUARD_SOURCE", "?")
)
print(json.dumps({"decision": "block", "reason": reason}, ensure_ascii=False))
'

exit 0
