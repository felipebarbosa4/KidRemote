import test from 'node:test';import assert from 'node:assert/strict';
import {mkdtempSync,rmSync,readFileSync,writeFileSync} from 'node:fs';import {tmpdir} from 'node:os';import {join,resolve} from 'node:path';import {randomUUID} from 'node:crypto';
import {Lease,label,images} from './lease.mjs';
class Docker {
 constructor(){this.items={};this.volumes={};this.networks={};this.calls=[];this.number=1;this.schema='';this.data='';}
 call=(a,input,env={})=>{
  this.calls.push(a);const tags=()=>Object.fromEntries(a.flatMap((v,i)=>v==='--label'?[a[i+1].split('=')]:[]));
  if(a[0]==='info')return 'linux';if(a[0]==='logs')return 'PostgreSQL init process complete; ready for start up.';
  if(a[0]==='network'&&a[1]==='create'){const id='network';this.networks[id]={Id:id,Name:a.at(-1),Labels:tags(),Driver:'bridge',Options:{'com.docker.network.bridge.host_binding_ipv4':'127.0.0.1','com.docker.network.bridge.enable_ip_masquerade':'false'}};return id;}
  if(a[0]==='network'&&a[1]==='inspect')return JSON.stringify([this.networks[a[2]]]);
  if(a[0]==='volume'&&a[1]==='create'){const name=a.at(-1);this.volumes[name]={Name:name,Labels:tags(),Driver:'local',Options:{}};return name;}
  if(a[0]==='volume'&&a[1]==='inspect')return JSON.stringify([this.volumes[a[2]]]);
  if(a[0]==='create'){
   const id=(this.number++).toString(16).padStart(64,'0'),kind=Object.entries(images).find(([,v])=>v===a.at(-1))[0];const ports={};
   a.forEach((v,i)=>{if(v==='-p'){const p=a[i+1].split(':');ports[p[2]+'/tcp']=[{HostIp:p[0],HostPort:p[1]}];}});
   this.items[id]={Id:id,Name:'/'+a[a.indexOf('--name')+1],Config:{Labels:tags(),Image:a.at(-1)},HostConfig:{NetworkMode:a[a.indexOf('--network')+1],RestartPolicy:{Name:'no'},Privileged:false,PortBindings:ports},Mounts:kind==='db'?[{Type:'volume',Name:Object.keys(this.volumes)[0],Destination:'/var/lib/postgresql/data'}]:[],State:{Running:false}};return id;
  }
  if(a[0]==='inspect')return JSON.stringify([this.items[a[1]]]);
  if(a[0]==='start'||a[0]==='stop'){this.items[a[1]].State.Running=a[0]==='start';return a[1];}
  if(a[0]==='exec'){
   if(input==='select 1;')return '1';if(input?.startsWith('select count(*) from pg_tables'))return '0';
   if(input?.includes('create schema lab_runtime'))this.schema=input.match(/values\('([a-f0-9]+)','([a-f0-9]+)'\)/).slice(1).join(':');
   if(input?.startsWith('select source'))return this.schema;return '';
  }
  if(a[0]==='rm'){delete this.items[a[2]];return '';}
  if(a[1]==='rm'){delete (a[0]==='volume'?this.volumes:this.networks)[a[2]];return '';}
  throw Error('FAKE_UNSUPPORTED');
 };
}
function fixture(){const dir=mkdtempSync(join(tmpdir(),'od51-'));const fake=new Docker();const config={root:resolve('.'),state:join(dir,'state.json'),source:'a'.repeat(40),id:randomUUID(),secrets:{database:'b'.repeat(64),jwt:'c'.repeat(96)},call:fake.call};return {dir,fake,config,lease:new Lease(config)};}
async function run(f){const x=fixture();try{await f(x);}finally{rmSync(x.dir,{recursive:true});}}
test('first creates one lease; second reuses exact volume and resources',()=>run(async x=>{assert.equal(await x.lease.start(),'CREATED');x.fake.data='synthetic enrolled epoch';x.lease.stop();const second=new Lease(x.config);assert.equal(await second.start(),'REUSED');assert.equal(x.fake.data,'synthetic enrolled epoch');assert.equal(x.fake.calls.filter(a=>a[0]==='create').length,4);assert.equal(Object.keys(x.fake.volumes).length,1);}));
test('wrong ownership prevents start, stop and teardown',()=>run(async x=>{await x.lease.start();x.fake.items[x.lease.record.containers.db].Config.Labels[label]=randomUUID();await assert.rejects(()=>new Lease(x.config).start(),/OWNERSHIP/);assert.throws(()=>x.lease.stop(),/OWNERSHIP/);assert.throws(()=>x.lease.teardown(()=>assert.fail()),/OWNERSHIP/);}));
test('wrong source and schema fail closed',()=>run(async x=>{await x.lease.start();await assert.rejects(()=>new Lease({...x.config,source:'d'.repeat(40)}).start(),/SOURCE_SCHEMA/);const r=JSON.parse(readFileSync(x.config.state));r.schema='0'.repeat(64);writeFileSync(x.config.state,JSON.stringify(r));await assert.rejects(()=>new Lease(x.config).start(),/SOURCE_SCHEMA/);}));
test('foreign mount or nonloopback port rejects reuse',()=>run(async x=>{await x.lease.start();const d=x.fake.items[x.lease.record.containers.db];d.Mounts[0].Name='foreign';await assert.rejects(()=>new Lease(x.config).start(),/MOUNT/);d.Mounts[0].Name=x.lease.volume;d.HostConfig.PortBindings={'5432/tcp':[{HostIp:'0.0.0.0',HostPort:'5432'}]};await assert.rejects(()=>new Lease(x.config).start(),/PORT/);}));
test('partial state never recreates resources or overwrites attempt',()=>run(async x=>{await x.lease.start();writeFileSync(x.config.state+'.tmp','truncated');const count=x.fake.calls.length;await assert.rejects(()=>new Lease(x.config).start(),/PARTIAL/);assert.equal(x.fake.calls.length,count);}));
test('teardown admission failure deletes nothing; exact teardown excludes foreign resources',()=>run(async x=>{await x.lease.start();assert.throws(()=>x.lease.teardown(()=>{throw Error('journal disk failed');}));assert.equal(Object.keys(x.fake.items).length,4);x.fake.items.foreign={};let admission;assert.equal(x.lease.teardown(r=>admission=r),'EXACT_LEASE_REMOVED');assert.equal(admission.lease,x.config.id);assert.deepEqual(Object.keys(x.fake.items),['foreign']);assert.equal(Object.keys(x.fake.volumes).length,0);}));
test('secrets absent in public state and command arguments',()=>run(async x=>{await x.lease.start();const publicBytes=readFileSync(x.config.state,'utf8')+JSON.stringify(x.fake.calls);for(const s of Object.values(x.config.secrets))assert.ok(!publicBytes.includes(s));}));
test('owner runtime has no WSL chain and disposable harness unchanged',()=>{for(const f of ['tools/enforcement/product-oracle/BackendHost.psm1','tools/enforcement/physical-lab/runtime.mjs','tools/enforcement/physical-lab/lease.mjs'])assert.doesNotMatch(readFileSync(f,'utf8'),/wsl\.exe|wslpath|\/mnt\/c\/|WSLENV|\/usr\/bin\/node/);assert.match(readFileSync('tools/kr004/test-local-db.mjs','utf8'),/--tmpfs/);assert.doesNotMatch(readFileSync('tools/kr004/test-local-db.mjs','utf8'),/physical-lab/);});
