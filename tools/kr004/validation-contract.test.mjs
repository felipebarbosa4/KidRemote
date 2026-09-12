import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { requiredMigrations,requiredSuites,requireInventory,localEndpoints } from './validation-contract.mjs';
test('complete inventory accepted; each missing migration/suite rejected',()=>{
  assert.doesNotThrow(()=>requireInventory(requiredMigrations,requiredSuites));
  for(const f of requiredMigrations) assert.throws(()=>requireInventory(requiredMigrations.filter(x=>x!==f),requiredSuites));
  for(const f of requiredSuites) assert.throws(()=>requireInventory(requiredMigrations,requiredSuites.filter(x=>x!==f)));
});
test('only named local Unix/npipe endpoints, never TCP or a remote Docker context',()=>{
  assert.equal(localEndpoints.length,2);assert.ok(localEndpoints.every(x=>x.startsWith('unix:')||x.startsWith('npipe:')));
});
test('recorded AC-1–4 assertions remain unchanged except explicit AC-6 table inventory increment',()=>{
  for(const [path,hash] of [
    ['supabase/migrations/202609110001_schema_rls.sql','8865eb717c5fd7057bb0b0c0cf268f72e385e36bba8d5733c13079d230a4f781'],
    ['supabase/tests/01_rls.test.sql','8fe4df55823176ba18277b1338b8b67ee49d3574fe4f10d4364f37d82178b42c'],
    ['supabase/tests/02_constraints.test.sql','8fb621c0b0336c3415f70567a87460aaf467a4d95d2a6f5fc55c16cf3d771d64'],
  ]) {
    let source=readFileSync(new URL('../../'+path,import.meta.url),'utf8');
    if(path.endsWith('01_rls.test.sql')) {
      assert.ok(source.includes('count(*) = 16 and bool_and(c.relrowsecurity)'));
      assert.ok(source.includes('all 16 app tables enable RLS'));
      source=source.replace('count(*) = 16 and bool_and(c.relrowsecurity)','count(*) = 15 and bool_and(c.relrowsecurity)').replace('all 16 app tables enable RLS','all 15 app tables enable RLS');
    }
    assert.equal(createHash('sha256').update(source).digest('hex'),hash,path);
  }
});
