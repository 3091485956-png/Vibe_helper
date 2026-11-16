#!/usr/bin/env bash
# 把本仓库 skills/ 下的所有 skill 安装到 agent 技能目录
# 用法:
#   bash scripts/install.sh                # 装到 ~/.agents/skills，ZCode 等
#   bash scripts/install.sh --claude       # 装到 ~/.claude/skills (Claude Code)
#   bash scripts/install.sh --commands     # 额外把 slash 命令装到 ~/.claude/commands (非插件安装时用)
#   bash scripts/install.sh --target DIR   # 装到自定义目录
#   bash scripts/install.sh --only X,Y     # 只装指定 skill
# 说明: 每个 skill 文件夹自包含，references 副本齐全，单独拷贝某个文件夹也能用。

set -u
cd "$(dirname "$0")/.."

TARGET=""
ONLY=""
WITH_COMMANDS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --claude) TARGET="$HOME/.claude/skills"; shift ;;
    --commands) WITH_COMMANDS=1; shift ;;
    --only)   ONLY="${2:-}"; shift 2 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done
[ -z "$TARGET" ] && TARGET="$HOME/.agents/skills"

mkdir -p "$TARGET"

for d in skills/*/; do
  name=$(basename "$d")
  if [ -n "$ONLY" ]; then
    echo ",$ONLY," | grep -q ",$name," || continue
  fi
  rm -rf "$TARGET/$name"
  cp -r "$d" "$TARGET/$name"
  echo "[OK] $name -> $TARGET/$name"
done

if [ "$WITH_COMMANDS" = "1" ]; then
  CMD_DIR="$HOME/.claude/commands"
  mkdir -p "$CMD_DIR"
  for c in commands/*.md; do
    [ -f "$c" ] || continue
    cp "$c" "$CMD_DIR/"
    echo "[OK] 命令 /$(basename "$c" .md) -> $CMD_DIR/"
  done
fi

echo
echo "完成。新装的 skill 一般要在新会话或重启 agent 后生效。"
echo "如需卸载: rm -rf $TARGET/<skill名>"
