# QA 보고서: 빠른 메모 MVP

## 실행 환경과 검증 방식
- 실행 환경: macOS (Darwin 24.6.0). node v22.22.3 (`/Users/reflectdata/.local/bin/node`), npm (`/Users/reflectdata/.local/bin/npm`). 검증할 수 없는 항목은 없었다.
- 앱 기동: README 대로 프로젝트 루트에서 `npm start` 를 실행했다. 프로젝트 `data/` 를 쓰지 않으려고 환경 변수만 덧붙였다(`PORT=3300 DATA_FILE=$S/memos.json npm start`). `$S` = `/private/tmp/claude-501/-Users-reflectdata-Project-loop-test/4fa10cde-f17c-4928-9cbf-e9f06fe7d145/scratchpad/qa`.
- 브라우저 확인: 이 환경에 설치된 Google Chrome(154)을 `--headless=new --remote-debugging-port=9333` 으로 띄우고, Node 22 내장 WebSocket으로 CDP(Chrome DevTools Protocol)에 붙어 조작했다(`$S/cdp.mjs`). 새 도구는 설치하지 않았다.
  - 입력은 `Input.insertText` 로 넣었다. 추가 버튼은 버튼 좌표에 `Input.dispatchMouseEvent` 를 보내 실제로 클릭했고, Enter는 `Input.dispatchKeyEvent` 로 보냈다. 새로고침은 `Page.reload` 를 썼다. 화면 상태는 실제 DOM에서 읽었고 스크린샷(`$S/shot-fresh.png`)도 확인했다.
  - 대체 사항: 사람이 화면에 보이는 브라우저 창을 직접 클릭하고 타이핑한 확인은 하지 않았다. 실제 Chrome 엔진에서 렌더링하고 입력 이벤트를 주입해 확인했으므로 판정은 통과로 두되, "사람의 GUI 브라우저 직접 확인"은 미확인 항목에 따로 적는다.
- 종료: npm 프로세스 그룹과 Chrome 프로세스 그룹에 SIGTERM을 보냈다. 이후 3000, 3300, 9333 포트에 LISTEN이 없고, 띄웠던 프로세스 그룹 4개(npm1, npm2, npm3, chrome)가 모두 사라진 것을 확인했다. 프로젝트 `data/` 디렉터리는 끝까지 생성되지 않았다.

## 성공 기준 판정 표

| # | 기준 | 실행 방법 | 기대 결과 | 실제 결과 | 판정 |
|---|------|-----------|-----------|-----------|------|
| 1 | 실행 명령 하나로 앱이 뜨고, 메인 페이지에 입력란, 추가 버튼, 목록 영역이 보인다 | `npm start`(PORT, DATA_FILE 지정)를 실행하고 headless Chrome으로 `http://localhost:3300/` 을 열었다. README 기본 포트도 따로 확인했다(`DATA_FILE` 만 지정해 `npm start` 하고 `http://localhost:3000/` 에 GET) | 서버가 기동하고 세 요소가 화면에 보인다 | stdout에 `http://localhost:3300` 이 나왔다. `#memo-input` 은 표시 폭이 0보다 크고, 버튼 텍스트는 "추가"(표시됨)이며, `#memo-list` 가 있다. 스크린샷에서도 확인했다. 기본 포트는 `http://localhost:3000` 출력, `GET /` 200 | 통과 |
| 2 | "테스트 메모 1"을 추가하면 페이지 이동 없이 목록에 나타난다 | 입력란에 "테스트 메모 1"을 넣고 추가 버튼을 마우스로 클릭했다 | 목록에 "테스트 메모 1"이 나오고 페이지 이동이 없다 | 목록은 `["테스트 메모 1"]`, frameNavigated 0회, URL은 그대로였다 | 통과 |
| 3 | 추가 후 입력란이 비워진다 | 2번 직후 `#memo-input.value` 를 읽었고, Enter로 추가한 뒤에도 다시 읽었다 | `""` | 두 경우 모두 `""` | 통과 |
| 4 | 메모 두 개를 추가하면 둘 다 보이고 최신이 맨 위다 | "테스트 메모 2"를 입력하고 Enter 키로 추가했다 | 두 개 모두 있고 2가 위 | `["테스트 메모 2", "테스트 메모 1"]`, 페이지 이동 0회 | 통과 |
| 5 | 공백만 입력하면 항목이 생기지 않는다 | (a) "   "를 넣고 버튼 클릭 (b) 빈 입력에서 Enter (c) API에 직접 `curl -X POST -d '{"text":"   "}'` | 목록 변화 없음 | (a)(b) POST 요청 0회, 목록은 2개 그대로. (c) 400 `{"error":"empty"}` | 통과 |
| 6 | 새로고침해도 메모가 그대로 보인다 | `Page.reload(ignoreCache)` 후 목록을 읽었다 | 두 메모가 같은 순서로 보인다 | `["테스트 메모 2", "테스트 메모 1"]` | 통과 |
| 7 | 앱을 종료하고 같은 명령으로 다시 띄워도 메모가 남아 있다 | npm 프로세스 그룹에 SIGTERM을 보내고 3300 포트가 빈 것과 server.js 프로세스가 없는 것을 확인했다. 같은 명령으로 재기동한 뒤 Chrome으로 페이지를 다시 열었다 | 앞서 추가한 메모가 모두 보인다 | 재기동 로그는 `http://localhost:3300`. 첫 화면 목록은 `["<b>x</b> & \"q\"", "테스트 메모 2", "테스트 메모 1"]`(추가 시험 메모 포함, 최신순) | 통과 |
| 8 | node, npm, python3, uv 외 도구 없이, 새 설치 없이 1~7이 통과한다 | `package.json` 의존성 확인, `node_modules/` 유무 확인, `which` 확인 | 의존성 0, 설치 단계 없음 | `package.json` 에 dependencies 없음, `node_modules/` 없음, `npm install` 없이 기동됨. 앱 실행에는 node와 npm만 쓴다. 검증에 쓴 Chrome은 이미 설치된 브라우저로, 스펙의 흐름 1단계가 전제하는 "브라우저"에 해당한다 | 통과 |

