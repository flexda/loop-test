# 빌더 로그

## 작업 1. 핵심 흐름 관통 조각

### 한 일
- 도구 확인: `which node npm` -> `/Users/reflectdata/.local/bin/node`, `/Users/reflectdata/.local/bin/npm`, node v22.22.3.
- `package.json`: `"type": "module"`, `scripts.start = "node server.js"`, 의존성 없음.
- `server.js`: `node:http` 서버.
  - `GET /` -> `public/index.html` (text/html; charset=utf-8)
  - `GET /api/memos` -> 저장 배열 그대로(파일 없으면 `[]`). 정렬은 작업 2에서 한다.
  - `POST /api/memos` -> `{text}` 를 `{id: 최댓값+1, text, createdAt}` 로 추가하고 저장한 뒤 201.
  - `PORT`(기본 3000)와 `DATA_FILE`(기본 `data/memos.json`)을 지원한다. 저장은 `<DATA_FILE>.tmp` 에 쓰고 `rename` 하며, 디렉터리는 `mkdir -p` 로 만든다.
  - 시작할 때 `http://localhost:<PORT>` 를 출력한다.
  - 응답 없이 요청이 걸리지 않도록 최소 장치를 두었다. 나머지 경로는 404를 주고, 처리 중 예외는 500으로 응답하며 서버는 죽지 않는다. 빈 입력 400과 JSON 파싱 실패 400은 작업 2 범위라 넣지 않았다. 지금은 잘못된 JSON을 보내면 500이 난다.
- `public/index.html`: `form#memo-form`, `input#memo-input`, 추가 버튼, `ul#memo-list` 로 구성했다. 로드할 때 GET으로 목록을 그리고, submit하면 preventDefault, POST, 입력란 비우기, 목록 다시 그리기 순으로 처리한다. 항목은 `textContent` 로 넣는다. trim 검사는 작업 2에서 한다.
- `.gitignore`: `data/`

### 실행한 명령과 결과
DATA_FILE: `/private/tmp/claude-501/-Users-reflectdata-Project-loop-test/4fa10cde-f17c-4928-9cbf-e9f06fe7d145/scratchpad/t1.json` (아래에서는 `$S/t1.json`). 시작 전에 이 파일을 지웠다.

1. `PORT=3100 DATA_FILE=$S/t1.json nohup npm start &`: 콘솔에 `http://localhost:3100` 이 출력됐고, `lsof` 로 node가 3100 포트에서 LISTEN 중인 것을 확인했다. 통과.
2. `node --input-type=module -e` 로 `fetch("http://localhost:3100/")`: status 200이고 `memo-input`, `memo-form`, `memo-list` 가 모두 있었다. 통과.
3. `POST /api/memos {"text":"테스트 메모 1"}`: 201, `{"id":1,"text":"테스트 메모 1","createdAt":"2026-10-06T07:06:51.363Z"}`. 이어서 GET: 200, 같은 항목 1개가 들어 있었다. 통과.
4. `ls -l $S/t1.json; cat $S/t1.json`: 파일이 있고(102 bytes) "테스트 메모 1"이 들어 있었다. `t1.json.tmp` 는 남아 있지 않았다(rename 정상). 통과.
5. npm과 node 프로세스를 `kill` 한 뒤 포트 3100이 비고 두 프로세스가 사라진 것을 확인했다. 같은 명령으로 다시 띄운 뒤 GET을 보냈더니 `[{"id":1,"text":"테스트 메모 1",...}]` 가 돌아왔다(성공 기준 7). 통과.
6. node와 npm을 `kill` 했다. `lsof` 로 3100 포트가 빈 것을 확인했고, `ps` 에 `node server.js` 나 `npm start` 프로세스가 없었다. 통과.

추가 확인: 프로젝트의 `data/` 디렉터리는 생성되지 않았다.

결론: 확인 방법 1~6을 모두 통과했다.

### 제안
- 작업 2에서 JSON 파싱 실패를 400으로 처리하면 지금의 500 경로는 예상하지 못한 오류에만 남는다.
- `npm start` 를 종료할 때 npm만 죽이면 자식 node가 남을 수 있다. 작업 3의 테스트에서는 설계대로 `node server.js` 를 직접 자식 프로세스로 띄우는 편이 안전하다.

## 작업 2. 빈 입력 거부와 최신순 정렬

### 한 일
- `server.js`
  - `POST /api/memos`: 본문 JSON 파싱에 실패하면 400 `{"error":"invalid json"}` 을 준다. `text` 가 문자열이 아니거나 trim 후 비어 있으면 400 `{"error":"empty"}` 을 주고 파일은 건드리지 않는다. 저장하는 값은 trim된 text다.
  - `GET /api/memos`: 저장 배열을 복사해 id 내림차순으로 정렬해 반환한다. 파일에는 오래된 것부터 저장된 순서가 그대로 남는다.
  - 404 처리는 작업 1에서 이미 있었다. 이제 500은 예상하지 못한 오류에만 남는다.
