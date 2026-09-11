import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
test('pairing protocol has no log/upload/URL-token/storage or caller-selected RPC plumbing',()=>{
 const source=read('supabase/functions/pairing/protocol.mjs');
 for(const pattern of [/console\./,/process\.env/,/writeFile/,/localStorage/,/https?:\/\//,/fetch\(/,/eval\(/])
  assert.ok(!pattern.test(source));
 assert.ok(source.includes('randomBytes(32)'));
 assert.ok(source.includes("'cache-control':'no-store'"));
 assert.ok(source.includes('url.search'));
});
test('SQL only accepts digests; fixed scope and least-privilege boundaries remain explicit',()=>{
 const sql=read('supabase/migrations/202609110003_pairing.sql');
 assert.ok(!/p_(?:token|credential|secret)\s+text/.test(sql));
 assert.ok(!/raise\s+(notice|log)|execute\s+format|grant\s+all/i.test(sql));
 assert.equal((sql.match(/security definer set search_path=''/g)||[]).length,3);
 assert.ok(sql.includes('s.expires_at<=t'));
 assert.ok(sql.includes('for update'));
 assert.ok(sql.includes('to service_role'));
 assert.ok(sql.includes('from public,anon,authenticated,service_role'));
});
test('combined checker cannot omit real pairing SQL/HTTP and concurrency inventory',()=>{
 assert.ok(read('tools/kr004/check-local.mjs').includes("'--pairing'"));
 assert.ok(read('tools/kr004/test-local-db.mjs').includes('await runPairingIntegration(sql'));
 assert.ok(read('tools/kr004/validation-contract.mjs').includes('06_pairing_races.test.sql'));
});
