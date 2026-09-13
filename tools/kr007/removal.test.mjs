import test from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
import {createDeviceHandler,credentialDigest} from '../../supabase/functions/device-gateway/handler.mjs';

// Storage fixture only: actual handler authentication and payload decision under test.
test('only verified device revocation on own sync issues a bound removal envelope',async()=>{
 const secret=randomBytes(32).toString('base64url');
 const device={id:randomUUID(),household_id:randomUUID(),policy_epoch:randomUUID(),revoked_at:new Date().toISOString()};
 const credential={credential_id:randomUUID(),device_id:device.id,secret_digest:credentialDigest(secret),revoked_at:null,expires_at:new Date(0).toISOString()};
 const handler=createDeviceHandler({withCredential:async(d,f)=>f(d===credential.secret_digest?{device,credential,sync:()=>{throw Error('REVOKED_POLICY_READ');}}:null)});
 const send=(body={protocol_version:1,after_version:0},bearer=secret,path='/device/sync')=>handler(new Request('http://127.0.0.1'+path,{method:'POST',headers:{authorization:'Bearer '+bearer,'content-type':'application/json'},body:JSON.stringify(body)}));
 const r=await send();assert.equal(r.status,403);
 assert.deepEqual(await r.json(),{protocol_version:1,code:'DEVICE_REVOKED',device_id:device.id,policy_epoch:device.policy_epoch});
 const unknown=await send(undefined,randomBytes(32).toString('base64url'));assert.equal(unknown.status,401);assert.deepEqual(await unknown.json(),{code:'UNAUTHORIZED'});
 assert.equal((await send({protocol_version:1,after_version:0,device_id:randomUUID()})).status,400);
 const other=await send({protocol_version:1},secret,'/device/ack');assert.deepEqual(await other.json(),{code:'DEVICE_REVOKED'});
 device.revoked_at=null;credential.revoked_at=new Date().toISOString();
 assert.deepEqual(await (await send()).json(),{code:'CREDENTIAL_REVOKED'});
 credential.revoked_at=null;assert.equal((await send()).status,401);
 delete device.revoked_at;assert.equal((await send()).status,401);
});
