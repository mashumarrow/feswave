import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { isolatedDatabase } from './database.mjs';

const binary = fileURLToPath(new URL(process.platform === 'win32' ? '../target/debug/feswave.exe' : '../target/debug/feswave', import.meta.url));

function launch(databaseUrl, port, args = []) {
  const child = spawn(binary, args, { env: { ...process.env, HOST: '127.0.0.1', PORT: String(port), DATABASE_URL: databaseUrl }, stdio: ['ignore', 'pipe', 'pipe'] });
  let stderr = ''; let stdout = '';
  child.stderr.on('data', data => { stderr += data; });
  child.stdout.on('data', data => { stdout += data; });
  const ready = new Promise((resolve, reject) => {
    const timer = setTimeout(() => { child.kill(); reject(new Error('Server startup timeout')); }, 15000);
    child.stdout.on('data', () => { if (stdout.includes('is ready:')) { clearTimeout(timer); resolve(); } });
    child.on('error', error => { clearTimeout(timer); reject(error); });
    child.on('exit', code => { clearTimeout(timer); if (args.length && code === 0) resolve(); else reject(new Error(stderr || `Server exited: ${code}`)); });
  });
  return { child, ready, output: () => stdout };
}
async function stop(running) {
  if (running?.child.exitCode === null) { const exited = once(running.child, 'exit'); running.child.kill(); await exited; }
}