- `public/index.html`: submit 핸들러에서 `const text = input.value.trim(); if (!text) return;` 를 한 뒤 trim된 값을 POST한다.

### 실행한 명령과 결과
스크래치 경로(`$S`) = `/private/tmp/claude-501/-Users-reflectdata-Project-loop-test/4fa10cde-f17c-4928-9cbf-e9f06fe7d145/scratchpad`. 확인 스크립트 `$S/check2.mjs` 는 `node server.js` 를 자식 프로세스로 띄우고, 검사가 끝나면 kill한 뒤 exit을 기다린다.

`node $S/check2.mjs $S/t2.json 3101` 실행, exit 0:
1. `POST {"text":"   "}` -> 400 `{"error":"empty"}`, 이어서 GET 길이 0. 통과.
2. `POST {}` -> 400, 본문 `not json` -> 400. 통과.
3. "메모 A", "메모 B" 순서로 POST한 뒤 GET -> `["메모 B","메모 A"]`. 통과.
4. `POST {"text":"  앞뒤공백  "}` -> 201. 응답과 파일 모두 `"앞뒤공백"` 으로 저장됐다. 통과.
5. `GET /없는경로` (URL 인코딩) -> 404. 통과.
6. `grep` 결과 index.html 32-33행에 `const text = input.value.trim();` 와 `if (!text) return;` 가 있다. 실제 브라우저 동작은 작업 4의 대체 검증에서 POST 0회로 확인했다. 통과.
7. 스크립트 끝에서 서버가 종료됐고, `lsof` 로 3101 포트가 비어 있으며 `ps` 에 `node server.js` 가 없는 것을 확인했다. 통과.

작업 1 재확인: `node $S/check1.mjs $S/t1.json 3100` 을 실행했고 exit 0이다. 작업 1 절차대로 `npm start` 를 쓰되 `detached` 로 띄워 프로세스 그룹 전체에 SIGTERM을 보냈다. GET / 200과 세 id, POST 201과 GET 포함, 파일 존재와 `.tmp` 미잔존, 재시작 후 유지, 종료를 모두 통과했다. 이후 3100 포트와 `npm start`/`server.js` 프로세스 모두 남지 않았다. 프로젝트 `data/` 는 없다.

### 제안
- 없음.

## 작업 3. 자동 통합 테스트

### 한 일
- `test/app.test.js`: `node:test`, `node:assert/strict`, `node:child_process`, `node:fs`, `node:os`, `node:path`, `node:url`, 전역 `fetch` 만 쓴다.
  - 테스트마다 `os.tmpdir()` 아래에 `mkdtemp` 로 임시 디렉터리를 만들고 그 안의 `memos.json` 을 DATA_FILE로 쓴다. 포트는 3200번대에서 하나씩 올려 쓴다.
  - `spawn(process.execPath, ['server.js'])` 로 `node server.js` 를 직접 띄우고(npm 경유하지 않음), stdout에 `http://localhost:<port>` 가 나오면 준비가 끝난 것으로 본다. 시작 타임아웃은 5초이고, 서버가 일찍 죽으면 실패한다.
  - `t.after` 에서 서버를 kill하고 exit을 기다린 뒤 임시 디렉터리를 지운다. 재시작 테스트에서 중복 kill해도 안전하게 짰다.
  - 케이스: (a) GET / 에 `id="memo-input"`, `id="memo-form"`, `id="memo-list"` 가 있다. (b) 추가한 메모가 목록에 나타난다. (c) 공백 입력은 400 `{"error":"empty"}` 이고 목록이 바뀌지 않는다. (d) 두 개를 추가하면 최신이 앞에 온다. (e) 같은 DATA_FILE과 같은 포트로 재시작해도 데이터가 유지된다.
- `package.json`: `scripts.test = "node --test test/*.test.js"`

### 설계와 다른 점
- 설계에는 `"node --test test/"` 로 되어 있다. 이대로 실행하니 Node v22.22.3이 `Error: Cannot find module '/Users/reflectdata/Project/loop-test/test'` 를 내고 실패했다. v22의 `--test` 는 디렉터리 인자를 받지 않고 파일이나 glob만 받는다. 그래서 `test/*.test.js` 로 바꿨다(npm은 sh로 실행하므로 sh가 glob을 확장한다). 테스트 내용은 바꾸지 않았다.

