# 설계: 빠른 메모 MVP

입력: `_workspace/01_planner_spec.md`

## 1. 스택과 선택 이유

| 영역 | 선택 | 이유 |
| --- | --- | --- |
| 런타임 | Node.js v22 (`/Users/reflectdata/.local/bin/node`, v22.22.3 확인) | 이미 설치되어 있고, 내장 모듈만으로 HTTP 서버, 파일 저장, 테스트가 모두 된다. |
| 웹 서버 | `node:http` 내장 모듈 | 라우트가 3개뿐이라 Express 같은 프레임워크가 필요 없다. `npm install` 단계가 사라진다. |
| 저장 | JSON 파일 1개 (`data/memos.json`), `node:fs` | 설정이 필요 없다. `node:sqlite`는 v22에서 실험 기능 경고가 출력되고, 단일 사용자 추가/조회만 하는 MVP에는 파일로 충분하다. |
| 화면 | 정적 HTML 1개 + 인라인 바닐라 JS (`fetch`) | 빌드 도구가 필요 없다. 페이지 이동 없이 목록을 갱신한다(성공 기준 2). |
| 테스트 | `node:test` + `node:assert` + 전역 `fetch` (`node --test`) | 내장 기능이라 설치가 없다. 서버를 자식 프로세스로 띄워 재시작까지 검증할 수 있다. |
| 실행 명령 | `npm start` (= `node server.js`) | 성공 기준 1의 "실행 명령 하나". npm은 스크립트 실행용으로만 쓰며 의존성은 0개다. |

사용하지 않는 것: 외부 npm 패키지, python3/uv(이 설계에서는 필요 없음), 인증, 배포, 빌드 도구, 브라우저 자동화 도구(설치 금지이므로 브라우저 확인은 사람이 하거나 HTTP 수준 테스트로 대체).

## 2. 파일 구조

```
loop-test/
  package.json        # name, "type": "module", scripts: start, test. dependencies 없음
  server.js           # HTTP 서버, 라우팅, 저장 함수
  public/
    index.html        # 입력란, 추가 버튼, 목록 영역, 인라인 스크립트
  data/
    memos.json        # 런타임에 자동 생성 (git 제외)
  test/
    app.test.js       # node:test 기반 통합 테스트
  .gitignore          # data/
  README.md           # 실행 명령과 테스트 명령
```

## 3. 데이터 모델

`data/memos.json`은 메모 객체 배열이다. 추가된 순서(오래된 것 먼저)로 저장하고, 응답할 때 뒤집어 최신이 맨 앞에 오게 한다.

```json
[
  { "id": 1, "text": "테스트 메모 1", "createdAt": "2026-10-06T07:00:00.000Z" }
]
```

- `id`: 정수, 현재 최댓값 + 1. 같은 밀리초에 추가돼도 순서가 정해지도록 시각 대신 id로 순서를 판단한다.
- `text`: 앞뒤 공백을 제거(`trim`)한 문자열. 비어 있으면 저장하지 않는다.
- `createdAt`: ISO 문자열. 화면에는 표시하지 않는다(스펙 "나중에" 항목). 나중 기능을 위해 저장만 한다.

저장 규칙:
- 파일이 없으면 빈 배열로 간주하고, 첫 쓰기 때 `data/` 디렉터리와 파일을 만든다.
- 쓰기는 임시 파일(`memos.json.tmp`)에 쓴 뒤 `rename`으로 교체해 중간에 프로세스가 죽어도 파일이 깨지지 않게 한다.
- 매 요청마다 파일을 읽는다(메모리 캐시 없음). 단일 사용자 MVP라 성능 문제가 없고, 재시작 후 일관성이 자명하다.
- 저장 경로는 환경 변수 `DATA_FILE`로 바꿀 수 있다(기본 `data/memos.json`). 테스트가 실제 데이터를 건드리지 않게 하기 위함이다.

## 4. HTTP 인터페이스

포트: 환경 변수 `PORT`, 기본 3000. 시작 시 `http://localhost:<PORT>` 를 콘솔에 출력한다.

| 메서드 경로 | 요청 | 응답 |
| --- | --- | --- |
| `GET /` | - | `200`, `public/index.html` (text/html; charset=utf-8) |
| `GET /api/memos` | - | `200`, JSON 배열, 최신 메모가 맨 앞 |
| `POST /api/memos` | JSON `{ "text": "..." }` | 정상: `201`, 생성된 메모 객체. `text`가 없거나 trim 후 빈 문자열: `400`, `{ "error": "empty" }`, 저장하지 않음. 본문이 JSON이 아니면 `400`. |
| 그 외 | - | `404` |

## 5. 화면 동작 (`public/index.html`)

- 요소: `<form id="memo-form">` 안에 `<input id="memo-input" type="text">`, `<button type="submit">추가</button>`, 그 아래 `<ul id="memo-list">`.
- form의 submit 이벤트를 쓰므로 버튼 클릭과 Enter 모두 같은 경로로 처리된다(흐름 3단계).
- 페이지 로드 시 `GET /api/memos`로 목록을 그린다(성공 기준 6, 7).
- submit 시 `preventDefault` 후, 입력값을 trim해서 비어 있으면 아무것도 하지 않는다(클라이언트 1차 방어, 서버 400이 2차 방어. 성공 기준 5).
- `POST` 성공 후 입력란을 비우고(성공 기준 3) 목록을 다시 불러와 그린다(성공 기준 2, 4).
- 목록 항목은 `textContent`로 넣어 HTML 주입을 막는다.
- 스타일링은 넣지 않는다(스펙 제외 항목).

## 6. 실행 방법

```
cd /Users/reflectdata/Project/loop-test
npm start                 # http://localhost:3000 을 브라우저로 연다
npm test                  # node --test test/
```

설치 단계 없음(`npm install` 불필요, 의존성 0개).

## 7. 성공 기준 대응표

| 성공 기준 | 담당 부분 | 확인 작업 번호 |
| --- | --- | --- |
| 1. 명령 하나로 실행, 입력란/버튼/목록 보임 | `npm start`, `GET /`, index.html 요소 | 1, 4 |
| 2. 추가하면 목록에 나타남 | `POST`, 클라이언트 재렌더 | 1, 4 |
| 3. 추가 후 입력란 비움 | 클라이언트 | 1, 4 |
| 4. 두 개 추가, 최신이 맨 위 | `GET` 역순 응답 | 2, 4 |
| 5. 빈 입력 무시 | 클라이언트 trim + 서버 400 | 2, 4 |
| 6. 새로고침 후 유지 | 파일 저장 + 로드 시 GET | 1, 3, 4 |
| 7. 재시작 후 유지 | 파일 저장 | 1, 3, 4 |
| 8. node/npm만 사용, 설치 없음 | 의존성 0개 | 3, 4 |

## 8. 범위 밖 (넣지 않음)

로그인, 검색, 수정, 삭제, 태그, 배포, 스타일링, 정렬 옵션, 페이지네이션, 작성 시각 표시, 동시 쓰기 잠금.