test('PostgreSQL migration, import, real-time sharing, restart persistence and privacy', { timeout: 45000 }, async () => {
  const db = await isolatedDatabase();
  const directory = await mkdtemp(join(tmpdir(), 'feswave-test-'));
  const port = 20000 + Math.floor(Math.random() * 20000);
  let running;
  const streams = [];
  try {
    // Import a legacy JSON fixture twice: preserve IDs/Cookies and never overwrite newer DB data.
    const legacyA = { id: randomUUID(), name: 'legacyA', artist: 'original', song: '群青', color: 'blue', visible: true, eventId: 'your-live' };
    const legacyB = { ...legacyA, id: randomUUID(), name: 'legacyB' };
    const legacyToken = randomUUID();
    const legacyMemory = { id: randomUUID(), userId: legacyA.id, eventId: 'your-live', at: Math.floor(Date.now()/5000)*5000, level: 2, person: legacyB, favorite: true };
    const source = join(directory, 'store.json');
    await writeFile(source, JSON.stringify({ users: { [legacyA.id]: legacyA, [legacyB.id]: legacyB }, sessions: { [legacyToken]: legacyA.id }, memories: [legacyMemory] }));
    running = launch(db.url, port, ['--import-json', source]); await running.ready;
    assert.match(running.output(), /"users":2/);
    await db.admin.query('UPDATE users SET artist=$2 WHERE id=$1', [legacyA.id, 'newer DB value']);
    running = launch(db.url, port, ['--import-json', source]); await running.ready;
    assert.match(running.output(), /"users":0/);
    assert.match(running.output(), /"memories":0/);
    running = launch(db.url, port); await running.ready;
    const base = `http://127.0.0.1:${port}/api/`;
    const request = async (path, cookie = '', method = 'GET', body) => {
      const response = await fetch(base + path, { method, headers: { Cookie: cookie, 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
      return { response, data: await response.json() };
    };
    const imported = await request('session', `feswave=${legacyToken}`);
    assert.equal(imported.data.user.id, legacyA.id);
    assert.equal(imported.data.user.artist, 'newer DB value');
    const importedMemories = (await request('memories', `feswave=${legacyToken}`)).data;
    assert.equal(importedMemories.length, 1);
    assert.equal(importedMemories[0].favorite, true);
    assert.equal(importedMemories[0].at, legacyMemory.at);
    assert.equal((await request('memories')).response.status, 401);
    const a = await request('session'); const b = await request('session');
    const cookieA = a.response.headers.get('set-cookie').split(';')[0];
    const cookieB = b.response.headers.get('set-cookie').split(';')[0];
    assert.notEqual(cookieA, cookieB);
    assert.equal(a.data.user.visible, false);
    assert.equal((await request('memories', `feswave=${a.data.user.id}`)).response.status, 401);
    for (const [cookie, name] of [[cookieA, 'Alice'], [cookieB, 'Bob']]) {
      assert.equal((await request('profile', cookie, 'PUT', { name, artist: 'YOASOBI', song: '群青', color: 'pink', visible: true })).response.status, 200);
      assert.equal((await request('join', cookie, 'POST', { eventId: 'feswave-2026' })).response.status, 200);
    }
    assert.equal((await request('join', cookieA, 'POST', { eventId: 'feswave-2026' })).response.status, 200);
    assert.equal((await request('join', cookieA, 'POST', { eventId: 'night-groove' })).response.status, 409);
    assert.equal((await request('session', cookieA)).data.user.eventId, 'feswave-2026');
    for (const cookie of [cookieA, cookieB]) {
      const controller = new AbortController(); streams.push(controller);
      const response = await fetch(base + 'stream', { headers: { Cookie: cookie }, signal: controller.signal });
      assert.equal(response.headers.get('content-type'), 'text/event-stream');
      const reader = response.body.getReader();
      assert.match(new TextDecoder().decode((await reader.read()).value), /participants/);
      (async () => { try { while (!(await reader.read()).done) {} } catch {} })();
    }
    await new Promise(resolve => setTimeout(resolve, 5000 - Date.now() % 5000 + 80));
    for (const cookie of [cookieA, cookieB]) assert.equal((await request('react', cookie, 'POST', {})).data.level, 1);
    await new Promise(resolve => setTimeout(resolve, 5000 - Date.now() % 5000 + 500));
    const memoriesA = (await request('memories', cookieA)).data;
    const memoriesB = (await request('memories', cookieB)).data;
    assert.equal(memoriesA.length, 1); assert.equal(memoriesA[0].person.name, 'Bob');
    assert.equal(memoriesB.length, 1); assert.equal(memoriesB[0].person.name, 'Alice');
    assert.ok(Date.now() - memoriesA[0].at < 6000);
    assert.equal((await request(`memories/${memoriesA[0].id}`, cookieB, 'PATCH', { favorite: true })).response.status, 404);
    assert.equal((await request(`memories/${memoriesA[0].id}`, cookieA, 'PATCH', { favorite: true })).data.favorite, true);
    const participantRows = await db.admin.query('SELECT * FROM event_participants WHERE user_id=$1', [a.data.user.id]);
    assert.equal(participantRows.rowCount, 1);
    const hashes = await db.admin.query('SELECT token_hash FROM sessions WHERE user_id=$1', [a.data.user.id]);
    assert.equal(hashes.rows[0].token_hash.length, 64);
    assert.notEqual(hashes.rows[0].token_hash, cookieA.split('=')[1]);
    // Recreate the Rust process and verify data is read from PostgreSQL, not process memory.
    streams.forEach(c => c.abort()); await stop(running);
    running = launch(db.url, port); await running.ready;
    assert.equal((await request('session', cookieA)).data.user.name, 'Alice');
    assert.equal((await request('session', cookieA)).data.user.eventId, 'feswave-2026');
    const persisted = (await request('memories', cookieA)).data;
    assert.equal(persisted.length, 1); assert.equal(persisted[0].favorite, true);
    await request('profile', cookieB, 'PUT', { name: 'Bob', artist: 'SECRET', visible: false });
    assert.equal((await request('memories', cookieA)).data.length, 0);
    assert.equal((await db.admin.query('SELECT id FROM memories WHERE person_id=$1', [b.data.user.id])).rowCount, 0);
    const privateStream = new AbortController(); streams.push(privateStream);
    const privateResponse = await fetch(base + 'stream', { headers: { Cookie: cookieB }, signal: privateStream.signal });
    const frame = new TextDecoder().decode((await privateResponse.body.getReader().read()).value);
    assert.doesNotMatch(frame, /SECRET/);
    assert.equal((await request('join', cookieA, 'POST', { eventId: 'unknown' })).response.status, 400);
    assert.equal((await request('memories/invalid-id', cookieA, 'PATCH', { favorite: true })).response.status, 404);
    const crossOrigin = await fetch(base + 'react', { method: 'POST', headers: { Cookie: cookieA, Origin: 'http://elsewhere.example' } });
    assert.equal(crossOrigin.status, 403);
    assert.equal((await fetch(`http://127.0.0.1:${port}/.env`)).status, 404);
    await db.admin.query("UPDATE sessions SET expires_at=NOW()-INTERVAL '1 day' WHERE user_id=$1", [a.data.user.id]);
    assert.equal((await request('memories', cookieA)).response.status, 401);
    assert.notEqual((await request('session', cookieA)).data.user.id, a.data.user.id);
  } finally {
    streams.forEach(controller => controller.abort()); await stop(running);
    await db.close(); await rm(directory, { recursive: true, force: true });
  }
});
