#!/usr/bin/env bash
# 완료 판정 스크립트. 점수 파일과 루브릭만 읽어 PASS/FAIL/STUCK을 출력한다.
# 판단이 개입하지 않게 하려는 것이 목적이다: 완료 문구는 이 스크립트가 PASS를 출력할 때만 낼 수 있다.
# 사용법: check_done.sh [워크스페이스 디렉터리 (기본 _workspace)]
# 종료 코드: 0 PASS, 1 FAIL, 2 STUCK, 3 ERROR
set -u
WS="${1:-_workspace}"
RUBRIC="$WS/rubric.md"
LOCK="$WS/rubric.sha256"
SCORE="$WS/05_score.json"
HIST="$WS/score_history.txt"

err() { echo "ERROR: $1"; exit 3; }

command -v jq >/dev/null 2>&1 || err "jq 가 필요하다. which jq 로 설치 여부를 확인한다."
[ -f "$RUBRIC" ] || err "$RUBRIC 이 없다. 루브릭을 만들고 사용자 승인을 받은 뒤 시작한다."
[ -f "$LOCK" ] || err "$LOCK 이 없다. 루브릭이 승인되어 잠기지 않았다."

# 잠금 검사: 승인 이후 루브릭이 바뀌었으면 점수를 믿을 수 없다.
NOW=$(shasum -a 256 "$RUBRIC" | awk '{print $1}')
WANT=$(awk '{print $1}' "$LOCK")
[ "$NOW" = "$WANT" ] || err "루브릭이 승인 이후 변경되었다. 되돌리거나 사용자에게 다시 승인받는다."

# 루브릭의 첫 번째 json 블록만 읽는다.
RJ=$(awk '/^```json/{f=1;next} /^```/{if(f){exit}} f' "$RUBRIC")
echo "$RJ" | jq -e '.threshold and .min_item and (.criteria|length>0)' >/dev/null 2>&1 \
  || err "루브릭의 json 블록을 읽을 수 없다."
SUMW=$(echo "$RJ" | jq '[.criteria[].weight]|add')
[ "$SUMW" = "100" ] || err "가중치 합이 100이 아니다 ($SUMW)."

[ -f "$SCORE" ] || { echo "FAIL: 점수 파일($SCORE)이 아직 없다. 평가를 먼저 실행한다."; exit 1; }
jq -e . "$SCORE" >/dev/null 2>&1 || err "점수 파일이 올바른 JSON이 아니다."

# 루브릭의 모든 항목에 0~5 정수 점수가 있어야 한다.
MISSING=$(jq -rn --argjson r "$RJ" --slurpfile s "$SCORE" '
  [ $r.criteria[].id as $id
    | ($s[0].criteria // [] | map(select(.id==$id)) | first) as $c
    | select($c==null or ($c.score|type)!="number" or $c.score<0 or $c.score>5 or ($c.score|floor)!=$c.score)
    | $id ] | join(",")')
[ -z "$MISSING" ] || err "점수가 없거나 0~5 정수가 아닌 항목: $MISSING"

RESULT=$(jq -n --argjson r "$RJ" --slurpfile s "$SCORE" '
  ($s[0].criteria) as $sc
  | [ $r.criteria[] | . as $c | {id:$c.id, weight:$c.weight, score:($sc|map(select(.id==$c.id))|first|.score)} ] as $items
  | { total: ([$items[] | .weight * .score / 5] | add),
      min: ([$items[].score] | min),
      lowest: ($items | sort_by(.score) | map(select(.score == ($items|map(.score)|min))) | map(.id) | join(",")),
      blocking: ($s[0].blocking_defects // 0),
      iteration: ($s[0].iteration // 0) }')
TOTAL=$(echo "$RESULT" | jq -r '.total')
MIN=$(echo "$RESULT" | jq -r '.min')
LOWEST=$(echo "$RESULT" | jq -r '.lowest')
BLOCK=$(echo "$RESULT" | jq -r '.blocking')
ITER=$(echo "$RESULT" | jq -r '.iteration')
TH=$(echo "$RJ" | jq -r '.threshold')
MINITEM=$(echo "$RJ" | jq -r '.min_item')

# 이력: 같은 반복 번호는 한 번만 기록한다.
touch "$HIST"
LASTITER=$(tail -n 1 "$HIST" | awk '{print $1}')
[ "$LASTITER" = "$ITER" ] || echo "$ITER $TOTAL" >> "$HIST"

OK=$(jq -n --argjson t "$TOTAL" --argjson th "$TH" --argjson m "$MIN" --argjson mi "$MINITEM" --argjson b "$BLOCK" \
  '($t>=$th) and ($m>=$mi) and ($b==0)')
if [ "$OK" = "true" ]; then
  echo "PASS: 총점 $TOTAL (기준 $TH 이상), 차단 결함 $BLOCK, 항목 최저 $MIN (기준 $MINITEM 이상)"
  exit 0
fi

# 정체 검사: 최근 3회 기록에서 점수가 2회 연속 오르지 않았으면 멈춘다.
if [ "$(wc -l < "$HIST" | tr -d ' ')" -ge 3 ]; then
  STUCK=$(tail -n 3 "$HIST" | awk '{a[NR]=$2} END{print (a[2]<=a[1] && a[3]<=a[2]) ? "yes" : "no"}')
  if [ "$STUCK" = "yes" ]; then
    echo "STUCK: 점수가 2회 연속 오르지 않았다 (총점 $TOTAL). _workspace/stuck.md 에 원인과 시도 내용을 적고 멈춘다."
    exit 2
  fi
fi

echo "FAIL: 총점 $TOTAL (기준 $TH), 차단 결함 $BLOCK, 항목 최저 $MIN (기준 $MINITEM). 가장 낮은 항목: $LOWEST"
exit 1
