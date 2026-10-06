import http from 'node:http';
import { readFile, writeFile, rename, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT) || 3000;
const DATA_FILE = process.env.DATA_FILE
  ? path.resolve(process.env.DATA_FILE)
  : path.join(ROOT, 'data', 'memos.json');
const INDEX_FILE = path.join(ROOT, 'public', 'index.html');

async function loadMemos() {
  try {
    return JSON.parse(await readFile(DATA_FILE, 'utf8'));
  } catch (err) {
    if (err.code === 'ENOENT') return [];
    throw err;
  }
}

async function saveMemos(memos) {
  await mkdir(path.dirname(DATA_FILE), { recursive: true });
  const tmp = `${DATA_FILE}.tmp`;
  await writeFile(tmp, JSON.stringify(memos, null, 2), 'utf8');
  await rename(tmp, DATA_FILE);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function sendJson(res, status, data) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(data));
}

const server = http.createServer(async (req, res) => {
  try {
    const { pathname } = new URL(req.url, 'http://localhost');

    if (req.method === 'GET' && pathname === '/') {
      const html = await readFile(INDEX_FILE);
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(html);
      return;
    }

    if (req.method === 'GET' && pathname === '/api/memos') {
      const memos = await loadMemos();
      sendJson(res, 200, [...memos].sort((a, b) => b.id - a.id));
      return;
    }

    if (req.method === 'POST' && pathname === '/api/memos') {
      let body;
      try {
        body = JSON.parse(await readBody(req));
      } catch {
        sendJson(res, 400, { error: 'invalid json' });
        return;
      }
      const text = body && typeof body.text === 'string' ? body.text.trim() : '';
      if (!text) {
        sendJson(res, 400, { error: 'empty' });
        return;
      }
      const memos = await loadMemos();
      const id = memos.reduce((max, m) => Math.max(max, m.id), 0) + 1;
      const memo = { id, text, createdAt: new Date().toISOString() };
      memos.push(memo);
      await saveMemos(memos);
      sendJson(res, 201, memo);
      return;
    }

    sendJson(res, 404, { error: 'not found' });
  } catch (err) {
    console.error(err);
    sendJson(res, 500, { error: 'internal' });
  }
});

server.listen(PORT, () => {
  console.log(`http://localhost:${PORT}`);
});
