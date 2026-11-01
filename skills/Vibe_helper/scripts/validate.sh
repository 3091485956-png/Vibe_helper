#!/usr/bin/env bash
# Vibe_helper 交付包机器自检
# 用法: bash scripts/validate.sh <产品目录> [--expect 交付包]
#   默认模式:   校验已存在的产出物, 缺失的文档只提醒
#   --expect 交付包: 01-07 全部文档 + prototypes/ 必须齐全;
#                    AI 轨道另需 08-评测方案 + badcase台账.md
# 退出码: 0 = 全部通过, 1 = 存在必须修复的问题

set -u

DIR="${1:-}"
EXPECT=""
if [ "${2:-}" = "--expect" ]; then
  EXPECT="${3:-交付包}"
fi

PASS=0; FAIL=0; WARN=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN+1)); }

if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
  echo "用法: bash scripts/validate.sh <产品目录> [--expect 交付包]"
  echo "未找到目录: ${DIR:-（未提供）}"
  exit 1
fi

echo "检查目录: $DIR"
echo "----------------------------------------"

# ---- 0. AI 轨道判定（00/02/05 提及，或 08 已存在）----
AI_TRACK=0
for f in "00-状态.md" "02-brief.md" "05-需求分层.md"; do
  p="$DIR/$f"
  if [ -f "$p" ] && grep -q "AI 轨道" "$p"; then AI_TRACK=1; fi
done
[ -f "$DIR/08-评测方案.md" ] && AI_TRACK=1
if [ "$AI_TRACK" -eq 1 ]; then
  echo "AI 轨道: 是（08-评测方案 / 能力边界 / badcase 台账 按 AI 规则检查）"
else
  echo "AI 轨道: 否"
fi

# 模糊词黑名单（对应 references/requirements-layering.md 的反例）
VAGUE='好用|流畅|快速|美观|优雅|体验好|响应快|高大上|完美|丝滑|良好|准时'

# ---- 1. 阶段文档齐全且非空 ----
DOCS=("01-问卷.md" "02-brief.md" "03-竞品分析.md" "04-用户声音.md" "05-需求分层.md" "06-产品框架.md" "07-技术框架.md")
for f in "${DOCS[@]}"; do
  p="$DIR/$f"
  if [ -f "$p" ]; then
    if [ "$(wc -c < "$p")" -lt 200 ]; then
      bad "$f 内容太薄（<200 字节），不像认真产出"
    else
      ok "$f 存在且非空"
    fi
  else
    if [ "$EXPECT" = "交付包" ]; then
      bad "缺 $f（交付包模式必需）"
    else
      warn "尚未产出 $f"
    fi
  fi
done

# ---- 1.5 版本头与状态卡（00-状态.md）----
for f in "${DOCS[@]}" "00-状态.md"; do
  p="$DIR/$f"
  [ -f "$p" ] || continue
  # 模式不带头部的 📌 emoji: GNU grep 3.x 对 4 字节 UTF-8 + 字符组的组合有已知 bug
  if grep -qE '版本 v[0-9]+' "$p"; then
    ok "$f 含版本头"
  else
    bad "$f 缺版本头（应为：📌 版本 vN · 日期 · 变更）"
  fi
done

