#!/usr/bin/env bash
# 평가용 플러그인 루트(harness-eval/mvp-harness)에서 claude plugin eval 을 실행하는 래퍼.
# 항상 같은 디렉터리에서 실행하고, 인자는 그대로 넘긴다.
# 사용 예:
#   bash harness-eval/run_eval.sh init --bare <케이스이름>     # 빈 케이스 틀 생성 (모델 호출 없음)
#   bash harness-eval/run_eval.sh . --runs 1 --ablation none   # 케이스 실행 (모델 호출 있음, 비용 발생)
set -eu
cd "$(dirname "$0")/mvp-harness"
exec claude plugin eval "$@"
