import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
let nextPort = 3200 + (process.pid % 50) * 10;

function tempDataFile(t) {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'quick-memo-test-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return path.join(dir, 'memos.json');
}

// node server.js 를 직접 자식 프로세스로 띄우고, 시작 메시지가 나오면 반환한다.
async function startServer(t, dataFile, port) {
  const child = spawn(process.execPath, ['server.js'], {
    cwd: ROOT,
    env: { ...process.env, PORT: String(port), DATA_FILE: dataFile },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const exited = new Promise((resolve) => child.once('exit', resolve));
  const stop = async () => {
    if (child.exitCode === null && child.signalCode === null) child.kill();
    await exited;
  };
  t.after(stop);
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('server start timeout')), 5000);
    let out = '';
    child.stdout.on('data', (d) => {
      out += d;
      if (out.includes(`http://localhost:${port}`)) {
        clearTimeout(timer);
        resolve();
      }
    });
    child.once('exit', (code) => {
      clearTimeout(timer);
      reject(new Error(`server exited early: ${code}`));
    });
  });
  return { base: `http://localhost:${port}`, stop };
}

async function setup(t) {
  const dataFile = tempDataFile(t);
  const port = nextPort++;
  const server = await startServer(t, dataFile, port);
  return { ...server, dataFile, port };
}

const postMemo = (base, body) =>
  fetch(`${base}/api/memos`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
const listTexts = async (base) =>
  (await (await fetch(`${base}/api/memos`)).json()).map((m) => m.text);

test('(a) GET / 에 입력란, 폼, 목록 요소가 있다', async (t) => {
  const { base } = await setup(t);
  const res = await fetch(`${base}/`);
  assert.equal(res.status, 200);
  const html = await res.text();
  for (const id of ['memo-input', 'memo-form', 'memo-list']) {
    assert.ok(html.includes(`id="${id}"`), `${id} 없음`);
  }
});

test('(b) 추가한 메모가 목록에 나타난다', async (t) => {
  const { base } = await setup(t);
  const res = await postMemo(base, { text: '테스트 메모 1' });
  assert.equal(res.status, 201);
  assert.deepEqual(await listTexts(base), ['테스트 메모 1']);
});

test('(c) 공백 입력은 400 이고 목록이 바뀌지 않는다', async (t) => {
  const { base } = await setup(t);
  await postMemo(base, { text: '기존 메모' });
  const res = await postMemo(base, { text: '   ' });
  assert.equal(res.status, 400);
  assert.deepEqual(await res.json(), { error: 'empty' });
  assert.deepEqual(await listTexts(base), ['기존 메모']);
});

test('(d) 두 개 추가하면 최신 메모가 앞에 온다', async (t) => {
  const { base } = await setup(t);
  assert.equal((await postMemo(base, { text: '메모 A' })).status, 201);
  assert.equal((await postMemo(base, { text: '메모 B' })).status, 201);
  assert.deepEqual(await listTexts(base), ['메모 B', '메모 A']);
});

test('(e) 서버를 재시작해도 데이터가 유지된다', async (t) => {
  const { base, dataFile, port, stop } = await setup(t);
  await postMemo(base, { text: '메모 A' });
  await postMemo(base, { text: '메모 B' });
  await stop();
  const second = await startServer(t, dataFile, port);
  assert.deepEqual(await listTexts(second.base), ['메모 B', '메모 A']);
});
