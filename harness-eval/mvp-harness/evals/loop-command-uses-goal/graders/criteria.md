---
type: llm
weight: 2
---

PASS if 응답이 /goal 로 시작하는 복사 가능한 명령을 기본으로 제시하고, 그 종료 조건이 check_done.sh 의 출력(PASS, STUCK, ERROR)에 근거하며, check_done.sh 출력 전문을 대화에 남기라는 지시와 턴 상한이 들어 있다.
FAIL if 응답이 완료 문구(promise) 문자열 일치만으로 끝나는 명령을 기본으로 제시하거나, 점수나 판정 기준 없이 "다 되면 끝"처럼 모호한 종료 조건을 쓴다.
