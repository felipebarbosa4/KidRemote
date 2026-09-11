// Local protocol boundary. Adapter calls must commit before resolving, including DENIED.
// No Auth/Edge bootstrap, selectable RPC/host, request logger or plaintext persistence.
import { randomBytes, createHash } from 'node:crypto';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const exact=(o,keys)=>o!==null && typeof o==='object' && !Array.isArray(o) &&
 Object.keys(o).length===keys.length && keys.every(k=>Object.hasOwn(o,k));
export const secretDigest=s=>createHash('sha256').update(s,'utf8').digest('hex');
const secret=()=>randomBytes(32).toString('base64url');
export function validToken(s) {
 return typeof s==='string' && /^[A-Za-z0-9_-]{43}$/.test(s) && Buffer.from(s,'base64url').toString('base64url')===s;
}
export function parseQR(text) {
 try {
  if(typeof text!=='string' || Buffer.byteLength(text)>256) return null;
  const q=JSON.parse(text);
  if(!exact(q,['protocol_version','session_id','token']) || q.protocol_version!==1 ||
   typeof q.session_id!=='string' || !uuid.test(q.session_id) || !validToken(q.token)) return null;
  return q;
 } catch { return null; }
}
export function validMetadata(m) {
 return exact(m,['platform','os_major','agent_version','nickname']) && m.platform==='android' &&
 Number.isInteger(m.os_major) && m.os_major>=1 && m.os_major<=999 &&
 typeof m.agent_version==='string' && /^[A-Za-z0-9._+-]{1,64}$/.test(m.agent_version) &&
 typeof m.nickname==='string' && m.nickname.trim().length>=1 && [...m.nickname].length<=80 &&
 Buffer.byteLength(JSON.stringify(m))<=1024;
}
export async function createPairing(adapter) {
 const token=secret();
 try {
  // adapter is bound to independently verified parent JWT context, no caller actor argument.
  const r=await adapter.create(secretDigest(token));
  if(r?.result==='RATE_LIMITED') return {result:'RATE_LIMITED',retry_after_seconds:600};
  if(r?.result!=='CREATED') return {result:'DENIED'};
  if(!uuid.test(r.session_id) || !Number.isFinite(Date.parse(r.expires_at))) return {result:'UNAVAILABLE'};
  return {result:'CREATED',expires_at:r.expires_at,qr:{protocol_version:1,session_id:r.session_id,token}};
 } catch { return {result:'UNAVAILABLE'}; }
}
export async function redeemPairing(adapter,body,sourceHash) {
 if(!exact(body,['qr','metadata']) || !parseQR(JSON.stringify(body.qr)) || !validMetadata(body.metadata) ||
  typeof sourceHash!=='string' || !/^[0-9a-f]{64}$/.test(sourceHash)) return {result:'INVALID'};
 const credential=secret();
 try {
  const r=await adapter.redeem({session_id:body.qr.session_id,token_digest:secretDigest(body.qr.token),
   credential_digest:secretDigest(credential),source_hash:sourceHash,metadata:body.metadata});
  if(r?.result==='RATE_LIMITED') return {result:'RATE_LIMITED',retry_after_seconds:60};
  if(r?.result==='INVALID') return {result:'INVALID'};
  if(r?.result!=='REDEEMED') return {result:'DENIED'};
  if(![r.device_id,r.credential_id,r.policy_epoch].every(v=>typeof v==='string' && uuid.test(v)) ||
   ![r.expires_at,r.rotate_after].every(v=>Number.isFinite(Date.parse(v)))) return {result:'UNAVAILABLE'};
  return {result:'REDEEMED',device_id:r.device_id,credential_id:r.credential_id,policy_epoch:r.policy_epoch,
   expires_at:r.expires_at,rotate_after:r.rotate_after,credential};
 } catch { return {result:'UNAVAILABLE'}; } // post-commit loss: never replay the credential
}

export function createPairingHandler(adapter,sourceKey) {
 return async request=>{
  const response=(status,result)=>new Response(JSON.stringify(result),{status,
   headers:{'content-type':'application/json','cache-control':'no-store','x-content-type-options':'nosniff'}});
  try {
   const url=new URL(request.url);
   if(request.method!=='POST' || url.pathname!=='/pairing/redeem' || url.search) return response(404,{result:'NOT_FOUND'});
   if(request.headers.get('content-type')!=='application/json') return response(415,{result:'INVALID'});
   // Streaming byte bound, not an unbounded request.text() allocation.
   const reader=request.body?.getReader(); if(!reader) return response(400,{result:'INVALID'});
   let bytes=0; const chunks=[];
   for(;;) { const {done,value}=await reader.read(); if(done) break; bytes+=value.length;
    if(bytes>2048) { await reader.cancel(); return response(413,{result:'INVALID'}); } chunks.push(value); }
   const body=JSON.parse(Buffer.concat(chunks).toString('utf8'));
   // sourceKey supplied by trusted ingress; do not derive from caller forwarded headers/body.
   const r=await redeemPairing(adapter,body,await sourceKey(request));
   return response(({REDEEMED:200,RATE_LIMITED:429,INVALID:400,DENIED:401,UNAVAILABLE:503})[r.result],r);
  } catch { return response(400,{result:'INVALID'}); }
 };
}
