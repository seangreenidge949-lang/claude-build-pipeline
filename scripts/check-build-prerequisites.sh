#!/usr/bin/env bash
# Build Pipeline 前置条件检查脚本
#
# 用法: check-build-prerequisites.sh <stage> [OPTIONS]
#
# STAGES:
#   specify, research, value, plan, design, code-plan, implement, deploy, review
#
# OPTIONS:
#   --json       输出 JSON 格式（供 Claude 解析）
#   --help, -h   显示帮助
#
# 检查逻辑:
#   1. 查找项目目录（当前目录或向上查找 .build/_manifest.json）
#   2. 读取 manifest，检查当前阶段的前置依赖
#   3. 输出可用的前序产出文件列表
#
# 退出码:
#   0 = 前置条件满足
#   1 = 前置条件不满足（stderr 有可操作的错误信息）

set -e

# --- 参数解析 ---
STAGE=""
JSON_MODE=false

for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --help|-h)
            sed -n '2,/^$/s/^# //p' "$0"
            exit 0
            ;;
        -*)
            echo "ERROR: 未知选项 '$arg'" >&2
            exit 1
            ;;
        *)
            if [[ -z "$STAGE" ]]; then
                STAGE="$arg"
            else
                echo "ERROR: 多余的参数 '$arg'" >&2
                exit 1
            fi
            ;;
    esac
done

if [[ -z "$STAGE" ]]; then
    echo "ERROR: 未指定阶段。用法: check-build-prerequisites.sh <stage> [--json]" >&2
    exit 1
fi

# --- 查找项目目录 ---
find_project_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.build/_manifest.json" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

PROJECT_ROOT=$(find_project_root) || {
    echo "ERROR: 未找到 Build Pipeline 项目。当前目录及上级目录中没有 .build/_manifest.json" >&2
    echo "请先运行 /build 创建项目。" >&2
    exit 1
}

BUILD_DIR="$PROJECT_ROOT/.build"
MANIFEST="$BUILD_DIR/_manifest.json"

# --- 读取 manifest ---
if command -v python3 >/dev/null 2>&1; then
    # 用 python3 解析 JSON（比 jq 更普遍可用）
    read_manifest_field() {
        local field_path="$1"
        local manifest_path="$MANIFEST"
        python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
keys = sys.argv[2].split('.')
val = data
for k in keys:
    val = val[k]
print(val if isinstance(val, str) else json.dumps(val))
" "$manifest_path" "$field_path" 2>/dev/null
    }
elif command -v jq >/dev/null 2>&1; then
    read_manifest_field() {
        jq -r ".$1" "$MANIFEST" 2>/dev/null
    }
else
    echo "ERROR: 需要 python3 或 jq 来解析 manifest。" >&2
    exit 1
fi

# --- 阶段依赖定义 ---
# 格式: HARD_DEPS=必须完成的阶段（缺了就停）  SOFT_DEPS=可选读取的阶段（缺了告知但不停）
case "$STAGE" in
    specify)
        HARD_DEPS=""
        SOFT_DEPS=""
        ;;
    research)
        HARD_DEPS="specify"
        SOFT_DEPS=""
        ;;
    value)
        HARD_DEPS="specify"
        SOFT_DEPS="research"
        ;;
    plan)
        HARD_DEPS="specify"
        SOFT_DEPS="research value"
        ;;
    design)
        HARD_DEPS="specify plan"
        SOFT_DEPS="research value"
        ;;
    code-plan)
        HARD_DEPS="specify plan"
        SOFT_DEPS="research value design"
        ;;
    implement)
        HARD_DEPS="specify code-plan"
        SOFT_DEPS="plan design"
        ;;
    deploy)
        HARD_DEPS="specify implement"
        SOFT_DEPS="code-plan"
        ;;
    review)
        HARD_DEPS="specify"
        SOFT_DEPS="research value plan design code-plan implement deploy"
        ;;
    *)
        echo "ERROR: 未知阶段 '$STAGE'。有效阶段: specify, research, value, plan, design, code-plan, implement, deploy, review" >&2
        exit 1
        ;;
esac

# --- 阶段名 → 文件名映射 ---
stage_to_file() {
    case "$1" in
        specify)    echo "01-specify.md" ;;
        research)   echo "02-research.md" ;;
        value)      echo "03-value.md" ;;
        plan)       echo "04-plan.md" ;;
        design)     echo "05-design.md" ;;
        code-plan)  echo "06-code-plan.md" ;;
        implement)  echo "07-implement-log.md" ;;
        deploy)     echo "08-deploy.md" ;;
        review)     echo "09-review.md" ;;
    esac
}

