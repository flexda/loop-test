# 구현 작업 목록: 빠른 메모 MVP

설계: `_workspace/02_architect_design.md`. 모든 확인은 작업 디렉터리 `/Users/reflectdata/Project/loop-test` 에서 하며, node/npm 외 도구를 쓰지 않는다. HTTP 확인은 `node -e` 와 내장 `fetch` 로 한다(curl 등 다른 도구에 의존하지 않음). 서버를 띄우는 확인은 끝나면 반드시 프로세스를 종료한다.

---

## 작업 1. 핵심 흐름 관통 조각 (적기 -> 보기 -> 파일 저장 -> 재시작 후 보기)

가장 얇은 조각이지만 흐름 1~5단계가 끝까지 간다. 빈 입력 처리와 정렬은 아직 신경 쓰지 않는다.

만들 것:
- `package.json`: `"type": "module"`, `scripts.start = "node server.js"`, dependencies 없음.
- `server.js`: `node:http` 서버. `GET /` 는 `public/index.html` 반환, `GET /api/memos` 는 `data/memos.json` 내용(없으면 `[]`) 반환, `POST /api/memos` 는 `{text}` 를 받아 `{id, text, createdAt}` 로 배열에 추가하고 파일에 저장 후 201. `PORT`, `DATA_FILE` 환경 변수 지원. 임시 파일 + rename 저장.
- `public/index.html`: form(`#memo-form`), input(`#memo-input`), 추가 버튼, `ul#memo-list`. 로드 시 목록 GET, submit 시 POST 후 입력란 비우고 목록 다시 그림. `textContent` 사용.
- `.gitignore`: `data/`

확인 방법:
1. `PORT=3100 DATA_FILE=/private/tmp/claude-501/-Users-reflectdata-Project-loop-test/4fa10cde-f17c-4928-9cbf-e9f06fe7d145/scratchpad/t1.json npm start` 를 백그라운드로 실행 (스크래치 경로는 실행 세션에 맞게 바꿔도 됨, 단 프로젝트 `data/` 는 쓰지 않는다).
2. `node -e` 로 `GET http://localhost:3100/` 응답이 200이고 본문에 `memo-input`, `memo-form`, `memo-list` 문자열이 모두 있는지 확인.
3. `node -e` 로 `POST /api/memos` 에 `{"text":"테스트 메모 1"}` 전송 -> 201, 이어서 `GET /api/memos` 결과에 "테스트 메모 1" 포함 확인.
4. DATA_FILE 경로의 파일이 존재하고 "테스트 메모 1"을 담고 있는지 확인.
5. 서버 프로세스를 종료하고 같은 명령으로 다시 띄운 뒤 `GET /api/memos` 에 "테스트 메모 1"이 여전히 있는지 확인 (성공 기준 7).
6. 서버 종료.

완료 조건: 위 1~6 모두 통과.

---

## 작업 2. 빈 입력 거부와 최신순 정렬

만들 것:
- `server.js`: `POST` 에서 `text` 를 trim. 없거나 빈 문자열이면 400 `{"error":"empty"}` 반환하고 파일을 건드리지 않음. JSON 파싱 실패도 400. 저장하는 text는 trim된 값. `GET /api/memos` 는 저장 배열을 뒤집어(id 내림차순) 반환. 그 외 경로 404.
- `public/index.html`: submit 시 trim 후 비면 요청을 보내지 않음.

확인 방법 (새 DATA_FILE, 예: 스크래치의 `t2.json`, PORT=3101):
1. `POST {"text":"   "}` -> 400, 이어서 `GET` 결과 길이 0.
2. `POST {}` -> 400, 본문 `not json` -> 400.
3. `POST "메모 A"`, `POST "메모 B"` 후 `GET` 결과가 `["메모 B","메모 A"]` 순서 (성공 기준 4).
4. `POST {"text":"  앞뒤공백  "}` -> 저장된 text 가 `"앞뒤공백"`.
5. `GET /없는경로` -> 404.
6. index.html 소스에 trim 후 빈 값이면 return 하는 분기가 있는지 눈으로 확인.
7. 서버 종료.

완료 조건: 위 1~7 통과, 작업 1 확인 절차도 다시 통과.

---

## 작업 3. 자동 통합 테스트

만들 것:
- `test/app.test.js`: `node:test`, `node:assert`, `node:child_process`, 전역 `fetch` 만 사용. 각 테스트마다 `os.tmpdir()` 아래 임시 DATA_FILE 과 비어 있는 포트(예: 3200번대)로 `node server.js` 를 자식 프로세스로 띄우고, 콘솔의 시작 메시지나 GET 재시도로 준비 완료를 기다린 뒤 검사하고, 끝나면 kill 한다.
- 테스트 케이스: (a) `GET /` 에 세 요소 id 포함, (b) 추가 후 목록에 나타남, (c) 공백 입력 400 및 목록 불변, (d) 두 개 추가 시 최신이 앞, (e) 서버 재시작 후 데이터 유지.
- `package.json`: `scripts.test = "node --test test/"`.

확인 방법:
1. `npm test` 실행 -> 5개 테스트 모두 pass, 종료 코드 0.
2. 실행 후 `ps` 로 남아 있는 `node server.js` 프로세스가 없는지 확인.
3. 프로젝트 `data/memos.json` 이 테스트 때문에 생성/변경되지 않았는지 확인.
4. `package.json` 에 `dependencies`/`devDependencies` 가 없고 `node_modules/` 가 없는지 확인 (성공 기준 8).

완료 조건: 위 1~4 통과.

---

## 작업 4. README 와 최종 수동 확인

만들 것:
- `README.md`: 실행 명령(`npm start`), 접속 주소(`http://localhost:3000`), 테스트 명령(`npm test`), 데이터 위치(`data/memos.json`), 필요 도구(node 22, npm. 설치 단계 없음).

확인 방법 (성공 기준 1~8 전체, 브라우저 사용):
1. `npm start` 하나로 기동, 브라우저에서 `http://localhost:3000` 열면 입력란, 추가 버튼, 목록 영역 보임.
2. "테스트 메모 1" 입력 후 추가 버튼 클릭 -> 목록에 나타나고 입력란 비워짐, 페이지 이동 없음.
3. "테스트 메모 2" 입력 후 Enter -> 두 개 보이고 "테스트 메모 2"가 맨 위.
4. 공백만 입력하고 추가 -> 목록 변화 없음.
5. 브라우저 새로고침 -> 두 메모 그대로.
6. 터미널에서 서버 종료(Ctrl+C) 후 `npm start` 재실행, 페이지 다시 열기 -> 두 메모 그대로.
7. `npm test` 통과.

브라우저를 조작할 수 없는 자동 루프에서는 1~6을 작업 3의 HTTP 수준 테스트 결과와 index.html 소스 검토로 대체하고, 그 사실을 QA 결과에 명시한다.

완료 조건: 위 1~7 통과 (또는 대체 근거 명시).