STATE="$DIR/00-状态.md"
if [ -f "$STATE" ]; then
  ok "00-状态.md 存在"
  MANIFEST=$(grep -m1 -oE '组装自: [^·]+' "$STATE" | sed 's/组装自: *//' | tr -d ' ')
  if [ -n "$MANIFEST" ]; then
    OLDIFS=$IFS
    IFS=','
    for pair in $MANIFEST; do
      doc="${pair%@*}"
      mv="${pair#*@}"; mv="${mv#v}"
      pp="$DIR/$doc.md"
      if [ ! -f "$pp" ]; then
        warn "组装清单引用的 $doc 不存在（可能改名，建议重组装）"
        continue
      fi
      cv=$(grep -m1 -oE '版本 v[0-9]+' "$pp" | grep -oE '[0-9]+')
      case "$mv" in ''|*[!0-9]*) continue ;; esac
      case "$cv" in ''|*[!0-9]*) continue ;; esac
      if [ "$cv" -gt "$mv" ]; then
        bad "00-状态.md 过期：$doc 已 v$cv，组装清单仍是 @$mv——先重组装再继续"
      elif [ "$mv" -gt "$cv" ]; then
        warn "组装清单记录 $doc@$mv 高于实际 v$cv（版本头疑似未更新）"
      else
        ok "组装清单一致：$doc@v$cv"
      fi
    done
    IFS=$OLDIFS
  else
    bad "00-状态.md 缺组装清单（组装自: 01@v1, …）"
  fi
  # 05 功能 ID 与 00 Must ID 集合一致性
  if [ -f "$DIR/05-需求分层.md" ]; then
    ids05=$(grep -oE 'M-F[0-9]+' "$DIR/05-需求分层.md" | sort -u)
    ids00=$(grep -oE 'M-F[0-9]+' "$STATE" | sort -u)
    if [ -n "$ids05" ]; then
      if [ -z "$ids00" ]; then
        bad "05 已用功能 ID（M-F*）但 00-状态.md 的 Must 清单没有同步——状态卡过期"
      elif [ "$ids05" = "$ids00" ]; then
        ok "05 功能 ID 与 00 Must ID 一致（$(echo "$ids05" | wc -l) 个）"
      else
        bad "05 功能 ID 与 00 Must ID 不一致——状态卡与需求文档漂移"
      fi
    fi
  fi
else
  if [ "$EXPECT" = "交付包" ]; then
    bad "缺 00-状态.md（交付包模式必需）"
  elif [ -f "$DIR/05-需求分层.md" ]; then
    warn "已有 05 但缺 00-状态.md，建议组装（状态卡是主上下文与交接首材料）"
  fi
fi

# ---- 2. 03-竞品分析: 🔶 对标选择点必须走完 ----
if [ -f "$DIR/03-竞品分析.md" ]; then
  if grep -q "确认对标集合" "$DIR/03-竞品分析.md"; then
    ok "03 含『确认对标集合』（对标已过用户确认）"
  else
    bad "03 缺『确认对标集合』小节——🔶 对标选择点没走完"
  fi
fi

# ---- 3. 调研文档必须写『待核实清单』（证据分级纪律强制）----
for f in "03-竞品分析.md" "04-用户声音.md"; do
  p="$DIR/$f"
  if [ -f "$p" ]; then
    if grep -q "待核实清单" "$p"; then
      ok "$f 含『待核实清单』（盲区 + 推测，一个出口）"
    elif grep -q "本轮盲区" "$p"; then
      warn "$f 只有旧版『本轮盲区』——升级为『待核实清单』（盲区+推测合并，推测须附验证路径）"
    else
      bad "$f 缺『待核实清单』小节（证据分级纪律强制）"
    fi
  fi
done

# ---- 4. 04-用户声音: 应含需求真伪初判 ----
if [ -f "$DIR/04-用户声音.md" ]; then
  if grep -qE "真伪初判|需求真伪" "$DIR/04-用户声音.md"; then
    ok "04 含『需求真伪初判』"
  else
    warn "04 疑似缺『需求真伪初判』小节"
  fi
fi

# ---- 5. 02-brief 应有边界小节 ----
if [ -f "$DIR/02-brief.md" ]; then
  if grep -q "不做" "$DIR/02-brief.md"; then
    ok "02-brief 含『明确不做』边界"
  else
    warn "02-brief 疑似缺『明确不做』边界小节"
  fi
  # AI 轨道: 能力边界必填
  if [ "$AI_TRACK" -eq 1 ]; then
    if grep -q "能力边界" "$DIR/02-brief.md"; then
      ok "02-brief 含『能力边界』（AI 轨道：适用域/水平线/不保证）"
    else
      if [ "$EXPECT" = "交付包" ]; then
        bad "AI 轨道但 02-brief 缺『能力边界』小节"
      else
        warn "AI 轨道但 02-brief 暂缺『能力边界』小节（Stage 2 应写入）"
      fi
    fi
  fi
  # 委托模式: 代定留痕（M10）
  if grep -qE "决策模式：委托|决策模式: 委托" "$DIR/02-brief.md"; then
    if grep -q "代定" "$DIR/02-brief.md"; then
      ok "委托模式：Brief 含 [B/C·代定] 留痕"
    else
      bad "委托模式但 Brief 无 [B/C·代定] 标注——委托必须留痕（M10）"
    fi
  fi
