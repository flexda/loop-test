#!/usr/bin/env bash
# check_done.sh 의 결정적 테스트. 모델을 호출하지 않으므로 비용이 없고 결과가 매번 같다.
# 판정 스크립트는 모델 평가가 아니라 이렇게 직접 시험하는 편이 정확하다.
# 사용법: bash harness-eval/tests/check_done_test.sh
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/.claude/skills/mvp-build-verify/scripts/check_done.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
PASS=0
FAIL=0

new_rubric() {
  rm -rf "$T/ws"; mkdir -p "$T/ws"
  cat > "$T/ws/rubric.md" <<'RUB'
# 루브릭
```json
{"threshold":85,"min_item":3,"criteria":[
 {"id":"functional","weight":40,"measure":"script"},
 {"id":"robustness","weight":20,"measure":"judge"},
 {"id":"scope","weight":15,"measure":"judge"},
 {"id":"simplicity","weight":15,"measure":"judge"},
 {"id":"docs","weight":10,"measure":"script"}]}
```
RUB
}
lock() { shasum -a 256 "$T/ws/rubric.md" > "$T/ws/rubric.sha256"; }
score() { # 반복 차단결함 functional robustness scope simplicity docs
  echo "{\"iteration\":$1,\"blocking_defects\":$2,\"criteria\":[{\"id\":\"functional\",\"score\":$3},{\"id\":\"robustness\",\"score\":$4},{\"id\":\"scope\",\"score\":$5},{\"id\":\"simplicity\",\"score\":$6},{\"id\":\"docs\",\"score\":$7}]}" > "$T/ws/05_score.json"
}
check() { # 이름 기대종료코드 기대출력접두사
  local out code
  out="$(bash "$SCRIPT" "$T/ws" 2>&1)"; code=$?
  if [ "$code" = "$2" ] && [ "${out%%:*}" = "$3" ]; then
    PASS=$((PASS+1)); echo "ok   $1"
  else
    FAIL=$((FAIL+1)); echo "FAIL $1 (exit=$code, out=$out)"
  fi
}

new_rubric;                                        check "잠금 없음은 ERROR"        3 ERROR
lock;                                              check "점수 파일 없음은 FAIL"    1 FAIL
score 1 0 5 5 5 5 5;                               check "만점은 PASS"              0 PASS
rm -f "$T/ws/score_history.txt"; score 1 0 5 4 5 4 3; check "총점 89, 항목 최저 3은 PASS" 0 PASS
rm -f "$T/ws/score_history.txt"; score 1 1 5 5 5 5 5; check "차단 결함 1은 FAIL"    1 FAIL
rm -f "$T/ws/score_history.txt"; score 1 0 5 5 5 5 2; check "항목 2점은 FAIL"       1 FAIL
rm -f "$T/ws/score_history.txt"; score 1 0 3 3 3 3 3; check "총점 60 반복 1은 FAIL"  1 FAIL
score 2 0 3 3 3 3 3;                               check "반복 2 같은 점수는 FAIL"  1 FAIL
score 3 0 3 3 3 3 3;                               check "2회 연속 미상승은 STUCK"  2 STUCK
rm -f "$T/ws/score_history.txt"; score 1 0 2 3 3 3 3; bash "$SCRIPT" "$T/ws" >/dev/null
score 2 0 3 3 3 3 3; bash "$SCRIPT" "$T/ws" >/dev/null
score 3 0 4 3 3 3 3;                               check "오르는 중은 FAIL"         1 FAIL
echo '{"iteration":9,"blocking_defects":0,"criteria":[{"id":"functional","score":5}]}' > "$T/ws/05_score.json"
check "항목 누락은 ERROR"                          3 ERROR
score 9 0 5 5 5 5 5; echo "변조" >> "$T/ws/rubric.md"
check "루브릭 변조는 ERROR"                        3 ERROR
lock; rm -f "$T/ws/score_history.txt"; score 1 0 5 5 5 5 5; bash "$SCRIPT" "$T/ws" >/dev/null
score 1 0 5 5 5 5 5; bash "$SCRIPT" "$T/ws" >/dev/null
if [ "$(wc -l < "$T/ws/score_history.txt" | tr -d ' ')" = "1" ]; then
  PASS=$((PASS+1)); echo "ok   같은 반복 번호는 이력에 한 번만 기록"
else
  FAIL=$((FAIL+1)); echo "FAIL 같은 반복 번호가 중복 기록됨"
fi

echo "---"
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" = "0" ]
