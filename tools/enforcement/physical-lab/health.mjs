// Real Auth, bootstrap, pairing and canonical control; only synthetic lease accounts.
import {randomUUID} from 'node:crypto';
import {check} from './lease.mjs';
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
export async function wire(port,path,body,jwt){
 const r=await fetch('http://127.0.0.1:'+port+path,{method:body===undefined?'GET':'POST',headers:{'content-type':'application/json',...(jwt?{authorization:'Bearer '+jwt}:{})},...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(10000)});
 check(r.status===200,'LIVE_HTTP_'+r.status);const text=await r.text();check(text.length<=65536,'LIVE_HTTP_BOUNDS');return JSON.parse(text);
}
async function parent(lease,email,password){
 check(/^product-lab-(probe-)?[a-f0-9-]{36}@example\.test$/.test(email)&&/^[a-f0-9]{64}aA1!$/.test(password),'PARENT_SECRET_FORMAT');
 const count=lease.sql(`select count(*) from auth.users where email='${email}';`);check(['0','1'].includes(count),'LAB_AUTH_AMBIGUOUS');
 if(count==='0'){
  await wire(47361,'/signup',{email,password});let token;
  for(let i=0;i<30&&!token;i++){
   const m=await wire(47365,'/api/v1/messages');const rows=m.messages.filter(m=>m.To.some(x=>x.Address===email));check(rows.length<=1,'LAB_MAIL_AMBIGUOUS');
   if(rows.length){const d=await wire(47365,'/api/v1/message/'+rows[0].ID);const urls=d.HTML.replaceAll('&amp;','&').match(/http:\/\/127\.0\.0\.1:47361\/verify\?[^\s"<>]+/g)??[];check(urls.length===1,'LAB_MAIL_SCHEMA');token=new URL(urls[0]).searchParams.get('token');}else await sleep(200);
  }
  check(/^[a-f0-9]+$/.test(token??''),'LAB_MAIL_TIMEOUT');await wire(47361,'/verify',{token_hash:token,type:'signup'});
 }
 const s=await wire(47361,'/token?grant_type=password',{email,password});check(/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(s.access_token),'LAB_AUTH_SESSION');
 const h=await wire(47362,'/rpc/bootstrap_household',{p_timezone:'Etc/UTC'},s.access_token);check(/^[a-f0-9-]{36}$/.test(h.household_id),'LAB_BOOTSTRAP');return s.access_token;
}
export async function health(lease){
 for(let i=0;i<45;i++){try{await wire(47361,'/health');await wire(47362,'/');await wire(47366,'/health');break;}catch(e){if(i===44)throw e;await sleep(1000);}}
 const s=lease.secrets;
 const probe=await parent(lease,'product-lab-probe-'+lease.id+'@example.test',s.probePassword);
 let page=await wire(47362,'/rpc/parent_devices',{p_after:null},probe);check(page.protocol_version===1&&page.devices.length<=1,'PROBE_SCOPE');
 if(!page.devices.length){
  const q=await wire(47366,'/parent/pairing-sessions',{},probe);check(q.result==='CREATED','PROBE_PAIRING');
  const d=await wire(47366,'/pairing/redeem',{qr:q.qr,metadata:{platform:'android',os_major:16,agent_version:'od51-host-probe',nickname:'synthetic-host-probe'}});check(d.result==='REDEEMED','PROBE_REDEMPTION');
  page=await wire(47362,'/rpc/parent_devices',{p_after:null},probe);
 }
 check(page.devices.length===1,'PROBE_DEVICE');const d=page.devices[0];let v=d.version;
 const op=async(kind,payload)=>{const operation_id=randomUUID();const q={protocol_version:1,operation_id,device_id:d.id,kind,payload,expected_version:v};let r;
  for(let i=0;i<2;i++){try{r=await wire(47366,'/parent/devices/'+d.id+'/operations',q,probe);break;}catch(e){if(i||!['LIVE_HTTP_503'].includes(e.message)&&e.name!=='TimeoutError'&&e.name!=='TypeError')throw e;}}
  check(r?.status==='accepted'&&r.operation_id===operation_id&&r.device_id===d.id&&r.policy_epoch===d.policy_epoch&&r.version===v+1,'PROBE_CONTROL');v=r.version;};
 if(!d.policy_configured)await op('SET_DAILY_LIMIT',{daily_limit_seconds:3600});
 try{await op('LOCK',{});}finally{await op('UNLOCK',{});}
 page=await wire(47362,'/rpc/parent_devices',{p_after:null},probe);
 check(page.devices.length===1&&page.devices[0].id===d.id&&page.devices[0].version===v,'PROBE_FINAL_VERSION');
 check(lease.sql(`select manual_lock from public.device_policies where device_id='${d.id}';`)==='f','PROBE_UNLOCK_UNVERIFIED');
 return parent(lease,'product-lab-'+lease.id+'@example.test',s.parentPassword);
}
