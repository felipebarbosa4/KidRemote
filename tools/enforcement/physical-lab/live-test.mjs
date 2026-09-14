// CI/Linux owned Docker only; no ADB or device commands. Real persistent lifecycle.
import {mkdtempSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';import {join,resolve} from 'node:path';import {randomUUID,randomBytes} from 'node:crypto';
import {Lease,dockerCall,startGateway,check} from './lease.mjs';import {health,wire} from './health.mjs';
const dir=mkdtempSync(join(tmpdir(),'kr-physical-ci-'));const docker=process.argv[2]??'docker',host='unix:///var/run/docker.sock';
const config={root:resolve('.'),state:join(dir,'resources.json'),source:'a'.repeat(40),id:randomUUID(),call:dockerCall(docker,host),secrets:{database:randomBytes(32).toString('hex'),jwt:randomBytes(48).toString('hex'),parentPassword:randomBytes(32).toString('hex')+'aA1!',probePassword:randomBytes(32).toString('hex')+'aA1!'}};
let lease=new Lease(config),gateway,passed=0;
const ok=(b,c)=>{check(b,c);passed++;console.log('LAB_LIVE_CHECK='+c);};
async function stopGateway(){if(gateway){gateway.kill();await new Promise(r=>gateway.once('exit',r));gateway=null;}}
try{
 ok(await lease.start()==='CREATED','FIRST_LEASE');gateway=await startGateway(lease,docker,host);let jwt=await health(lease);passed++;
 const q=await wire(47366,'/parent/pairing-sessions',{},jwt);const d=await wire(47366,'/pairing/redeem',{qr:q.qr,metadata:{platform:'android',os_major:16,agent_version:'od51-ci',nickname:'synthetic-persistence'}});ok(d.result==='REDEEMED','REAL_ENROLLMENT');
 const before=await wire(47366,'/device/sync',{protocol_version:1,after_version:0},d.credential);ok(before.device_id===d.device_id,'REAL_DEVICE_AUTH');
 const ids=JSON.stringify(lease.record);await stopGateway();ok(lease.stop()==='STOPPED_DATA_RETAINED','STOP_RETAINS');
 lease=new Lease(config);ok(await lease.start()==='REUSED','SECOND_START_REUSE');ok(JSON.stringify(lease.record)===ids,'EXACT_RESOURCES');gateway=await startGateway(lease,docker,host);jwt=await health(lease);passed++;
 const after=await wire(47366,'/device/sync',{protocol_version:1,after_version:0},d.credential);ok(after.device_id===before.device_id&&after.policy_epoch===before.policy_epoch,'ENROLLMENT_SURVIVES_RESTART');
 const page=await wire(47362,'/rpc/parent_devices',{p_after:null},jwt);ok(page.devices.length===1&&page.devices[0].id===d.device_id,'NO_DUPLICATE_CHILD');
 ok(lease.sql(`select count(*) from private.device_credentials where device_id='${d.device_id}';`)==='1','SAME_CREDENTIAL');
 for(const id of Object.values(lease.record.containers)){const x=JSON.parse(lease.call(['inspect',id]))[0];check(x.HostConfig.LogConfig.Type==='none','LOG_RETENTION_NOT_DISABLED');}ok(true,'SERVICE_LOG_RETENTION_DISABLED');
 console.log('PHYSICAL_LAB_LIVE_CHECKS='+passed);
} catch(e){console.error('LAB_LIVE_FAILED:'+(/^[A-Z0-9_]+$/.test(e.message)?e.message:'UNCLASSIFIED'));process.exitCode=1;}
finally{await stopGateway();try{lease.teardown(r=>{console.log('CI_EXACT_LEASE_TEARDOWN_ADMITTED');});console.log('CI_EXACT_LEASE_TEARDOWN_VERIFIED');rmSync(dir,{recursive:true});}catch{console.error('CI_LEASE_CLEANUP_UNVERIFIED');process.exitCode=1;}}