### 실행한 명령과 결과
1. `npm test`: 5개 중 5개가 pass하고 fail 0, 종료 코드 0이다(약 0.9초). 통과.
2. `ps ax | grep "[s]erver.js"` 와 `pgrep -fl "node server.js"` 를 돌렸다. node 프로세스는 없었다(ps에 걸린 한 줄은 확인 명령을 실행한 zsh 자신의 명령줄이었다). `lsof` 로 확인한 32xx 포트에도 LISTEN이 없다. 통과.
3. 프로젝트 `data/` 디렉터리 자체가 없다(`ls data` -> No such file). `$TMPDIR/quick-memo-test-*` 임시 디렉터리도 남지 않았다. 통과.
4. `package.json` 에 `dependencies` 문자열이 0번 나오고 `node_modules/` 가 없다. 통과.

### 제안
- 포트를 고정 번호로 쓰고 있어 다른 프로세스가 같은 포트를 쓰고 있으면 테스트가 실패한다. 필요해지면 서버가 `PORT=0` 을 받았을 때 실제로 할당된 포트를 출력하도록 바꾸는 방안이 있다(지금은 범위 밖이라 하지 않았다).

## 작업 4. README 와 최종 수동 확인

### 한 일
- `README.md`: 필요 도구(Node.js 22, npm, 설치 단계 없음), 실행(`npm start` 후 `http://localhost:3000`), 테스트(`npm test`), 데이터 위치(`data/memos.json`).

### 브라우저 확인 대체 근거
이 자동 루프에서는 브라우저를 조작할 수 없었다. 브라우저 자동화 도구는 설계상 설치 금지이고, 이 실행 환경에도 브라우저 조작 도구가 연결되어 있지 않다. 그래서 1~6번은 아래 두 가지로 대체했다. 실제 브라우저 렌더링, 버튼 클릭, Enter 키 입력은 사람이 확인하지 않은 상태이므로 QA에서 "브라우저 미확인"으로 표시해야 한다.

(가) 화면 스크립트 실행 검증 `$S/check4.mjs` (`node $S/check4.mjs $S/t4.json 3102`, exit 0)
- 실제 `node server.js` 를 띄운 뒤 `GET /` 로 받은 index.html에서 인라인 `<script>` 를 그대로 추출했다. 이를 최소 DOM 스텁(getElementById, createElement, replaceChildren, appendChild, addEventListener)과 서버로 연결되는 fetch를 붙여 실행했다. 화면 코드를 고치거나 다시 구현하지 않았다.
- 1번: 세 요소를 찾았고 submit 핸들러가 등록됐으며 초기 목록은 비어 있다. 통과.
- 2번: "테스트 메모 1" 을 submit하면 `preventDefault` 가 호출되고(페이지 이동 없음) 목록이 `["테스트 메모 1"]` 이 되며 입력란이 `""` 이 된다. 통과.
- 3번: "테스트 메모 2" 를 submit하면 목록이 `["테스트 메모 2","테스트 메모 1"]` 이 된다. Enter와 버튼 클릭은 모두 form submit 이벤트로 들어오며, 이는 설계 5절과 소스(`type="submit"` 버튼, form submit 리스너)로 확인했다. 통과.
- 4번: 공백 `"    "` 을 submit하면 POST가 0회이고 목록은 2개 그대로다. 통과.
- 5번: 페이지를 다시 열면(HTML을 다시 받아 스크립트를 재실행하면) 두 메모가 같은 순서로 나온다. 통과.
- 6번: 서버를 kill하고 다시 띄운 뒤 페이지를 다시 열어도 두 메모가 같은 순서로 나온다. 통과.
- 종료 후 `pgrep -fl "node server.js"` 결과가 비어 있다.

(나) README대로 기동
- 3000 포트가 비어 있는 것을 `lsof` 로 확인한 뒤, 프로젝트 디렉터리에서 `npm start` 를 `detached` 로 실행했다. stdout은 `> node server.js` 다음에 `http://localhost:3000` 이었다. `GET /` 는 200이고 세 id가 모두 있었으며, `GET /api/memos` 는 200 `[]` 였다. 프로젝트 `data/` 를 쓰지 않도록 POST는 보내지 않았다. 그 뒤 프로세스 그룹에 SIGTERM을 보내 종료했고, 3000 포트와 `npm start`/`node server.js` 프로세스가 남지 않은 것을 확인했다. 프로젝트 `data/` 는 없다.

7번: 마지막으로 `npm test` 를 돌려 5개 모두 pass, fail 0을 확인했다. 통과.

### 제안
- 사람이 브라우저에서 README 절차대로 1~6번을 한 번 확인하면 대체 근거의 빈틈(실제 렌더링과 키 입력)이 메워진다. 이때 프로젝트 `data/memos.json` 이 생성된다.
