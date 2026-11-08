import pg from 'pg';
import { existsSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const envPath = fileURLToPath(new URL('../.env', import.meta.url));
if (existsSync(envPath)) process.loadEnvFile(envPath);

export async function isolatedDatabase() {
  const connectionString = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;
  if (!connectionString) throw new Error('テスト用PostgreSQLを起動し、DATABASE_URLまたはTEST_DATABASE_URLを設定してください。');
  const admin = new pg.Client({ connectionString });
  await admin.connect();
  // Each run owns this randomly named schema. Public/development tables are never reset.
  const schema = `feswave_test_${randomUUID().replaceAll('-', '')}`;
  try {
    await admin.query(`CREATE SCHEMA ${schema}`);
    await admin.query(`SET search_path TO ${schema}`);
  } catch (error) { await admin.end(); throw error; }
  const url = new URL(connectionString);
  url.searchParams.set('options', `-csearch_path=${schema}`);
  return {
    admin, url: url.toString(),
    async close() {
      try {
        if (!/^feswave_test_[a-f0-9]{32}$/.test(schema)) throw new Error('Invalid test schema');
        await admin.query(`DROP SCHEMA ${schema} CASCADE`);
      } finally { await admin.end(); }
    },
  };
}
