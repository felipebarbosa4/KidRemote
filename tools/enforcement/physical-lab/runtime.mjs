// Private stdin/stdout control pipe from native PowerShell. Never print raw errors/config.
import {createInterface} from 'node:readline';
import {Lease,dockerCall,startGateway,check} from './lease.mjs';
import {health} from './health.mjs';
import {createServer} from 'node:net';
const lines=createInterface({input:process.stdin,crlfDelay:Infinity});let lease,gateway,started=false,closing=false;
async function freePort(port){const s=createServer();try{await new Promise((yes,no)=>{s.once('error',no);s.listen(port,'127.0.0.1',yes);});}finally{if(s.listening)await new Promise(r=>s.close(r));}}
async function stop(){if(closing)return;closing=true;try{if(gateway){gateway.kill();await new Promise(r=>{if(gateway.exitCode!==null)r();else gateway.once('exit',r);});}if(started){lease.stop();process.stdout.write('STOPPED_DATA_RETAINED\n');}}catch{process.stdout.write('STOP_UNVERIFIED\n');process.exitCode=1;}lines.close();}
lines.on('line',async line=>{
 try{
  if(line==='STOP'){await stop();return;}
  check(!lease&&line.length<16384,'CONTROL_PROTOCOL');const c=JSON.parse(line);
  if(process.platform==='win32')check(c.host==='npipe:////./pipe/dockerDesktopLinuxEngine','WINDOWS_NATIVE_ONLY');
  await freePort(47366);
  lease=new Lease({...c,call:dockerCall(c.docker,c.host)});const disposition=await lease.start();started=true;
  gateway=await startGateway(lease,c.docker,c.host);const jwt=await health(lease);
  // This is a PRIVATE pipe consumed directly into SecureString, never a console/log record.
  process.stdout.write(JSON.stringify({ready:true,disposition,jwt})+'\n');
 }catch(e){const code=/^[A-Z0-9_]+$/.test(e.message)?e.message:'HOST_RUNTIME_FAILED';process.stdout.write(JSON.stringify({ready:false,code})+'\n');await stop();process.exitCode=1;}
});
lines.on('close',()=>{if(!closing)void stop();});
for(const sig of ['SIGINT','SIGTERM'])process.on(sig,()=>void stop());
