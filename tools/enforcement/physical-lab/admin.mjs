// Native private pipe only; status/explicit teardown of exactly the protected lease.
import {readFileSync} from 'node:fs';import {dirname,join} from 'node:path';import {randomUUID} from 'node:crypto';
import {Lease,dockerCall,atomic,check} from './lease.mjs';
let input='';process.stdin.on('data',b=>{input+=b;});process.stdin.on('end',()=>{
 try{
  check(input.length<16384,'ADMIN_BOUNDS');const c=JSON.parse(input);check(['status','teardown'].includes(c.action),'ADMIN_ACTION');
  const lease=new Lease({...c,call:dockerCall(c.docker,c.host)});lease.record=JSON.parse(readFileSync(c.state,'utf8'));
  if(c.action==='status'){process.stdout.write(JSON.stringify(lease.status()));return;}
  check(c.confirmLease===lease.id,'EXPLICIT_LEASE_CONFIRMATION_REQUIRED');
  const path=join(dirname(c.state),'teardown-'+randomUUID()+'.json');
  const verdict=lease.teardown(row=>atomic(path,{...row,utc:new Date().toISOString(),originalVerdictsUnchanged:true}));
  atomic(path+'.result',{verdict,utc:new Date().toISOString()});process.stdout.write(verdict);
 }catch{process.stderr.write('LAB_ADMIN_FAILED_CLOSED');process.exitCode=1;}
});
