# 과정 아카이브: 빠른 메모 MVP (2026-10-06)

## 개요
mvp 하네스를 구축하고, ralph-loop로 메모 앱 MVP를 아이디어에서 동작 확인까지 만든 과정의 기록이다.

## 타임라인
1. grill-me 스킬 설치. mattpocock/skills 저장소의 grill-me와 grilling을 ~/.claude/skills/에 복사했다.
2. harness 스킬로 MVP 하네스 구축. 에이전트 4개(mvp-planner, mvp-architect, mvp-builder, mvp-qa, 모두 opus)와 스킬 3개(mvp-orchestrator, mvp-scoping, mvp-build-verify), CLAUDE.md 호출 조건을 만들었다. 사용자 선택: 범용 MVP, 아이디어에서 동작 확인까지, 인터뷰 단계 포함.
3. ralph-loop 플러그인 설치(ralph-loop@claude-plugins-official). Stop hook이 같은 프롬프트를 되먹이는 방식이다.
4. ralph-loop 실행. 설정: 메모 앱, 인터뷰 생략(기본값 사용), 최대 8회, 완료 문구 COMPLETE. 반복 3회차에 완료했다.
5. 단계별 진행
   - 00 인터뷰: 오케스트레이터가 기본값으로 직접 작성
   - 01 범위 확정: mvp-planner. 포함 4개, 성공 기준 8개
   - 02 설계: mvp-architect. Node 내장 모듈만 사용, 작업 4개
   - 03 구현: mvp-builder. 작업 1 먼저 확인 후 작업 2~4 진행
   - 04 검증: mvp-qa. headless Chrome으로 8개 기준 모두 통과, 차단 결함 없음
6. 완료 확인: npm test 5개 통과를 오케스트레이터가 직접 재실행해 확인한 뒤 완료 문구를 출력했다.

## 결정과 이탈
- 인터뷰를 생략했으므로 웹 페이지 형태, 최신순 정렬, 빈 입력 무시는 확인받지 않은 가정이다.
- 설계서의 test 스크립트 node --test test/ 는 Node 22에서 실패해 node --test test/*.test.js 로 바꿨다.
- 빌더는 작업 1에서 404 처리를 범위보다 조금 앞서 넣었다.
- 프로젝트의 docs/mmca-exhibition-api.md 는 이 작업에서 만든 파일이 아니다.

## 남은 일
- QA 참고 결함: README에 PORT, DATA_FILE, 종료 방법 설명 없음. 화면이 POST 응답 코드를 확인하지 않음.
- 미확인: 사람이 직접 브라우저에서 해 본 확인, Chrome 외 브라우저.
- 하네스 자체는 호출 조건 테스트(경계 사례)를 하지 않았다. 필요하면 harness:evolve로 개선한다.

## 구성
- workspace/: 단계별 산출물(00~04) 사본. 원본은 프로젝트 루트의 _workspace/에도 남아 있다.
- harness/: 이 시점의 에이전트, 스킬, CLAUDE.md 사본
