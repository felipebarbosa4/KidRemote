import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes,randomUUID } from 'node:crypto';
import { parseQR,createPairing,redeemPairing,createPairingHandler,secretDigest } from '../../supabase/functions/pairing/protocol.mjs';
const qr=()=>({protocol_version:1,session_id:randomUUID(),token:randomBytes(32).toString('base64url')});
const metadata={platform:'android',os_major:16,agent_version:'synthetic',nickname:'synthetic'};
const source=()=>randomBytes(32).toString('hex');
const success=()=>({result:'REDEEMED',device_id:randomUUID(),credential_id:randomUUID(),policy_epoch:randomUUID(),expires_at:new Date(Date.now()+90*864e5).toISOString(),rotate_after:new Date(Date.now()+30*864e5).toISOString()});
test('minimal QR only; no redirects, credentials, foreign targets, versions or malformed tokens',()=>{
 const q=qr(); assert.ok(JSON.stringify(parseQR(JSON.stringify(q)))===JSON.stringify(q));
 for(const value of [null,'https://example.invalid/?token=x','{',JSON.stringify({...q,backend:'https://example.invalid'}),
  JSON.stringify({...q,household_id:randomUUID()}),JSON.stringify({...q,parent_jwt:'synthetic'}),
  JSON.stringify({...q,protocol_version:2}),JSON.stringify({...q,token:q.token+'='}),' '.repeat(257)]) assert.equal(parseQR(value),null);
});
test('creation supplies digest only and returns minimal QR; adapter is verified-parent dependency stub',async()=>{
 let digest; const r=await createPairing({create:async d=>{digest=d;return {result:'CREATED',session_id:randomUUID(),expires_at:new Date().toISOString()};}});
 assert.deepEqual(Object.keys(r.qr).sort(),['protocol_version','session_id','token']);
 assert.equal(secretDigest(r.qr.token),digest);
});
test('redemption passes hashes only, redacts adapter errors and returns plaintext once, never on denial',async()=>{
 const q=qr(); let stored;
 const r=await redeemPairing({redeem:async p=>{stored=p; return success();}},{qr:q,metadata},source());
 assert.equal(r.result,'REDEEMED'); assert.equal(stored.credential_digest,secretDigest(r.credential));
 assert.equal(JSON.stringify(stored).includes(q.token),false); assert.equal(JSON.stringify(stored).includes(r.credential),false);
 for(const result of ['DENIED','RATE_LIMITED','INVALID']) {
  const denied=await redeemPairing({redeem:async()=>({result,credential:r.credential})},{qr:q,metadata},source());
  assert.equal(Object.hasOwn(denied,'credential'),false);
 }
 const lost=await redeemPairing({redeem:async()=>{throw Error(q.token);}},{qr:q,metadata},source());
 assert.deepEqual(lost,{result:'UNAVAILABLE'});
});
test('foreign identity, metadata bounds and malformed payload rejected before adapter',async()=>{
 let calls=0;const adapter={redeem:async()=>{calls++;return success();}};
 const body={qr:qr(),metadata};
 for(const b of [{...body,household_id:randomUUID()},{...body,device_id:randomUUID()},
  {...body,rpc:'accept_control'},{...body,metadata:{...metadata,os_major:0}},
  {...body,metadata:{...metadata,nickname:'x'.repeat(81)}},{...body,metadata:{...metadata,platform:'ios'}},
  {...body,metadata:{...metadata,agent_version:'x'.repeat(65)}}]) assert.equal((await redeemPairing(adapter,b,source())).result,'INVALID');
 assert.equal(calls,0);
});
test('actual handler payload, route, query and error boundaries; storage and ingress stubs explicit',async()=>{
 let calls=0;const handler=createPairingHandler({redeem:async()=>{calls++;return {result:'DENIED'};}},async()=>source());
 for(const [path,body,expected] of [['/pairing/redeem',JSON.stringify({qr:qr(),metadata}),401],
  ['/pairing/redeem?token=synthetic','{}',404],['/parent/pairing-sessions','{}',404],
  ['/rpc/accept_control','{}',404],['/pairing/redeem','x'.repeat(2049),413],['/pairing/redeem','{',400]]) {
  const r=await handler(new Request('http://127.0.0.1'+path,{method:'POST',headers:{'content-type':'application/json'},body}));
  assert.equal(r.status,expected);assert.equal(r.headers.get('cache-control'),'no-store');
 }
 assert.equal(calls,1);
});
