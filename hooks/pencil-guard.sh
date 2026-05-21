#!/bin/bash
# PreToolUse hook: Pencil 经验文件读取守卫（command 类型）
#
# 令牌机制：
# - 有令牌（30 分钟内）→ 直接放行
# - 无令牌 → block，要求先读 pencil-tips.md
# - 读完后 Claude 创建令牌，后续免检
#
# 比 prompt hook 的优势：
# - 确定性判断，不受上下文距离影响
# - 0 token 消耗
# - 不会因对话变长而误判

# 令牌检查
TOKEN_FILE="/tmp/claude-pencil-tips-read"
if [ -f "$TOKEN_FILE" ]; then
  TOKEN_AGE=$(( $(date +%s) - $(stat -f %m "$TOKEN_FILE" 2>/dev/null || echo 0) ))
  if [ "$TOKEN_AGE" -lt 1800 ]; then
    echo '{"decision": "allow"}'
    exit 0
  fi
  rm -f "$TOKEN_FILE"
fi

# 无令牌 → 拦截
cat << 'BLOCK'
{"decision": "block", "reason": "⚠️ Pencil 设计操作前请先读取 details/pencil-tips.md 经验文件。\n\n关键坑点：\n1) 文字不换行必须手动 \\n + snapshot_layout 校准\n2) fill 不支持渐变（静默失败）\n3) textColor 无效需用 fill\n4) 每次 batch_design ≤25 ops\n5) Copy 后不能 Update 子节点（ID 已变）\n\n读完后创建令牌：echo read > /tmp/claude-pencil-tips-read\n然后重试操作。令牌有效 30 分钟。"}
BLOCK
exit 0
