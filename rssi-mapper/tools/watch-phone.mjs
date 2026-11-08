// Node 22+ and an authorized Android device with the mapper open in Chrome.
import { execFileSync } from 'node:child_process';
import { once } from 'node:events';
import { setTimeout as delay } from 'node:timers/promises';

process.stdout.on('error', error => {
  if (error.code === 'EPIPE') process.exit(0);
  throw error;
});
const adb = (...args) => execFileSync('adb', args, { encoding: 'utf8' }).trim();
const port = adb('forward', 'tcp:0', 'localabstract:chrome_devtools_remote');
process.on('exit', () => {
  try { adb('forward', '--remove', 'tcp:' + port); } catch {}
});
process.on('SIGINT', () => process.exit(0));
process.on('SIGTERM', () => process.exit(0));

const tabs = await (await fetch('http://127.0.0.1:' + port + '/json/list')).json();
const tab = tabs.find(t => t.url === 'http://192.168.4.1/');
if (!tab) throw Error('PixelなどのAndroid端末のChromeで http://192.168.4.1/ を開いてください');
const ws = new WebSocket(tab.webSocketDebuggerUrl);
await once(ws, 'open');
ws.addEventListener('close', () => process.exit(0));
const expression = `Object.fromEntries(['left','right','zone','offset','status'].map(id =>
  [id, document.getElementById(id)?.textContent ?? null]))`;
for (let id = 1; ; id++) {
  const reply = once(ws, 'message', { signal: AbortSignal.timeout(5000) });
  ws.send(JSON.stringify({ id, method:'Runtime.evaluate', params:{ expression, returnByValue:true } }));
  const [event] = await reply;
  const result = JSON.parse(event.data);
  if (result.error || result.result?.exceptionDetails) throw Error('Chrome画面の読み取りに失敗しました');
  console.log(JSON.stringify({ time:new Date().toISOString(), ...result.result.result.value }));
  await delay(500);
}
