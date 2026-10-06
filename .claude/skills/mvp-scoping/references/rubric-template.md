# 루브릭 템플릿

루브릭은 빌드가 시작되기 전에 사용자가 승인하고 고정한다. 빌드 도중 기준이 바뀌면 낮은 점수를 피하려고 기준을 낮추는 길이 열리므로, 승인 후에는 해시로 잠그고 어떤 에이전트도 수정하지 못한다.

## 항목 설계 원칙

- 항목은 4~6개로 한다. 많아지면 가중치가 흐려지고 평가 비용만 늘어난다.
- 가중치 합은 정확히 100이다.
- 항목마다 측정 방식을 정한다. `script`는 명령을 실행해 결과로 매기는 항목(테스트 통과 수, 실행 성공, 의존성 수), `judge`는 평가자가 근거를 적고 점수를 매기는 항목이다. 가능한 항목은 `script`로 둔다. 판단이 개입할수록 점수가 흔들린다.
- 점수는 0~5 정수이고, 항목마다 3점과 5점이 무엇인지 한 줄로 적는다. 기준이 없으면 평가자마다 점수가 달라진다.
- 스펙의 성공 기준은 `functional` 항목 하나로 묶고, 하나라도 실패하면 차단 결함으로 센다.

## rubric.md 형식

rubric.md는 사람이 읽는 설명과 기계가 읽는 JSON 블록 하나로 구성한다. `check_done.sh`는 첫 번째 ```json 블록만 읽는다.

````
# 루브릭: {프로젝트명}

## 항목 설명
- functional (40, script): 3점 = 성공 기준의 절반 이상 통과, 5점 = 전부 통과
- robustness (20, judge): 3점 = 흔한 이상 입력에서 죽지 않음, 5점 = 오류가 사용자에게 안내됨
- scope (15, judge): 3점 = 제외 항목 1개 침범, 5점 = 침범 없음
- simplicity (15, judge): 3점 = 불필요한 구성요소 1~2개, 5점 = 필요한 것만 있음
- docs (10, script): 3점 = 실행 방법만 있음, 5점 = 실행, 테스트, 종료, 환경 변수가 있음

```json
{
  "threshold": 85,
  "min_item": 3,
  "criteria": [
    {"id": "functional", "weight": 40, "measure": "script"},
    {"id": "robustness", "weight": 20, "measure": "judge"},
    {"id": "scope", "weight": 15, "measure": "judge"},
    {"id": "simplicity", "weight": 15, "measure": "judge"},
    {"id": "docs", "weight": 10, "measure": "script"}
  ]
}
```
````

## 05_score.json 형식

평가자(mvp-qa)가 쓴다. `total`은 적지 않는다. 합산은 `check_done.sh`가 루브릭의 가중치로 직접 계산한다. 평가자가 합계를 조작하거나 계산 실수를 하는 길을 없애기 위해서다.

```json
{
  "iteration": 1,
  "blocking_defects": 0,
  "criteria": [
    {"id": "functional", "score": 5, "evidence": "성공 기준 8개를 실행해 8개 통과"}
  ],
  "unverified": ["사람이 직접 브라우저에서 확인"]
}
```
