#!/usr/bin/env node
// Fake lifecycle only. Never database evidence; invoked by runner.test.mjs.
import { readFileSync, writeFileSync, appendFileSync } from 'node:fs';
const a=process.argv.slice(2), mode=process.env.KR004_FAKE_MODE;
const file=process.env.KR004_FAKE_STATE, journal=process.env.KR004_FAKE_JOURNAL;
appendFileSync(journal, JSON.stringify(a)+'\n');
const args=a.slice(2), cmd=args[0], id='a'.repeat(64);
const output=x=>process.stdout.write(x+'\n');
const load=()=>JSON.parse(readFileSync(file,'utf8'));
if(cmd==='info') output('linux');
else if(cmd==='create') {
  const name=args[args.indexOf('--name')+1], label=args[args.indexOf('--label')+1].split('=');
  writeFileSync(file,JSON.stringify({Id:id,Name:'/'+name,Config:{Labels:{[label[0]]:label[1]},Image:args.at(-1)},
    HostConfig:{NetworkMode:'none',PortBindings:{}},Mounts:[{Type:'tmpfs'}],State:{Running:true}}));
  output(id);
} else if(cmd==='inspect'){
  const v=load(); if(mode==='identity') v.Name='/unrelated';
  output(JSON.stringify([v]));
} else if(cmd==='logs') output('PostgreSQL init process complete; ready for start up.');
else if(cmd==='start') output(id);
else if(cmd==='exec') {
  if(args.includes('pg_isready')) output('accepting connections');
  else {
    const sql=readFileSync(0,'utf8');
    if(sql.includes('current_database()')) output('postgres:supabase_admin\n'+(mode==='nonempty'?'1':'0'));
    else if(sql.includes("to_regprocedure('auth.uid()')")) output('t');
    else if(sql.includes('show server_version')) output('17.6');
    else if(sql.includes('pg_available_extensions')) output('t');
    else if(sql.includes('no_plan()')) {
      if(mode==='test-failure' || mode==='cleanup-primary') output('not ok 1 - synthetic lifecycle failure\n1..1');
      else if(mode==='empty-plan') output('1..0');
      else if(mode==='skip') output('ok 1 - not executed # SKIP\n1..1');
      else output('ok 1 - fake lifecycle only\n1..1');
    } else if(mode==='migration') {
      process.stderr.write('ERROR: 23514\n'+process.env.POSTGRES_PASSWORD);
      process.exitCode=3;
    }
  }
} else if(cmd==='rm') {
  if(mode==='cleanup-primary') process.exitCode=1;
  else output(id);
} else if(cmd==='container') {
  if(mode==='cleanup-unknown') process.exitCode=1;
} else process.exitCode=2;
