import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { Readable } from 'node:stream';
import { createDeviceHandler, credentialDigest } from '../../supabase/functions/device-gateway/handler.mjs';

// Explicit dependency stub: storage transaction/records, NOT handler authorization.
test('actual gateway HTTP authorization on loopback with synthetic storage stub', async t => {
  const now=Date.now(), secret=randomBytes(32).toString('base64url');
  const u={a:randomUUID(),sibling:randomUUID(),foreign:randomUUID(),ha:randomUUID(),hb:randomUUID(),epoch:randomUUID()};
  const credential={credential_id:randomUUID(),device_id:u.a,secret_digest:credentialDigest(secret),
    expires_at:new Date(now+60000).toISOString(),revoked_at:null};
  const device={id:u.a,household_id:u.ha,policy_epoch:u.epoch,revoked_at:null};
  const commands=new Map([[randomUUID(),{device_id:u.a,household_id:u.ha,version:1}],
    [randomUUID(),{device_id:u.sibling,household_id:u.ha,version:1}],
    [randomUUID(),{device_id:u.foreign,household_id:u.hb,version:1}]]);
  const [own,sibling,foreign]=[...commands.keys()];
  let calls=[], pushOwner=null, dependencyThrows=false;
  const store={
    async withCredential(digest, callback) {
      if(dependencyThrows) throw new Error(secret); // prove no exception/bearer disclosure
      return callback({
        credential:digest===credential.secret_digest?credential:null, device,policy_version:2,
        findCommand:async id=>commands.get(id),findPushOwner:async()=>pushOwner,
        sync:async(scope,input)=>{calls.push({op:'sync',scope,input}); return {result:'STUB_OWN_SNAPSHOT'};},
        ack:async(scope,input)=>{calls.push({op:'ack',scope,input}); return {result:'STUB_RECEIPT'};},
        registerPush:async(scope,input)=>{calls.push({op:'push',scope,input}); return {result:'STUB_REGISTRATION'};},
      });
    },
  };
  const handler=createDeviceHandler(store,()=>now);
  const server=createServer(async(req,res)=>{
    const response=await handler(new Request('http://127.0.0.1'+req.url,{
      method:req.method,headers:req.headers,
      ...(req.method==='POST'?{body:Readable.toWeb(req),duplex:'half'}:{}),
    }));
    res.writeHead(response.status,Object.fromEntries(response.headers));
    res.end(await response.text());
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  t.after(()=>new Promise(resolve=>server.close(resolve)));
  const base='http://127.0.0.1:'+server.address().port;
  const sync={protocol_version:1,after_version:0};
  const ack={protocol_version:1,command_id:own,policy_epoch:u.epoch,snapshot_version:2,outcome:'applied',observed_enforcement:true};
  const push={protocol_version:1,provider:'fcm',address_kind:'fid',address:'synthetic-fixture-address'};
  async function request(body=sync,path='/device/sync',token=secret,method='POST'){
    calls=[];
    const r=await fetch(base+path,{method,headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},
      ...(method==='POST'?{body:JSON.stringify(body)}:{})});
    const text=await r.text();
    assert.ok(!text.includes(secret)); assert.equal(r.headers.get('cache-control'),'no-store');
    return r.status;
  }
  async function denied(name,body,path,status=400,token=secret,method='POST'){
    await t.test(name,async()=>{assert.equal(await request(body,path,token,method),status);assert.equal(calls.length,0);});
  }
  await t.test('own snapshot scope is derived exclusively from credential records',async()=>{
    assert.equal(await request(),200);assert.equal(calls[0].scope.device_id,u.a);assert.equal(calls[0].scope.household_id,u.ha);
  });
  await t.test('own receipt allowed',async()=>assert.equal(await request(ack,'/device/ack'),200));
  await t.test('own push registration allowed',async()=>assert.equal(await request(push,'/device/push-registration'),200));
  await denied('missing credential',sync,'/device/sync',401,null);
  await denied('invalid credential',sync,'/device/sync',401,randomBytes(32).toString('base64url'));
  await denied('parent JWT is not a device bearer',sync,'/device/sync',401,'eyJhbGciOiJIUzI1NiJ9.synthetic.signature');
  credential.expires_at=new Date(now).toISOString();
  await denied('expired credential',sync,'/device/sync',401);credential.expires_at=new Date(now+60000).toISOString();
  credential.revoked_at=new Date(now).toISOString();
  await denied('revoked matching credential has typed removal result',sync,'/device/sync',403);
  await denied('wrong secret cannot discover revoked record',sync,'/device/sync',401,randomBytes(32).toString('base64url'));
  credential.revoked_at=null;device.revoked_at=new Date(now).toISOString();
  await denied('revoked device',sync,'/device/sync',403);device.revoked_at=null;
  credential.expires_at='invalid';await denied('unknown expiry fails closed',sync,'/device/sync',401);
  credential.expires_at=new Date(now+60000).toISOString();
  delete credential.revoked_at;
  await denied('missing credential revocation state fails closed',sync,'/device/sync',401);
  credential.revoked_at=null;
  delete device.revoked_at;
  await denied('missing device revocation state fails closed',sync,'/device/sync',401);
  device.revoked_at=null;
  credential.device_id=u.foreign;
  await denied('inconsistent server credential/device join fails closed',sync,'/device/sync',401);
  credential.device_id=u.a;
  for(const [name,value] of [['own',u.a],['sibling',u.sibling],['foreign',u.foreign]])
    await denied(name+' caller device override rejected',{...sync,device_id:value},'/device/sync');
  for(const key of ['household_id','actor_user_id','role','rpc','operation','manual_lock'])
    await denied(key+' injection rejected',{...sync,[key]:u.hb},'/device/sync');
  await denied('sibling receipt denied',{...ack,command_id:sibling},'/device/ack',403);
  await denied('foreign household receipt denied',{...ack,command_id:foreign},'/device/ack',403);
  await denied('missing command indistinguishable',{...ack,command_id:randomUUID()},'/device/ack',403);
  await denied('future receipt denied',{...ack,snapshot_version:3},'/device/ack',409);
  await denied('receipt before command version denied',{...ack,snapshot_version:0},'/device/ack',409);
  await denied('wrong epoch denied',{...ack,policy_epoch:randomUUID()},'/device/ack',409);
  for(const d of [u.sibling,u.foreign]){
    pushOwner={device_id:d}; await denied('foreign/sibling push address cannot be stolen',push,'/device/push-registration',409);
  }
  pushOwner=null;
  for(const path of ['/parent/households','/parent/devices/'+u.a+'/operations','/rpc/accept_command','/device/credentials/rotate','/device/sync?rpc=anything'])
    await denied('unsupported route '+path,sync,path,404);
  await denied('unsupported method',sync,'/device/sync',404,secret,'GET');
  await denied('oversize payload',{...sync,padding:'x'.repeat(65536)},'/device/sync');
  await denied('unknown protocol',{...sync,protocol_version:2},'/device/sync');
  await denied('negative cursor',{...sync,after_version:-1},'/device/sync');
  dependencyThrows=true;await denied('dependency failure redacted',sync,'/device/sync',503);dependencyThrows=false;
  // A fresh lookup occurs on every request; no credential authorization cache.
  await request();credential.revoked_at=new Date(now).toISOString();
  await denied('revoked after initial success',sync,'/device/sync',403);
});