fi

# ---- 5.5 决策面板（02–08 第一屏，双阅读模式）----
for f in "02-brief.md" "03-竞品分析.md" "04-用户声音.md" "05-需求分层.md" "06-产品框架.md" "07-技术框架.md" "08-评测方案.md"; do
  p="$DIR/$f"
  [ -f "$p" ] || continue
  if head -50 "$p" | grep -q "决策面板"; then
    ok "$f 第一屏含决策面板（30 秒拍板层）"
  else
    if [ "$EXPECT" = "交付包" ]; then
      bad "$f 缺第一屏决策面板——用户点开看不到要判断什么"
    else
      warn "$f 疑似缺第一屏决策面板"
    fi
  fi
done

# ---- 6. 05-需求分层: Must 结构 + Gherkin 验收场景质量 ----
REQ="$DIR/05-需求分层.md"
if [ -f "$REQ" ]; then
  if grep -qE "MVP 范围|Must have" "$REQ"; then
    ok "05 含 MVP（Must have）范围小节"
  else
    bad "05 缺 MVP（Must have）范围小节"
  fi

  if grep -qE "本期不做|Won.t have" "$REQ"; then
    ok "05 含『本期不做（Won't have）』边界"
  else
    bad "05 缺『本期不做（Won't have）』——边界和 Must 一样重要"
  fi

  # 每条 Must 用户故事的验收场景计数（支持 Gherkin 场景式与旧版平铺式）
  # 故事以非缩进的『- 验收标准』行开始；其下缩进列表项为验收内容：
  #   『- 场景…』计一个场景；『- Given/When/Then』为场景步骤；其余计为一条普通 AC
  # 输出两列: 故事数、每故事最少验收条数（普通 AC + 场景数合计）
  STATS=$(awk '
    /^[-*][[:space:]]*验收标准/ { story++; inac=1; next }
    inac && /^[[:space:]]+[-*][[:space:]]*场景/ { scen[story]++; next }
    inac && /^[[:space:]]+[-*][[:space:]]*(Given|When|Then)[[:space:]]/ { next }
    inac && /^[[:space:]]+[-*][[:space:]]/ { cnt[story]++; next }
    inac && /^[-*][[:space:]]/ { inac=0; next }
    /^#/ { inac=0 }
    END {
      min = 999999; n = story + 0
      for (s = 1; s <= n; s++) {
        tot = cnt[s] + scen[s]
        if (tot > 0 && tot < min) min = tot
      }
      printf "%d %d\n", n, (min==999999?0:min)
    }' "$REQ")
  GWT=$(awk '
    /^[-*][[:space:]]*验收标准/ { inac=1 }
    inac && /^[[:space:]]+[-*][[:space:]]*(Given|When|Then)[[:space:]]/ { c++ }
    inac && /^[-*][[:space:]]/ && $0 !~ /^[-*][[:space:]]*验收标准/ { inac=0 }
    /^#/ { inac=0 }
    END { print c + 0 }' "$REQ")
  STORY=$(echo "$STATS" | awk '{print $1}')
  MINAC=$(echo "$STATS" | awk '{print $2}')
  if [ "${STORY:-0}" -ge 1 ]; then
    ok "05 共 ${STORY} 条带验收标准的 Must 故事"
    if [ "${MINAC:-0}" -lt 2 ]; then
      bad "存在验收标准不足 2 条的 Must 故事（最少的一条只有 ${MINAC} 条/场景）"
    else
      ok "每条 Must 故事验收标准 ≥2（最少 ${MINAC}）"
    fi
    if [ "${GWT:-0}" -gt 0 ]; then
      ok "验收标准含 Gherkin 步骤（Given/When/Then 共 ${GWT} 行）"
    fi
  else
    bad "05 没有解析到『- 验收标准』块——Must 故事缺失或格式不对"
  fi

  # 验收标准里的模糊词
  ACLINES=$(awk '
    /^[-*][[:space:]]*验收标准/ { inac=1; next }
    inac && /^[[:space:]]+[-*][[:space:]]/ { print; next }
    inac && /^[-*][[:space:]]/ { inac=0; next }
    /^#/ { inac=0 }' "$REQ")
  if [ -n "$ACLINES" ]; then
    HITS=$(printf '%s\n' "$ACLINES" | grep -nE "$VAGUE" | head -3 | tr '\n' ' ')
    if [ -n "$HITS" ]; then
      bad "验收标准含模糊词（无法判断做完没）: $HITS"
    else
      ok "验收标准无模糊词"
    fi
  fi
fi

# ---- 7. prototypes/: 入口 + 死链 ----
if [ -d "$DIR/prototypes" ]; then
  if [ -f "$DIR/prototypes/index.html" ]; then
    ok "prototypes/index.html 入口存在"
  else
    bad "prototypes/ 缺入口 index.html"
  fi

  DEAD=0
  TOTAL=0
  while IFS= read -r -d '' html; do
    [ "$(wc -c < "$html")" -lt 100 ] && { bad "$(basename "$html") 内容太薄"; continue; }
    base=$(dirname "$html")
    refs=$(grep -oE '(href|src)="[^"]+"' "$html" 2>/dev/null | sed -E 's/^(href|src)="//; s/"$//')
    while IFS= read -r r; do
      case "$r" in
        ""|\#*|http://*|https://*|mailto:*|data:*|javascript:*|tel:*) continue ;;
      esac
      r="${r%%\#*}"
      [ -z "$r" ] && continue
      TOTAL=$((TOTAL+1))
      if [ ! -e "$base/$r" ]; then
        echo "    -> 死链: $r （在 $(basename "$html")）"
        DEAD=$((DEAD+1))
      fi
    done <<< "$refs"
  done < <(find "$DIR/prototypes" -name '*.html' -print0)

  if [ "$DEAD" -gt 0 ]; then
    bad "原型存在 ${DEAD} 个死链（本地产能跳转的文件不存在）"
  else
    ok "原型内链检查通过（共 ${TOTAL} 个本地产能引用）"
  fi
else
  if [ "$EXPECT" = "交付包" ]; then
    bad "缺 prototypes/ 目录（交付包模式必需）"
  else
    warn "尚未产出 prototypes/"
  fi
fi

# ---- 8. AI 轨道: 08-评测方案 结构 + badcase 台账 ----
if [ "$AI_TRACK" -eq 1 ]; then
  EVAL="$DIR/08-评测方案.md"
  if [ -f "$EVAL" ]; then
    ok "08-评测方案.md 存在"
    for kw in "评测用例表" "期望输出" "冒烟子集"; do
      if grep -q "$kw" "$EVAL"; then
        ok "08 含『$kw』"
      else
        bad "08 缺『$kw』——评测方案结构不完整"
      fi
    done
    if grep -qE "通过线|通过率" "$EVAL"; then
      ok "08 含通过线/通过率（评测有门槛）"
    else
      bad "08 缺通过线——没有门槛的评测等于没评测"
    fi
  else
    if [ "$EXPECT" = "交付包" ]; then
      bad "AI 轨道但缺 08-评测方案.md（交付包模式必需）"
    else
      warn "AI 轨道：08-评测方案.md 尚未产出（Stage 6 应产出）"
    fi
  fi

  LEDGER="$DIR/badcase台账.md"
  if [ -f "$LEDGER" ]; then
    ok "badcase台账.md 已创建（随包交付）"
    if grep -q "归因" "$LEDGER"; then
      ok "台账含归因分诊表"
    else
      bad "台账缺归因分诊表（模板见 badcase-ledger.md）"
    fi
    if grep -q "回灌" "$LEDGER"; then
      ok "台账含回灌规则"
    else
      bad "台账缺回灌规则——未回灌不得关闭（M9）"
    fi
  else
    if [ "$EXPECT" = "交付包" ]; then
      bad "AI 轨道但缺 badcase台账.md（Stage 8 交接必留）"
    fi
  fi
fi

# ---- 汇总 ----
echo "----------------------------------------"
echo "结果: [PASS] $PASS 项通过 | [FAIL] $FAIL 项失败 | [WARN] $WARN 项提醒"
if [ "$FAIL" -gt 0 ]; then
  echo "结论: 未通过——FAIL 项修复前，对应 ⛔ 门不放行"
  exit 1
else
  echo "结论: 通过"
  exit 0
fi
