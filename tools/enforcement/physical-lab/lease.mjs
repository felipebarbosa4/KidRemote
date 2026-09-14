// OD-51 only. Separate from disposable CI harness; no remote Docker contexts.
import {spawnSync, spawn} from 'node:child_process';
import {readFileSync, readdirSync, writeFileSync, openSync, closeSync, fsyncSync, renameSync, existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
export function parsePrivateFrame(text){check(typeof text==='string'&&text.length<=16384,'PRIVATE_FRAME_BOUNDS');return JSON.parse(text.replace(/^\uFEFF/,''));}
export const label='org.kidremote.physical-lab';
export const images={
 db:'supabase/postgres:17.6.1.136@sha256:f371b5f3f2ac0a05703f33d6e6134515fb2498cab708fb948a0aeb7481467c00',
 auth:'supabase/gotrue:v2.196.0@sha256:c0c25187a6b835e65a6f6e6c6b39d090e832d40e6de5186f2c038e0411944232',
 rest:'postgrest/postgrest:v14.17@sha256:c9dc201e555f5d8e37e7f39cdd4df0229774996e213bfd7de8d10ac609030f2c',
 mail:'axllent/mailpit:v1.31.1@sha256:98b916bd3c8d61f7633a52d3ea2f58d00620cb01ca57ab59edde68c347a95365'};
export function check(b,c){if(!b)throw Error(c);}
export function schema(root){const files=readdirSync(resolve(root,'supabase/migrations')).filter(f=>/^\d+.*\.sql$/.test(f)).sort();check(files.length>0,'MIGRATIONS_MISSING');return {files,hash:createHash('sha256').update(files.map(f=>f+'\n'+readFileSync(resolve(root,'supabase/migrations',f),'utf8')).join('\n')).digest('hex')};}
export function atomic(path,value){check(!existsSync(path+'.tmp'),'PARTIAL_HOST_STATE');const f=openSync(path+'.tmp','wx',0o600);try{writeFileSync(f,JSON.stringify(value));fsyncSync(f);}finally{closeSync(f);}renameSync(path+'.tmp',path);}
export function dockerCall(docker,host){
 check(['npipe:////./pipe/dockerDesktopLinuxEngine','unix:///var/run/docker.sock'].includes(host),'LOCAL_DOCKER_ONLY');
 const clean={...process.env};for(const k of ['DOCKER_HOST','DOCKER_CONTEXT','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH'])delete clean[k];
 return (args,input,vars={})=>{const p=spawnSync(docker,['--host',host,...args],{input,env:{...clean,...vars},encoding:'utf8',timeout:180000,maxBuffer:8*1024*1024,windowsHide:true});check(!p.error&&p.status===0,'NATIVE_DOCKER_COMMAND_FAILED');return p.stdout.trim();};
}
export class Lease {
 constructor({root,state,source,id,secrets,call}){
  check(/^[a-f0-9]{40}$/.test(source)&&/^[a-f0-9-]{36}$/.test(id),'LEASE_CONFIG');
  for(const k of ['database','jwt'])check(/^[a-f0-9]{64,96}$/.test(secrets[k]),'LEASE_SECRET_FORMAT');
  Object.assign(this,{root,state,source,id,secrets,call});this.schema=schema(root);this.name='kr-physical-'+id;this.network=this.name+'-network';this.volume=this.name+'-data';
  this.labels={[label]:id,[label+'.source']:source,[label+'.schema']:this.schema.hash};
  this.record={format:1,id,source,schema:this.schema.hash,complete:false,network:null,volume:null,containers:{}};
 }
 save(){atomic(this.state,this.record);}
 tags(){return Object.entries(this.labels).flatMap(([k,v])=>['--label',k+'='+v]);}
 owned(x){check(Object.entries(this.labels).every(([k,v])=>x?.[k]===v),'LEASE_OWNERSHIP_MISMATCH');}
 inspect(){
  const r=this.record;check(r.format===1&&r.id===this.id&&r.source===this.source&&r.schema===this.schema.hash,'LEASE_SOURCE_SCHEMA_MISMATCH');
  const n=JSON.parse(this.call(['network','inspect',r.network]))[0];this.owned(n.Labels);
  check(n.Id===r.network&&n.Name===this.network&&n.Driver==='bridge'&&n.Options['com.docker.network.bridge.host_binding_ipv4']==='127.0.0.1'&&n.Options['com.docker.network.bridge.enable_ip_masquerade']==='false','LEASE_NETWORK_MISMATCH');
  const v=JSON.parse(this.call(['volume','inspect',r.volume]))[0];this.owned(v.Labels);check(v.Name===this.volume&&v.Driver==='local'&&Object.keys(v.Options??{}).length===0,'LEASE_VOLUME_MISMATCH');
  for(const [kind,id] of Object.entries(r.containers)){
   const x=JSON.parse(this.call(['inspect',id]))[0];this.owned(x.Config.Labels);
   check(x.Id===id&&x.Name==='/'+this.name+'-'+kind&&x.Config.Image===images[kind]&&x.HostConfig.NetworkMode===this.network&&x.HostConfig.RestartPolicy.Name==='no'&&x.HostConfig.LogConfig.Type==='none'&&!x.HostConfig.Privileged,'LEASE_CONTAINER_MISMATCH');
   const ports={db:{},auth:{'9999/tcp':[{HostIp:'127.0.0.1',HostPort:'47361'}]},rest:{'3000/tcp':[{HostIp:'127.0.0.1',HostPort:'47362'}]},mail:{'8025/tcp':[{HostIp:'127.0.0.1',HostPort:'47365'}]}};
   check(JSON.stringify(x.HostConfig.PortBindings??{})===JSON.stringify(ports[kind]),'LEASE_PORT_MISMATCH');
   const mounts=x.Mounts??[];
   check(kind==='db'?mounts.length===1&&mounts[0].Type==='volume'&&mounts[0].Name===this.volume&&mounts[0].Destination==='/var/lib/postgresql/data':mounts.every(m=>m.Type==='tmpfs'),'LEASE_MOUNT_MISMATCH');
  }
  return r;
 }
 sql(input){return this.call(['exec','-i',this.record.containers.db,'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate','-U','supabase_admin','-d','postgres'],input);}
 create(kind,vars,ports=[]){
  const args=['create','--name',this.name+'-'+kind,...this.tags(),'--network',this.network,'--restart','no','--log-driver','none',
   ...(kind==='db'?['--mount','type=volume,source='+this.volume+',target=/var/lib/postgresql/data']:kind==='mail'?['--tmpfs','/data:rw']:[]),
   ...ports.flatMap(p=>['-p','127.0.0.1:'+p]),...Object.keys(vars).flatMap(k=>['-e',k]),images[kind]];
  const id=this.call(args,undefined,Object.fromEntries(Object.entries(vars).map(([k,v])=>[k,String(v)])));check(/^[a-f0-9]{64}$/.test(id),'LEASE_CONTAINER_ID');this.record.containers[kind]=id;this.save();this.inspect();this.call(['start',id]);
 }
 async readyDb(){for(let i=0;i<90;i++){try{if(this.sql("select 1 where current_setting('listen_addresses') <> '';")==='1')return;}catch{}await new Promise(r=>setTimeout(r,1000));}throw Error('DATABASE_READINESS');}
 async start(){
  check(!existsSync(this.state+'.tmp'),'PARTIAL_HOST_STATE');
  check(this.call(['info','--format','{{.OSType}}'])==='linux','LINUX_DOCKER_REQUIRED');
  if(existsSync(this.state)){
   this.record=JSON.parse(readFileSync(this.state,'utf8'));check(this.record.complete&&Object.keys(this.record.containers).sort().join(',')==='auth,db,mail,rest','PARTIAL_LEASE_REVIEW_REQUIRED');this.inspect();
   for(const id of Object.values(this.record.containers))this.call(['start',id]);await this.readyDb();
   check(this.sql('select source || \':\' || schema_hash from lab_runtime.identity;')===this.source+':'+this.schema.hash,'DATABASE_LEASE_MISMATCH');return 'REUSED';
  }
  // Persist intent before creation. Interrupted creation is review-only, never adopted by name.
  this.save();
  this.record.network=this.call(['network','create','--driver','bridge','--opt','com.docker.network.bridge.host_binding_ipv4=127.0.0.1','--opt','com.docker.network.bridge.enable_ip_masquerade=false',...this.tags(),this.network]);this.save();
  this.record.volume=this.call(['volume','create',...this.tags(),this.volume]);this.save();
  this.create('db',{POSTGRES_PASSWORD:this.secrets.database});await this.readyDb();
  check(this.sql("select count(*) from pg_tables where schemaname in ('public','private');")==='0','NEW_DATABASE_NOT_EMPTY');
  for(const f of this.schema.files)this.sql(readFileSync(resolve(this.root,'supabase/migrations',f),'utf8'));
  this.sql(`set log_statement='none'; alter role supabase_auth_admin password '${this.secrets.database}'; alter role authenticator password '${this.secrets.database}'; create schema lab_runtime; revoke all on schema lab_runtime from public; create table lab_runtime.identity(source text not null,schema_hash text not null); insert into lab_runtime.identity values('${this.source}','${this.schema.hash}');`);
  this.create('mail',{MP_DATABASE:'/data/mail.db',MP_MAX_MESSAGES:50},['47365:8025']);
  const db=this.name+'-db';
  this.create('auth',{
   GOTRUE_API_HOST:'0.0.0.0',GOTRUE_API_PORT:9999,API_EXTERNAL_URL:'http://127.0.0.1:47361',GOTRUE_DB_DRIVER:'postgres',GOTRUE_DB_DATABASE_URL:`postgres://supabase_auth_admin:${this.secrets.database}@${db}:5432/postgres`,
   GOTRUE_SITE_URL:'http://127.0.0.1:47361',GOTRUE_URI_ALLOW_LIST:'',GOTRUE_DISABLE_SIGNUP:false,GOTRUE_JWT_SECRET:this.secrets.jwt,GOTRUE_JWT_EXP:3600,GOTRUE_JWT_AUD:'authenticated',GOTRUE_JWT_DEFAULT_GROUP_NAME:'authenticated',
   GOTRUE_EXTERNAL_EMAIL_ENABLED:true,GOTRUE_MAILER_AUTOCONFIRM:false,GOTRUE_SMTP_HOST:this.name+'-mail',GOTRUE_SMTP_PORT:1025,GOTRUE_SMTP_ADMIN_EMAIL:'noreply@example.test',GOTRUE_SMTP_SENDER_NAME:'KidRemote physical lab',GOTRUE_SMTP_MAX_FREQUENCY:'1s',GOTRUE_RATE_LIMIT_EMAIL_SENT:100,GOTRUE_MAILER_OTP_EXP:300,LOG_LEVEL:'error'},['47361:9999']);
  this.create('rest',{PGRST_DB_URI:`postgres://authenticator:${this.secrets.database}@${db}:5432/postgres`,PGRST_DB_SCHEMAS:'public',PGRST_DB_ANON_ROLE:'anon',PGRST_JWT_SECRET:this.secrets.jwt,PGRST_LOG_LEVEL:'crit'},['47362:3000']);
  this.record.complete=true;this.save();return 'CREATED';
 }
 status(){this.inspect();return {lease:this.id,source:this.source,schema:this.schema.hash,complete:this.record.complete,persistence:'TASK_OWNED_SYNTHETIC'};}
 stop(){this.inspect();for(const id of Object.values(this.record.containers).reverse())this.call(['stop',id]);return 'STOPPED_DATA_RETAINED';}
 teardown(admit){this.inspect();admit({stage:'TEARDOWN_ADMITTED',lease:this.id,source:this.source,schema:this.schema.hash});this.inspect();for(const id of Object.values(this.record.containers).reverse())this.call(['rm','-f',id]);this.call(['volume','rm',this.record.volume]);this.call(['network','rm',this.record.network]);this.record.complete=false;this.record.tornDown=true;this.save();return 'EXACT_LEASE_REMOVED';}
}
export async function startGateway(lease,docker,host){
 const p=spawn(process.execPath,[resolve(lease.root,'tools/kr007/local-gateway.mjs')],{stdio:['pipe','pipe','pipe'],windowsHide:true});let ready=false;p.stdout.on('data',b=>{if(b.toString().includes('LOCAL_ENROLLMENT_GATEWAY_READY'))ready=true;});p.stderr.resume();p.on('error',()=>{});
 p.stdin.end(JSON.stringify({docker,host,container:lease.record.containers.db,label,owner:lease.id}));
 for(let i=0;i<100&&!ready&&p.exitCode===null;i++)await new Promise(r=>setTimeout(r,100));
 if(!ready){p.kill();throw Error('GATEWAY_READINESS');}return p;
}
