import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';

test('two independent clients share reactions, keep consented memories and revoke sharing', { timeout: 25000 }, async () => {
  const directory = await mkdtemp(join(tmpdir(), 'feswave-test-'));
  const port = 20000 + Math.floor(Math.random() * 20000);
  const binary = fileURLToPath(new URL(process.platform === 'win32' ? '../target/debug/feswave.exe' : '../target/debug/feswave', import.meta.url));
  const child = spawn(binary, [], { env: { ...process.env, PORT: String(port), FESWAVE_DATA_DIR: directory }, stdio: ['ignore', 'pipe', 'pipe'] });
  let stderr = ''; child.stderr.on('data', data => { stderr += data; });
  const streams = [];
  try {
    await Promise.race([once(child.stdout, 'data'), once(child, 'exit').then(() => { throw new Error(stderr || 'Server exited early'); })]);
    const base = `http://127.0.0.1:${port}/api/`;
    const request = async (path, cookie = '', method = 'GET', body) => {
      const response = await fetch(base + path, { method, headers: { Cookie: cookie, 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
      return { response, data: await response.json() };
    };
    assert.equal((await request('memories')).response.status, 401);
    const a = await request('session'); const b = await request('session');
    const cookieA = a.response.headers.get('set-cookie').split(';')[0];
    const cookieB = b.response.headers.get('set-cookie').split(';')[0];
    assert.notEqual(cookieA, cookieB);
    assert.equal(a.data.user.visible, false);
    // Public user IDs must not be usable as session credentials.
    assert.equal((await request('memories', `feswave=${a.data.user.id}`)).response.status, 401);
    for (const [cookie, name] of [[cookieA, 'Alice'], [cookieB, 'Bob']]) {
      assert.equal((await request('profile', cookie, 'PUT', { name, artist: 'YOASOBI', song: '群青', color: 'pink', visible: true })).response.status, 200);
      assert.equal((await request('join', cookie, 'POST', { eventId: 'feswave-2026' })).response.status, 200);
    }
    for (const cookie of [cookieA, cookieB]) {
      const controller = new AbortController(); streams.push(controller);
      const response = await fetch(base + 'stream', { headers: { Cookie: cookie }, signal: controller.signal });
      assert.equal(response.headers.get('content-type'), 'text/event-stream');
      const reader = response.body.getReader();
      const first = await reader.read(); assert.match(new TextDecoder().decode(first.value), /participants/);
      // Drain frames so the server can continue writing during the test.
      (async () => { try { while (!(await reader.read()).done) {} } catch {} })();
    }
    // Start early in a window to keep both requests in the same aggregation bucket.
    await new Promise(resolve => setTimeout(resolve, 5000 - Date.now() % 5000 + 80));
    for (const cookie of [cookieA, cookieB]) assert.equal((await request('react', cookie, 'POST', {})).data.level, 1);
    await new Promise(resolve => setTimeout(resolve, 5000 - Date.now() % 5000 + 400));
    const memoriesA = (await request('memories', cookieA)).data;
    const memoriesB = (await request('memories', cookieB)).data;
    assert.equal(memoriesA.length, 1); assert.equal(memoriesA[0].person.name, 'Bob');
    assert.equal(memoriesB.length, 1); assert.equal(memoriesB[0].person.name, 'Alice');
    assert.equal((await request(`memories/${memoriesA[0].id}`, cookieB, 'PATCH', { favorite: true })).response.status, 404);
    assert.equal((await request(`memories/${memoriesA[0].id}`, cookieA, 'PATCH', { favorite: true })).data.favorite, true);
    await request('profile', cookieB, 'PUT', { name: 'Bob', artist: 'SECRET', visible: false });
    assert.equal((await request('memories', cookieA)).data.length, 0);
    const privateStream = new AbortController(); streams.push(privateStream);
    const privateResponse = await fetch(base + 'stream', { headers: { Cookie: cookieA }, signal: privateStream.signal });
    const frame = new TextDecoder().decode((await privateResponse.body.getReader().read()).value);
    assert.doesNotMatch(frame, /SECRET/);
    assert.equal((await request('join', cookieA, 'POST', { eventId: 'unknown' })).response.status, 400);
    const crossOrigin = await fetch(base + 'react', { method: 'POST', headers: { Cookie: cookieA, Origin: 'http://elsewhere.example' } });
    assert.equal(crossOrigin.status, 403);
    assert.equal((await fetch(`http://127.0.0.1:${port}/server.mjs`)).status, 404);
  } finally {
    streams.forEach(controller => controller.abort());
    if (child.exitCode === null) { const exited = once(child, 'exit'); child.kill(); await exited; }
    await rm(directory, { recursive: true, force: true });
  }
});