### 자동 테스트
- `npm test`(`node --test test/*.test.js`): tests 5, pass 5, fail 0, 종료 코드 0, 약 0.84초. 끝난 뒤 남은 `node server.js` 프로세스는 없었고 프로젝트 `data/` 도 생성되지 않았다.

## 경계면 교차 확인
- 화면 -> 서버(POST): index.html은 `{"text": <trim된 값>}` 을 JSON으로 보낸다. server.js는 `body.text` 가 문자열인지 보고 trim한 뒤 빈 값이면 400을 준다. 형식이 일치한다. 잘못된 JSON은 400 `{"error":"invalid json"}` 이다(curl로 확인).
- 서버 -> 화면(GET): 서버는 `[{id, text, createdAt}]` 를 id 내림차순으로 준다. 화면은 `memo.text` 만 `textContent` 로 넣는다. 형식이 일치하고 순서도 서버 정렬을 그대로 따른다.
- 저장 -> 읽기: `$S/memos.json` 에는 오래된 것부터 `{id, text, createdAt}` 배열로 저장된다. 재기동 후 GET이 이를 읽어 최신순으로 돌려준다. 파일 내용과 화면 목록을 나란히 대조해 일치함을 확인했다. `.tmp` 파일은 남지 않았다.
- 이상 입력: `<b>x</b> & "q"` 를 추가하면 문자 그대로 표시되고 `<b>` 요소는 0개다(HTML 주입 없음).

## 결함 목록

### 차단
- 없음.

### 일반
- 없음.

### 참고
1. README에 `PORT` 와 `DATA_FILE` 환경 변수가 적혀 있지 않다. 3000 포트가 이미 쓰이고 있으면 사용자가 우회 방법을 알 수 없다. 재현: 3000 포트를 다른 프로세스가 점유한 상태에서 `npm start` 를 실행한다(EADDRINUSE 예상, 이번 검증에서는 실행하지 않음).
2. README에 종료 방법(터미널에서 Ctrl+C)이 없다. 성공 기준 7이 "종료 후 재실행"을 요구하므로 한 줄 있으면 좋다.
3. 화면은 POST 응답 코드를 확인하지 않는다. 서버가 400이나 500을 주어도 입력란을 비워 사용자가 입력을 잃을 수 있다. 정상 흐름에서는 화면이 trim 검사를 먼저 하므로 재현되지 않으며 MVP 범위 안에서는 영향이 없다.

## 미확인 항목
- 사람이 화면에 보이는 브라우저 창에서 직접 클릭하고 타이핑하는 확인. headless Chrome에서 CDP로 입력 이벤트를 주입해 대체했다. 렌더링 엔진과 이벤트 경로는 실제 Chrome과 같지만 사람의 눈으로 본 확인은 아니다.
- Chrome 외 브라우저(Safari 등)에서의 동작.

## 전체 판정
통과. 성공 기준 1~8을 모두 실제로 실행해 통과했고 차단 결함과 일반 결함은 없다. README에 실행 방법(`npm start` 후 `http://localhost:3000` 접속)이 있으며, 문서대로 기동된다.
