#!/usr/bin/env node
// Bounded local pre-exposure check, not a production/deployment approval command.
import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { localEndpoints } from './validation-contract.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const args=process.argv.slice(2);
if(args.length!==2 || !localEndpoints.includes(args[1])) {
  console.error('EXPLICIT_LOCAL_DOCKER_CLIENT_AND_ENDPOINT_REQUIRED');
  process.exit(1);
}
const tests=readdirSync(new URL('./',import.meta.url)).filter(f=>f.endsWith('.test.mjs')).sort().map(f=>'tools/kr004/'+f);
tests.push(...readdirSync(new URL('../kr005/',import.meta.url)).filter(f=>f.endsWith('.test.mjs')).sort().map(f=>'tools/kr005/'+f));
const checks=[
  ['repository',process.execPath,['tools/validate.mjs']],
  ['HTTP_and_runner_tests',process.execPath,['--test',...tests]],
  ['actual_disposable_database',process.execPath,['tools/kr004/test-local-db.mjs',...args,'--pairing']],
  ['worktree_whitespace','git',['diff','--check']],
  ['staged_whitespace','git',['diff','--cached','--check']],
  ['commit_whitespace','git',['show','--format=','--check','HEAD']],
];
for(const [label,exe,argv] of checks) {
  console.log('LOCAL_CHECK_START='+label);
  const result=spawnSync(exe,argv,{cwd:root,stdio:'inherit'});
  if(result.error || result.status!==0) { console.error('LOCAL_CHECK_FAILED='+label);process.exit(1); }
}
console.log('KR004_LOCAL_CHECKS_PASSED:DEPLOYMENT_AUTHORIZED=false');
