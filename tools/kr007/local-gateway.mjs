// Native host entrypoint. Configuration arrives via stdin, never credential arguments.
import {spawn,spawnSync} from 'node:child_process';
import {createServer} from 'node:http';
import {Readable} from 'node:stream';
import {createHash,randomBytes,randomUUID} from 'node:crypto';
import {createPairing,createPairingHandler} from '../../supabase/functions/pairing/protocol.mjs';
import {createDeviceHandler} from '../../supabase/functions/device-gateway/handler.mjs';
import {databaseRepository} from '../../supabase/functions/device-gateway/local-database.mjs';
let input='';process.stdin.on('data',c=>input+=c);
process.stdin.on('end',async()=>{
 try {await start(JSON.parse(input));}catch{console.error('LOCAL_GATEWAY_START_FAILED');process.exitCode=1;}
});
async function start(c) {
 if(!/^[a-f0-9]{64}$/.test(c.container)||!['npipe:////./pipe/dockerDesktopLinuxEngine','unix:///var/run/docker.sock'].includes(c.host))throw Error('LOCAL_ONLY');
 const inspected=spawnSync(c.docker,['--host',c.host,'inspect',c.container],{encoding:'utf8'});
 if(inspected.status!==0)throw Error('CONTAINER_UNAVAILABLE');
 const x=JSON.parse(inspected.stdout)[0];
 if(x.Id!==c.container || x.Config.Labels[c.label]!==c.owner || Object.keys(x.HostConfig.PortBindings??{}).length)throw Error('OWNER_MISMATCH');
 async function session(action) {
  const p=spawn(c.docker,['--host',c.host,'exec','-i',c.container,'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate','-U','supabase_admin','-d','postgres'],{stdio:['pipe','pipe','pipe']});
  let data='',pending;let stopped=false;
  p.stdout.on('data',b=>{data+=b.toString().replaceAll('\r','');check();});p.stderr.resume();
  function check(){if(pending&&data.includes(pending.marker+'\n')){const at=data.indexOf(pending.marker);const out=data.slice(0,at).trim();data=data.slice(at+pending.marker.length+1);const q=pending;pending=null;q.resolve(out);}}
  p.on('error',()=>{stopped=true;pending?.reject(Error('SQL_SESSION_FAILED'));});
  p.on('close',()=>{stopped=true;pending?.reject(Error('SQL_SESSION_CLOSED'));});
  const timer=setTimeout(()=>p.kill(),15000);
  const query=sql=>new Promise((resolve,reject)=>{
   if(stopped||pending)return reject(Error('SQL_SESSION_UNAVAILABLE'));
   const marker='end_'+randomUUID();pending={marker,resolve,reject};p.stdin.write(sql+'\n\\echo '+marker+'\n');check();
  });
  try{return await action(query);}finally{clearTimeout(timer);p.stdin.end();}
 }
 const lit=s=>"'"+String(s).replaceAll("'","''")+"'";
 const byte=d=>{if(!/^[a-f0-9]{64}$/.test(d))throw Error('DIGEST');return `decode('${d}','hex')`;};
 const adapter={redeem:p=>session(async q=>JSON.parse(await q(`set role service_role; select public.redeem_pairing(${lit(p.session_id)}::uuid,${byte(p.token_digest)},${byte(p.credential_digest)},${byte(p.source_hash)},${lit(JSON.stringify(p.metadata))}::jsonb);`)))};
 const salt=randomBytes(32);
 const pairing=createPairingHandler(adapter,async()=>createHash('sha256').update(salt).update('loopback-lab').digest('hex'));
 const device=createDeviceHandler(databaseRepository(session));
 const reply=(status,body)=>Response.json(body,{status,headers:{'cache-control':'no-store','x-content-type-options':'nosniff'}});
 const server=createServer(async(req,res)=>{
  try {
   const url=new URL(req.url,'http://127.0.0.1');let response;
   if(req.method==='GET'&&url.pathname==='/health'&&!url.search)response=reply(200,{scope:'LOCAL_ENROLLMENT_ONLY'});
   else if(req.method==='POST'&&url.pathname==='/parent/pairing-sessions'&&!url.search) {
    let n=0;for await(const b of req){n+=b.length;if(n>2)break;}
    if(n>2)response=reply(400,{result:'INVALID'});
    else {
     const authorization=req.headers.authorization??'';
     const verified=await fetch('http://127.0.0.1:57361/user',{headers:{authorization},signal:AbortSignal.timeout(5000)});
     const user=verified.ok?await verified.json():null;
     if(!user?.email_confirmed_at)response=reply(401,{result:'DENIED'});
     else {
      const result=await createPairing({create:async digest=>{
       const r=await fetch('http://127.0.0.1:57362/rpc/create_pairing',{method:'POST',headers:{authorization,'content-type':'application/json'},body:JSON.stringify({p_token_digest:'\\x'+digest}),signal:AbortSignal.timeout(5000)});
       if(!r.ok)throw Error('PARENT_RPC_DENIED');return r.json();
      }});
      response=reply(result.result==='CREATED'?200:result.result==='RATE_LIMITED'?429:403,result);
     }
    }
   } else if(req.method==='POST'&&!url.search&&['/pairing/redeem','/device/sync','/device/credentials/rotate'].includes(url.pathname)) {
    const r=new Request('http://127.0.0.1'+req.url,{method:req.method,headers:req.headers,body:Readable.toWeb(req),duplex:'half'});
    response=await (url.pathname==='/pairing/redeem'?pairing:device)(r);
   } else response=reply(404,{result:'UNSUPPORTED_OPERATION'});
   res.writeHead(response.status,Object.fromEntries(response.headers));res.end(Buffer.from(await response.arrayBuffer()));
  } catch {res.writeHead(503,{'content-type':'application/json','cache-control':'no-store'});res.end('{"result":"UNAVAILABLE"}');}
 });
 await new Promise((ok,no)=>{server.once('error',no);server.listen(57366,'127.0.0.1',ok);});
 console.log('LOCAL_ENROLLMENT_GATEWAY_READY');
 for(const signal of ['SIGINT','SIGTERM'])process.once(signal,()=>server.close(()=>process.exit()));
}
