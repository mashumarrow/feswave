// Tooling only: the application backend is implemented in src/*.rs.
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const localCargo = join(root, '.tools', 'cargo', 'bin', process.platform === 'win32' ? 'cargo.exe' : 'cargo');
const local = existsSync(localCargo);
const env = { ...process.env, ...(local ? { CARGO_HOME: join(root, '.tools/cargo'), RUSTUP_HOME: join(root, '.tools/rustup') } : {}) };
const child = spawn(local ? localCargo : 'cargo', process.argv.slice(2), { cwd: root, env, stdio: 'inherit' });
child.on('error', error => { console.error(`Cargoを起動できません。Rustをインストールしてください: ${error.message}`); process.exitCode = 1; });
child.on('exit', code => { process.exitCode = code ?? 1; });
