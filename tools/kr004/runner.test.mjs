import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const runner=fileURLToPath(new URL('./test-local-db.mjs',import.meta.url));
const fake=fileURLToPath(new URL('./fake-docker.mjs',import.meta.url));
function execute(mode,host='unix:///var/run/docker.sock'){
  const directory=mkdtempSync(join(tmpdir(),'kr004-runner-test-'));
  try {
    const journal=join(directory,'journal');
    const r=spawnSync(process.execPath,[runner,fake,host],{encoding:'utf8',timeout:15000,
      env:{...process.env,KR004_FAKE_MODE:mode,KR004_FAKE_STATE:join(directory,'state'),KR004_FAKE_JOURNAL:journal}});
    let calls=[];
    try { calls=readFileSync(journal,'utf8').trim().split('\n').map(JSON.parse); } catch {}
    return {status:r.status,text:r.stdout+r.stderr,calls};
  } finally { rmSync(directory,{recursive:true,force:true}); } // only test-created temp dir
}
test('reject remote endpoints before any Docker command',()=>{
  for(const host of ['tcp://127.0.0.1:2375','tcp://remote:2376','ssh://remote']){
    const r=execute('success',host); assert.notEqual(r.status,0); assert.equal(r.calls.length,0);
  }
});
test('exact allocated identity, network none, no ports/volumes/secrets in argv; scoped cleanup',()=>{
  const r=execute('success'); assert.equal(r.status,0,r.text);
  const create=r.calls.find(c=>c[2]==='create'); assert.ok(create.includes('none'));
  assert.ok(create.includes('--tmpfs')); assert.ok(!create.some(x=>x==='-p'||x==='-v'||x.includes('POSTGRES_PASSWORD=')));
  assert.ok(!r.calls.some(c=>c.includes('prune')));
  assert.ok(r.calls.some(c=>c[2]==='rm'&&c.at(-1)==='a'.repeat(64)));
  assert.match(r.text,/CLEANUP=VERIFIED/);
});
test('identity mismatch never starts or deletes target',()=>{
  const r=execute('identity'); assert.notEqual(r.status,0);
  assert.ok(!r.calls.some(c=>['start','rm'].includes(c[2])));
});
test('nonempty database stops before migration and cleans only owned container',()=>{
  const r=execute('nonempty'); assert.notEqual(r.status,0);
  assert.match(r.text,/EMPTY_APPLICATION_DATABASE_REQUIRED/);
  assert.doesNotMatch(r.text,/MIGRATION_START/); assert.match(r.text,/CLEANUP=VERIFIED/);
});
test('migration error exposes SQLSTATE not raw stderr or credential',()=>{
  const r=execute('migration'); assert.notEqual(r.status,0);
  assert.match(r.text,/sqlstate=23514/); assert.doesNotMatch(r.text,/ERROR: 23514/);
  assert.match(r.text,/CLEANUP=VERIFIED/);
});
for(const mode of ['test-failure','empty-plan','skip']) test(mode+' cannot pass',()=>{
  const r=execute(mode); assert.notEqual(r.status,0); assert.match(r.text,/DATABASE_TEST_FAILURE/);
  assert.match(r.text,/CLEANUP=VERIFIED/);
});
test('cleanup failure preserves primary test failure',()=>{
  const r=execute('cleanup-primary'); assert.notEqual(r.status,0);
  assert.match(r.text,/DATABASE_TEST_FAILURE/); assert.match(r.text,/CLEANUP_FAILED/);
  assert.doesNotMatch(r.text,/CLEANUP=VERIFIED/);
});
test('unavailable engine after removal is not verified cleanup',()=>{
  const r=execute('cleanup-unknown'); assert.notEqual(r.status,0);
  assert.match(r.text,/CLEANUP_FAILED/); assert.doesNotMatch(r.text,/CLEANUP=VERIFIED/);
});

