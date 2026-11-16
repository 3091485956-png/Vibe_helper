#!/usr/bin/env bash
# skill 自检: 校验本仓库 skills/ 下的所有 skill 结构健康
# 用法: bash scripts/lint-skills.sh
# 检查项:
#   1. 每个 skill 有 SKILL.md 且 frontmatter 完整，含 name 与 description，name 与目录一致
#   2. 文中引用的 references/*.md 必须真实存在(死链检查)
#   3. 共享 reference 在多个 skill 间必须字节一致，防漂移
#   4. 触发词划界: 全流程关键词只归 Vibe_helper
#   5. M1-M10 编号: 凡引用必须能在 Vibe_helper 失败模式表中找到定义
#   6. 所有 .sh 语法检查
# 退出码: 0 = 全部通过, 1 = 存在必须修复的问题

set -u
cd "$(dirname "$0")/.."
ROOT=$(pwd)

PASS=0; FAIL=0; WARN=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN+1)); }

echo "skill 自检 · 仓库根目录: $ROOT"
echo "----------------------------------------"

SKILLS=$(find skills -mindepth 1 -maxdepth 1 -type d | sort)

# ---- 1. SKILL.md + frontmatter ----
for d in $SKILLS; do
  name=$(basename "$d")
  f="$d/SKILL.md"
  if [ ! -f "$f" ]; then bad "$name 缺 SKILL.md"; continue; fi
  head -1 "$f" | grep -q '^---' || { bad "$name SKILL.md 缺 frontmatter，首行须为 ---"; continue; }
  FM=$(awk 'NR==1&&/^---/{fm=1;next} fm&&/^---/{exit} fm{print}' "$f")
  echo "$FM" | grep -qE '^name:' || bad "$name frontmatter 缺 name"
  echo "$FM" | grep -qE '^description:' || bad "$name frontmatter 缺 description"
  fmname=$(echo "$FM" | sed -nE 's/^name:[[:space:]]*//p' | tr -d '\r"')
  [ "$fmname" = "$name" ] || bad "$name frontmatter name $fmname 与目录名不一致"
  desclen=$(echo "$FM" | sed -nE 's/^description:[[:space:]]*//p' | tr -d '\r' | wc -m)
  [ "$desclen" -gt 900 ] && warn "$name description 长度 ${desclen} 字符，双语版上限 900，建议瘦身：做什么加 Use when 加触发句"
  ok "$name SKILL.md frontmatter 完整"
done

# ---- 2. references 死链 ----
for d in $SKILLS; do
  name=$(basename "$d")
  refs=$(grep -rhoE 'references/[A-Za-z0-9._-]+\.md' "$d" 2>/dev/null | sort -u)
  [ -z "$refs" ] && continue
  while IFS= read -r r; do
    if [ -f "$d/$r" ]; then
      ok "$name 引用 $r 存在"
    else
      bad "$name 引用的 $r 不存在，死链"
    fi
  done <<< "$refs"
done

# ---- 3. 共享文件漂移检查 ----
# 映射: 文件名 -> 持有它的 skill 列表，至少 2 个才需要一致
check_drift() {
  local file="$1"; shift
  local first=""
  for d in "$@"; do
    p="skills/$d/references/$file"
    [ -f "$p" ] || { bad "漂移检查: 缺 $p"; return; }
    if [ -z "$first" ]; then first="$p"
    else
      if cmp -s "$first" "$p"; then
        ok "共享文件一致: $file ($d)"
      else
        bad "共享文件漂移: $first 与 $p 内容不一致，改共享文件必须同步所有副本"
      fi
    fi
  done
}
check_drift anti-hallucination.md Vibe_helper competitive-analysis user-voice
check_drift questionnaire.md Vibe_helper product-brief
check_drift prompt-refinement.md Vibe_helper product-brief
check_drift competitive-analysis.md Vibe_helper competitive-analysis
check_drift user-research.md Vibe_helper user-voice
check_drift requirements-layering.md Vibe_helper requirements-layering
check_drift framework-output.md Vibe_helper tech-framework
check_drift eval-plan.md Vibe_helper tech-framework
check_drift context-assembly.md Vibe_helper product-brief requirements-layering tech-framework

# ---- 4. 触发词划界，只看 frontmatter 的 description 行 ----
ORCH="skills/Vibe_helper/SKILL.md"
orch_desc() { sed -nE 's/^description:[[:space:]]*//p' "$1" | head -1; }
for kw in "一条龙" "从零开始" "全流程"; do
  if orch_desc "$ORCH" | grep -q "$kw"; then
    ok "orchestrator 持有触发词 $kw"
  else
    warn "orchestrator description 疑似缺少全流程触发词 $kw"
  fi
done
for d in $SKILLS; do
  name=$(basename "$d")
  [ "$name" = "Vibe_helper" ] && continue
  # 允许出现"改用 Vibe_helper / 无需单独触发"这类负面引导句, 只拦真正的抢占
  HITS=$(orch_desc "$d/SKILL.md" | grep -E "一条龙|从零开始|全流程" | grep -vE "改用|而非|无需" || true)
  if [ -n "$HITS" ]; then
    bad "$name description 抢占了全流程触发词，会劫持一条龙请求"
  else
    ok "$name 触发词与 orchestrator 无冲突"
  fi
done

# ---- 5. M 编号一致性 ----
USED=$(grep -rhoE '\bM(10|[1-9])\b' skills --include='*.md' | sort -u | tr -d '\r')
for m in $USED; do
  if grep -q "$m" "$ORCH"; then
    ok "编号 $m 在失败模式表中有定义"
  else
    bad "编号 $m 被引用但 Vibe_helper 失败模式表中无定义"
  fi
done
for i in 1 2 3 4 5 6 7 8 9 10; do
  grep -q "M$i" "$ORCH" || bad "失败模式表缺 M$i"
done

# ---- 7. commands/ 命令文件，如存在 ----
SKILL_NAMES='Vibe_helper|product-brief|competitive-analysis|user-voice|requirements-layering|tech-framework'
if [ -d commands ] && ls commands/*.md >/dev/null 2>&1; then
  for c in commands/*.md; do
    cname=$(basename "$c" .md)
    head -1 "$c" | grep -q '^---' || { bad "/$cname 缺 frontmatter，首行须为 ---"; continue; }
    CFM=$(awk 'NR==1&&/^---/{fm=1;next} fm&&/^---/{exit} fm{print}' "$c")
    echo "$CFM" | grep -qE '^description:' || bad "/$cname frontmatter 缺 description"
    if grep -q 'ARGUMENTS' "$c" && ! echo "$CFM" | grep -qE '^argument-hint:'; then
      warn "/$cname 用了 \$ARGUMENTS 但缺 argument-hint"
    fi
    if grep -qE "$SKILL_NAMES" "$c"; then
      ok "/$cname 指向了存在的 skill"
    else
      bad "/$cname 没有指向任何已知 skill"
    fi
  done
else
  warn "commands/ 不存在或为空，slash 命令缺失"
fi

# ---- 8. shell 语法 ----
while IFS= read -r -d '' sh; do
  if bash -n "$sh" 2>/dev/null; then
    ok "语法通过: ${sh#"$ROOT"/}"
  else
    bad "语法错误: $sh"
  fi
done < <(find . -name '*.sh' -print0)

# ---- 汇总 ----
echo "----------------------------------------"
echo "结果: [PASS] $PASS 项通过 | [FAIL] $FAIL 项失败 | [WARN] $WARN 项提醒"
if [ "$FAIL" -gt 0 ]; then
  echo "结论: 未通过"
  exit 1
else
  echo "结论: 通过"
  exit 0
fi
