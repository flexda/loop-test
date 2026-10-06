# 하네스 시험 (harness-eval)

MVP 하네스(`.claude/`의 스킬과 에이전트)가 의도대로 호출되고 동작하는지 시험하는 폴더다.

## 구성

| 경로 | 역할 |
| --- | --- |
| `mvp-harness/` | `claude plugin eval`이 요구하는 플러그인 형태의 복사본. 직접 고치지 않는다 |
| `mvp-harness/evals/` | 시험 케이스 6개 (모델 호출이 드는 시험) |
| `sync.sh` | `.claude/`의 원본을 `mvp-harness/`로 복사한다. 하네스를 고친 뒤 시험 전에 실행한다 |
| `run_eval.sh` | `mvp-harness/`에서 `claude plugin eval`을 실행하는 래퍼 |
| `tests/check_done_test.sh` | 판정 스크립트의 결정적 테스트 (모델 호출 없음, 비용 없음) |

원본은 항상 `.claude/`다. 평가용 복사본이 필요한 이유는, 플러그인이 자기 디렉터리 밖의 파일을 구성요소로 선언할 수 없기 때문이다.

## 케이스

| 케이스 | 확인하는 것 |
| --- | --- |
| `trigger-mvp-request` | MVP 제작 요청에 오케스트레이터가 호출되고 인터뷰로 시작하는가 |
| `ignore-small-fix` | 한 줄 수정 요청에 오케스트레이터가 호출되지 않는가 (경계 사례) |
| `ignore-general-question` | 일반 개념 질문에 오케스트레이터가 호출되지 않는가 (경계 사례) |
| `no-eval-without-rubric` | 승인된 루브릭이 없으면 점수를 지어내지 않고 선행 단계를 안내하는가 |
| `loop-command-uses-goal` | 루프 시작 명령을 /goal 기본으로, check_done.sh 출력 기준의 종료 조건과 함께 안내하는가 |
| `rubric-format` | 루브릭 초안이 형식(항목 4~6개, 가중치 합 100, 측정 방식, 3점과 5점 기준, functional)을 지키는가 |

## 실행

```
bash harness-eval/sync.sh
bash harness-eval/tests/check_done_test.sh
bash harness-eval/run_eval.sh . --runs 1 --ablation none --max-cost-usd 2 --trust-plugin --no-publish
```

- 위 세 번째 명령은 모델을 호출하므로 비용이 든다. 케이스 6개를 1회씩 한 쪽 팔로 돌리면 약 0.7달러(목록가 추정)였다.
- `--runs`를 생략하면 케이스당 3회씩, 플러그인이 있을 때와 없을 때 두 팔로 돌려서 비용이 약 6배가 된다. 점수가 흔들리므로 판단은 3회 이상으로 한다.
- 스킬 호출 여부(`tool_used: Skill`) 채점기는 두 팔 실행에서 점수에 들어가지 않고 표시로만 나온다.
- 응답 본문을 보려면 `--keep-temp`를 붙이고, 출력된 경로의 `out/trace.jsonl`을 읽는다.
