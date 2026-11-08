// Optional native PostgreSQL setup. Creates a project-owned cluster; never changes system PostgreSQL.
import { existsSync, readdirSync } from 'node:fs';
import { mkdir, readFile, writeFile, unlink } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const data = join(root, '.data', 'postgres');
const suffix = process.platform === 'win32' ? '.exe' : '';
const candidates = [process.env.PG_BIN];
for (const base of [join(process.env.ProgramFiles || 'C:/Program Files', 'PostgreSQL'), '/usr/lib/postgresql']) {
  if (existsSync(base)) for (const version of readdirSync(base).sort((a,b) => b.localeCompare(a, undefined, { numeric: true }))) candidates.push(join(base, version, 'bin'));
}
for (const directory of (process.env.PATH || '').split(process.platform === 'win32' ? ';' : ':')) candidates.push(directory);
const bin = candidates.find(directory => directory && existsSync(join(directory, `initdb${suffix}`)));
if (!bin) throw new Error('PostgreSQLの実行ファイルが見つかりません。PG_BINを設定するか、Docker Composeを利用してください。');

await mkdir(join(root, '.data'), { recursive: true });
const envPath = join(root, '.env');
if (!existsSync(envPath)) {
  const password = randomBytes(24).toString('hex');
  const text = (await readFile(join(root, '.env.example'), 'utf8')).replaceAll('feswave_dev_password', password);
  await writeFile(envPath, text, { flag: 'wx', mode: 0o600 });
}
process.loadEnvFile(envPath);
const url = new URL(process.env.DATABASE_URL);
const name = decodeURIComponent(url.pathname.slice(1));
const user = decodeURIComponent(url.username);
const password = decodeURIComponent(url.password);
const port = url.port || '5432';
if (url.hostname !== '127.0.0.1' || port !== '55432' || !/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(name) || !/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(user)) {
  throw new Error('db:localは127.0.0.1:55432専用です。外部DBはDATABASE_URLで指定して直接npm startしてください。');
}
const env = { ...process.env, PGPASSWORD: password, PGHOST: '127.0.0.1', PGPORT: port, PGUSER: user };
async function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(join(bin, command + suffix), args, { env, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    child.stdout.on('data', data => { stdout += data; });
    child.stderr.on('data', data => { stderr += data; });
    child.on('error', reject);
    // pg_ctl's background server may inherit pipe handles on Windows. Wait for the parent process, not pipe closure.
    child.on('exit', code => {
      child.stdout.destroy(); child.stderr.destroy();
      if (code === 0) resolve({ stdout, stderr });
      else reject(new Error(`${command}に失敗しました。${stderr || stdout || `終了コード ${code}`}`));
    });
  });
}
if (process.argv.includes('--stop')) {
  await run('pg_ctl', ['-D', data, '-m', 'fast', '-w', 'stop']);
  console.log('プロジェクト専用PostgreSQLを停止しました。');
} else {
  if (!existsSync(join(data, 'PG_VERSION'))) {
    const passwordFile = join(root, '.data', 'postgres-init-password');
    await writeFile(passwordFile, password, { mode: 0o600 });
    try { await run('initdb', ['-D', data, '-U', user, '--auth=scram-sha-256', '--pwfile', passwordFile, '--encoding=UTF8', '--locale=C']); }
    finally { await unlink(passwordFile); }
  }
  let running = false;
  try { await run('pg_ctl', ['-D', data, 'status']); running = true; } catch {}
  if (!running) await run('pg_ctl', ['-D', data, '-l', join(root, '.data', 'postgres.log'), '-o', `-h 127.0.0.1 -p ${port}`, '-w', 'start']);
  const { stdout } = await run('psql', ['-w', '-d', 'postgres', '-Atqc', `SELECT 1 FROM pg_database WHERE datname='${name}'`]);
  if (!stdout.trim()) await run('createdb', ['-w', name]);
  console.log(`PostgreSQL is ready: 127.0.0.1:${port} / ${name}`);
}
