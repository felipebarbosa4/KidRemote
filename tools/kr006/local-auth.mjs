// Reuses the ownership-verified KR-004 DB runner. No secrets in argv or output.
import {randomBytes} from 'node:crypto';
import {spawn,execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const images={
 auth:'supabase/gotrue:v2.196.0@sha256:c0c25187a6b835e65a6f6e6c6b39d090e832d40e6de5186f2c038e0411944232',
 rest:'postgrest/postgrest:v14.17@sha256:c9dc201e555f5d8e37e7f39cdd4df0229774996e213bfd7de8d10ac609030f2c',
 mail:'axllent/mailpit:v1.31.1@sha256:98b916bd3c8d61f7633a52d3ea2f58d00620cb01ca57ab59edde68c347a95365',
};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
export async function runParentAuth({sql,call,env,name,label,token,network,databaseHost,windows,keep,runtime=false,enrollment=false,enrollmentRuntime=false,gatewayConfig}) {
 const resources=[];let primary,gateway;
 const secrets=new Set();
 const jwt=randomBytes(48).toString('hex'), password=randomBytes(32).toString('hex');
 const check=(b,c)=>{if(!b) throw Error(c);};
 // Windows-owned loopback is contacted with the existing native Node process.
 // Request bodies/tokens travel through stdin, never argv/files/tool output.
 const http=async(url,method='GET',body,headers={})=>{
  for(const key of ['password','refresh_token','token_hash']) if(typeof body?.[key]==='string') secrets.add(body[key]);
  if(headers.authorization?.startsWith('Bearer ')) secrets.add(headers.authorization.slice(7));
  const request={url,options:{method,headers:{'content-type':'application/json',...headers},...(body===undefined?{}:{body:JSON.stringify(body)})}};
  if(!windows) {
   try {const r=await fetch(url,{...request.options,signal:AbortSignal.timeout(10000)});return {status:r.status,body:await r.text()};}
   catch{return {status:0,body:''};}
  }
  return new Promise(resolve=>{
   const script="let s='';process.stdin.on('data',x=>s+=x);process.stdin.on('end',async()=>{try{const q=JSON.parse(s);const r=await fetch(q.url,{...q.options,signal:AbortSignal.timeout(10000)});process.stdout.write(JSON.stringify({status:r.status,body:await r.text()}));}catch{process.stdout.write('{\"status\":0,\"body\":\"\"}');}});";
   const p=spawn('/mnt/c/Program Files/nodejs/node.exe',['-e',script],{stdio:['pipe','pipe','pipe']});
   let out='';p.stdout.on('data',x=>out+=x);p.stderr.resume();p.on('error',()=>resolve({status:0,body:''}));
   p.on('close',()=>{try{resolve(JSON.parse(out));}catch{resolve({status:0,body:''});}});p.stdin.end(JSON.stringify(request));
  });
 };
 function verify(r) {
  const x=JSON.parse(call(['inspect',r.id]))[0];
  check(x.Id===r.id && x.Name==='/'+r.name && x.Config.Labels[label]===token && x.Config.Image===r.image &&
   x.HostConfig.NetworkMode===network && (x.Mounts??[]).every(m=>m.Type==='tmpfs') &&
   Object.values(x.HostConfig.PortBindings??{}).flat().every(p=>p.HostIp==='127.0.0.1'),'AUTH_RESOURCE_NOT_VERIFIED');
 }
 function create(kind,vars,ports) {
  for(const [k,v] of Object.entries(vars)) {env[k]=String(v);if(windows) env.WSLENV+=':'+k+'/w';}
  const r={name:name+'-'+kind,image:images[kind]};
  r.id=call(['create','--name',r.name,'--label',label+'='+token,'--network',network,'--restart','no',
   ...ports.flatMap(p=>['-p','127.0.0.1:'+p]),...(kind==='mail'?['--tmpfs','/data:rw']:[]),
   ...Object.keys(vars).flatMap(k=>['-e',k]),r.image]);
  resources.push(r);verify(r);call(['start',r.id]);return r;
 }
 async function gatewayAvailable(enabled) {
  if(!enrollment)throw Error('GATEWAY_NOT_IN_SCOPE');
  if(!enabled){
   if(!gateway)throw Error('OWN_GATEWAY_MISSING');gateway.kill();
   for(let i=0;i<20&&(await http('http://127.0.0.1:57366/health')).status!==0;i++)await sleep(250);
   check((await http('http://127.0.0.1:57366/health')).status===0,'GATEWAY_STOP_UNVERIFIED');gateway=null;return;
  }
  check(!gateway,'GATEWAY_ALREADY_RUNNING');
  const path=fileURLToPath(new URL('../kr007/local-gateway.mjs',import.meta.url));
  const win=p=>execFileSync('wslpath',['-w',p],{encoding:'utf8'}).trim();
  gateway=spawn(windows?'/mnt/c/Program Files/nodejs/node.exe':process.execPath,[windows?win(path):path],{stdio:['pipe','pipe','pipe']});
  let ready=false;gateway.stdout.on('data',b=>{if(b.toString().includes('LOCAL_ENROLLMENT_GATEWAY_READY'))ready=true;});gateway.stderr.resume();
  gateway.stdin.end(JSON.stringify({...gatewayConfig,docker:windows?win(gatewayConfig.docker):gatewayConfig.docker}));
  for(let i=0;i<30&&!ready;i++)await sleep(1000);
  check(ready&&(await http('http://127.0.0.1:57366/health')).status===200,'ENROLLMENT_GATEWAY_UNAVAILABLE');
 }
 try {
  // Credentials generated for this isolated DB only; statement body not emitted.
  sql(`set log_statement='none'; alter role supabase_auth_admin password '${password}'; alter role authenticator password '${password}';`);
  create('mail',{MP_DATABASE:'/data/mail.db',MP_MAX_MESSAGES:50},['57365:8025']);
  create('auth',{
   GOTRUE_API_HOST:'0.0.0.0',GOTRUE_API_PORT:9999,API_EXTERNAL_URL:'http://127.0.0.1:57361',
   GOTRUE_DB_DRIVER:'postgres',GOTRUE_DB_DATABASE_URL:`postgres://supabase_auth_admin:${password}@${databaseHost}:5432/postgres`,
   GOTRUE_SITE_URL:'http://127.0.0.1:57361',GOTRUE_URI_ALLOW_LIST:'',GOTRUE_DISABLE_SIGNUP:false,
   GOTRUE_JWT_SECRET:jwt,GOTRUE_JWT_EXP:300,GOTRUE_JWT_AUD:'authenticated',GOTRUE_JWT_DEFAULT_GROUP_NAME:'authenticated',
   GOTRUE_EXTERNAL_EMAIL_ENABLED:true,GOTRUE_MAILER_AUTOCONFIRM:false,
   GOTRUE_SMTP_HOST:name+'-mail',GOTRUE_SMTP_PORT:1025,GOTRUE_SMTP_ADMIN_EMAIL:'noreply@example.test',
   GOTRUE_SMTP_SENDER_NAME:'KidRemote local lab',GOTRUE_SMTP_MAX_FREQUENCY:'1s',GOTRUE_RATE_LIMIT_EMAIL_SENT:100,
   GOTRUE_MAILER_OTP_EXP:300,LOG_LEVEL:'error',
  },['57361:9999']);
  create('rest',{PGRST_DB_URI:`postgres://authenticator:${password}@${databaseHost}:5432/postgres`,
   PGRST_DB_SCHEMAS:'public',PGRST_DB_ANON_ROLE:'anon',PGRST_JWT_SECRET:jwt,PGRST_LOG_LEVEL:'crit'},['57362:3000']);
  for(let i=0;i<45;i++) {
   if((await http('http://127.0.0.1:57361/health')).status===200 && (await http('http://127.0.0.1:57362/')).status===200) break;
   if(i===44) {
    for(const r of resources) {
     const x=JSON.parse(call(['inspect',r.id]))[0];
     const output=call(['logs',r.id]);
     console.log(JSON.stringify({stage:'SERVICE_READINESS',kind:r.name.slice(name.length+1),running:x.State.Running,exitCode:x.State.ExitCode,
      passwordRejected:/password authentication failed/i.test(output),connectionRefused:/connection refused/i.test(output),migrationError:/migration.*(?:fail|error)|(?:fail|error).*migration/i.test(output)}));
    }
    console.log('AUTH_HTTP_STATUS='+(await http('http://127.0.0.1:57361/health')).status);
    console.log('REST_HTTP_STATUS='+(await http('http://127.0.0.1:57362/')).status);
    throw Error('LOCAL_AUTH_REST_READINESS_UNAVAILABLE');
   }await sleep(1000);
  }
  console.log('LOCAL_AUTH_REST_MAIL_READY:confirmationRequired=true:loopbackOnly=true');
  if(enrollment) {
   await gatewayAvailable(true);
   console.log('LOCAL_ENROLLMENT_GATEWAY_VERIFIED_LOOPBACK');
  }
  if(keep) {
   console.log('PARENT_DEV_READY:Auth=127.0.0.1:57361:REST=127.0.0.1:57362:Mail=127.0.0.1:57365:CtrlC=scopedCleanup');
   await new Promise(r=>{process.once('SIGINT',r);process.once('SIGTERM',r);});
  } else {
   const mailResource=resources.find(r=>r.image===images.mail);
   const mailAvailable=enabled=>{verify(mailResource);call([enabled?'start':'stop',mailResource.id]);};
   const restResource=resources.find(r=>r.image===images.rest);
   const restAvailable=enabled=>{verify(restResource);call([enabled?'start':'stop',restResource.id]);};
   const {testParentAuth}=await import('./real-auth-tests.mjs');await testParentAuth({http,sql,mailAvailable,restAvailable});
   if(enrollment) {
    const {testEnrollment}=await import('../kr007/backend-tests.mjs');await testEnrollment({http,sql});
   }
   if(enrollmentRuntime) {
    const {testEnrollmentRuntime}=await import('../kr007/android-runtime.mjs');await testEnrollmentRuntime({restAvailable,sql,gatewayAvailable});
   }
   if(runtime) {
    const {testAndroidRuntime}=await import('./android-runtime.mjs');
    await testAndroidRuntime({restAvailable,sql});
   }
   for(const r of resources) {
    const output=call(['logs',r.id]);
    check([...secrets].filter(s=>s.length>=16).every(s=>!output.includes(s)),'RAW_AUTH_SECRET_IN_SERVICE_LOG');
   }
   console.log('AUTH_SERVICE_LOG_SECRET_SCAN_PASS');
  }
 } catch(e) {primary=e;}
 finally {
  if(gateway) {
   gateway.kill();
   for(let i=0;i<15&&(await http('http://127.0.0.1:57366/health')).status!==0;i++)await sleep(500);
   if((await http('http://127.0.0.1:57366/health')).status!==0)primary??=Error('GATEWAY_CLEANUP_UNVERIFIED');
   else console.log('ENROLLMENT_GATEWAY_CLEANUP_VERIFIED');
  }
  for(const r of resources.reverse()) {
   try {verify(r);call(['rm','-f',r.id]);check(call(['container','ls','-a','--filter','id='+r.id,'--format','{{.ID}}'])==='','AUTH_CLEANUP_UNVERIFIED');}
   catch(e){primary??=e;console.error('AUTH_RESOURCE_CLEANUP_FAILED:'+r.id);}
  }
 }
 if(primary) throw primary;
 console.log('AUTH_SERVICE_CLEANUP_VERIFIED');
}
