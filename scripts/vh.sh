#!/usr/bin/env bash
# vh · Vibe Helper 命令行助手，不依赖 agent，纯终端可用
# 用法:
#   vh new <产品名>                # 创建产品工作区骨架，含目录、prototypes/ 与 backlog.md
#   vh next [产品目录]             # 看流程走到哪一步、下一步做什么、用哪个 skill/命令
#   vh check [产品目录] [--expect 交付包]   # 跑交付包机器自检
#   vh backlog <产品目录> <想法>   # 范围守卫：把中途冒出的想法记进 backlog
# 说明: 需要 Git Bash / WSL / 任何 bash 环境。

set -u

DOCS=("01-问卷.md" "02-brief.md" "03-竞品分析.md" "04-用户声音.md" "05-需求分层.md" "06-产品框架.md" "07-技术框架.md")
STAGES=("Stage 1 需求访谈" "Stage 2 产品 Brief" "Stage 3 竞品调研" "Stage 4 用户声音" "Stage 5 需求分层" "Stage 6 产品框架" "Stage 6 技术框架")
HOWTO=("product-brief / vibe-brief" "product-brief / vibe-brief" "competitive-analysis / vibe-competitive" "user-voice / vibe-voice" "requirements-layering / vibe-req" "tech-framework / vibe-tech" "tech-framework / vibe-tech")

find_validate() {
  local self_dir cand
  self_dir=$(cd "$(dirname "$0")" && pwd)
  for cand in \
    "$self_dir/../skills/Vibe_helper/scripts/validate.sh" \
    "$HOME/.agents/skills/Vibe_helper/scripts/validate.sh" \
    "$HOME/.claude/skills/Vibe_helper/scripts/validate.sh"; do
    if [ -f "$cand" ]; then echo "$cand"; return 0; fi
  done
  return 1
}

status_of() {
  if [ ! -f "$1" ]; then echo "未开始"
  elif [ "$(wc -c < "$1")" -lt 200 ]; then echo "半成品"
  else echo "完成"; fi
}

cmd_new() {
  local name="${1:-}"
  [ -z "$name" ] && { echo "用法: vh new <产品名>"; exit 1; }
  if [ -d "$name" ]; then echo "目录已存在: $name，不覆盖"; exit 1; fi
  mkdir -p "$name/prototypes"
  printf '# Backlog · %s\n\n中途冒出的新想法一律先记这里，二期再议。\n\n' "$name" > "$name/backlog.md"
  echo "已创建 $name/，含 prototypes/ 与 backlog.md"
  echo "下一步: 对 agent 说“我想做一个叫 $name 的产品”，或用 /vibe $name"
}

cmd_next() {
  local dir="${1:-.}"
  [ -d "$dir" ] || dir="./$dir"
  if [ ! -d "$dir" ]; then echo "未找到产品目录: $1"; echo "先运行: vh new <产品名>"; exit 1; fi
  echo "产品目录: $dir"
  echo "----------------------------------------"
  if [ -f "$dir/00-状态.md" ]; then
    sv=$(grep -m1 -oE '版本 v[0-9]+' "$dir/00-状态.md" || true)
    printf '  %-18s %-8s %s\n' "00-状态.md" "${sv:-无版本}" "主上下文/交接首材料"
  else
    printf '  %-18s %-8s %s\n' "00-状态.md" "未开始" "主上下文/交接首材料"
  fi
  local i st first=-1
  for i in "${!DOCS[@]}"; do
    st=$(status_of "$dir/${DOCS[$i]}")
    printf '  %-18s %-6s %s\n' "${DOCS[$i]}" "$st" "${STAGES[$i]}"
    if [ "$st" != "完成" ] && [ "$first" -lt 0 ]; then first=$i; fi
  done
  # AI 轨道: 08-评测方案 与 badcase 台账
  local ai=0
  for f in "00-状态.md" "02-brief.md" "05-需求分层.md"; do
    [ -f "$dir/$f" ] && grep -q "AI 轨道" "$dir/$f" && ai=1
  done
  [ -f "$dir/08-评测方案.md" ] && ai=1
  if [ "$ai" -eq 1 ]; then
    printf '  %-18s %-6s %s\n' "08-评测方案.md" "$(status_of "$dir/08-评测方案.md")" "Stage 6 评测方案，AI 轨道"
    if [ -f "$dir/badcase台账.md" ]; then
      printf '  %-18s %-6s\n' "badcase台账.md" "已创建"
    else
      printf '  %-18s %-6s\n' "badcase台账.md" "未创建"
    fi
  fi
  local pst="未开始"
  [ -f "$dir/prototypes/index.html" ] && pst="完成"
  printf '  %-18s %-6s %s\n' "prototypes/" "$pst" "Stage 7 静态原型"
  if [ -f "$dir/backlog.md" ]; then
    printf '  %-18s %-6s\n' "backlog.md" "$(grep -c '^- ' "$dir/backlog.md" 2>/dev/null || echo 0) 条"
  fi
  echo "----------------------------------------"
  if [ "$first" -ge 0 ]; then
    echo "→ 下一步: ${STAGES[$first]}，文件 ${DOCS[$first]}"
    echo "  用 skill ${HOWTO[$first]%% *} 或命令 /${HOWTO[$first]##* } 触发；已完成文件会自动复用"
  elif [ ! -f "$dir/prototypes/index.html" ]; then
    echo "→ 下一步: Stage 7 静态原型prototypes/index.html，用 Vibe_helper 全流程或 /vibe 继续"
  else
    echo "→ 文档与原型齐全: Stage 8 交接，用 Vibe_helper 全流程或 /vibe 收尾，交付前跑 vh check --expect 交付包"
  fi
}

cmd_check() {
  local dir="${1:-.}" expect=""
  if [ "${2:-}" = "--expect" ]; then expect="${3:-交付包}"; fi
  [ -d "$dir" ] || dir="./$dir"
  local script
  if ! script=$(find_validate); then
    echo "未找到 validate.sh，找过套件仓库与 ~/.agents/skills、~/.claude/skills"
    echo "请先安装 Vibe_helper 套件，或在本仓库目录内运行"
    exit 1
  fi
  if [ -n "$expect" ]; then
    bash "$script" "$dir" --expect "$expect"
  else
    bash "$script" "$dir"
  fi
}

cmd_backlog() {
  local dir="${1:-}" item="${2:-}"
  if [ -z "$dir" ] || [ -z "$item" ]; then
    echo "用法: vh backlog <产品目录> <想法内容>"; exit 1
  fi
  [ -d "$dir" ] || dir="./$dir"
  [ -d "$dir" ] || { echo "未找到产品目录: $1"; exit 1; }
  [ -f "$dir/backlog.md" ] || printf '# Backlog\n\n' > "$dir/backlog.md"
  printf -- '- [%s] %s\n' "$(date +%F)" "$item" >> "$dir/backlog.md"
  echo "已记入 $dir/backlog.md：$item"
  echo "范围守卫：新想法不进本期，二期再议"
}

case "${1:-}" in
  new)      shift; cmd_new "$@" ;;
  next)     shift; cmd_next "$@" ;;
  check)    shift; cmd_check "$@" ;;
  backlog)  shift; cmd_backlog "$@" ;;
  *)
    cat <<'EOF'
vh · Vibe Helper 命令行助手

用法:
  vh new <产品名>                        创建产品工作区骨架
  vh next [产品目录]                     看流程进度与下一步
  vh check [产品目录] [--expect 交付包]  跑交付包机器自检
  vh backlog <产品目录> <想法>           新想法记入 backlog，范围守卫
EOF
    ;;
esac