# 阶段名 → 对应的 /build.xxx 命令
stage_to_command() {
    case "$1" in
        specify)    echo "/build.specify" ;;
        research)   echo "/build.research" ;;
        value)      echo "/build.value" ;;
        plan)       echo "/build.plan" ;;
        design)     echo "/build.design" ;;
        code-plan)  echo "/build.code-plan" ;;
        implement)  echo "/build.implement" ;;
        deploy)     echo "/build.deploy" ;;
        review)     echo "/build.review" ;;
    esac
}

# --- 硬检查 ---
ERRORS=()
for dep in $HARD_DEPS; do
    status=$(read_manifest_field "stages.$dep.status" 2>/dev/null || echo "unknown")
    if [[ "$status" != "completed" && "$status" != "skipped" ]]; then
        ERRORS+=("$dep")
    fi
done

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    for dep in "${ERRORS[@]}"; do
        dep_status=$(read_manifest_field "stages.$dep.status" 2>/dev/null || echo "unknown")
        echo "ERROR: Stage '$dep' not completed (status: $dep_status). Run $(stage_to_command "$dep") first." >&2
    done
    exit 1
fi

# --- 软扫描：可用文档 ---
AVAILABLE_DOCS=()
MISSING_OPTIONAL=()

# 检查所有已完成阶段的产出文件
ALL_STAGES="specify research value plan design code-plan implement deploy"
for s in $ALL_STAGES; do
    file=$(stage_to_file "$s")
    if [[ -f "$BUILD_DIR/$file" ]]; then
        AVAILABLE_DOCS+=("$file")
    else
        # 只记录软依赖中缺失的
        for sd in $SOFT_DEPS; do
            if [[ "$sd" == "$s" ]]; then
                MISSING_OPTIONAL+=("$s")
            fi
        done
    fi
done

# --- 读取 manifest 基本信息 ---
FEATURE_NAME=$(read_manifest_field "feature_name" 2>/dev/null || echo "unknown")
FEATURE_SLUG=$(read_manifest_field "feature" 2>/dev/null || echo "unknown")
STOP_AFTER=$(read_manifest_field "stop_after" 2>/dev/null || echo "null")

# --- 输出 ---
if $JSON_MODE; then
    # 构建 JSON 输出（通过环境变量传递，避免 shell 注入）
    AVAILABLE_DOCS_STR="${AVAILABLE_DOCS[*]}"
    MISSING_OPTIONAL_STR="${MISSING_OPTIONAL[*]}"
    export PROJECT_ROOT BUILD_DIR FEATURE_SLUG FEATURE_NAME STAGE STOP_AFTER AVAILABLE_DOCS_STR MISSING_OPTIONAL_STR
    python3 -c "
import json, os
avail = os.environ.get('AVAILABLE_DOCS_STR', '').split()
missing = os.environ.get('MISSING_OPTIONAL_STR', '').split()
stop = os.environ.get('STOP_AFTER', 'null')
data = {
    'project_root': os.environ['PROJECT_ROOT'],
    'build_dir': os.environ['BUILD_DIR'],
    'feature': os.environ['FEATURE_SLUG'],
    'feature_name': os.environ['FEATURE_NAME'],
    'stage': os.environ['STAGE'],
    'stop_after': None if stop == 'null' else stop,
    'prerequisites_met': True,
    'available_docs': [d for d in avail if d],
    'missing_optional': [d for d in missing if d],
}
print(json.dumps(data, ensure_ascii=False))
"
else
    echo "📋 项目: $FEATURE_NAME"
    echo "📁 路径: $PROJECT_ROOT"
    echo "🎯 当前阶段: $STAGE"
    echo ""
    echo "可用文档:"
    for doc in "${AVAILABLE_DOCS[@]}"; do
        echo "  ✓ $doc"
    done
    if [[ ${#MISSING_OPTIONAL[@]} -gt 0 ]]; then
        echo ""
        echo "可选文档（未找到）:"
        for dep in "${MISSING_OPTIONAL[@]}"; do
            echo "  ✗ $(stage_to_file "$dep")（$(stage_to_command "$dep") 未执行）"
        done
    fi
fi
