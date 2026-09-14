// Parent JWT is verified by Auth and forwarded to the existing RLS/RPC boundary.
export function createControlHandler({verify,rpc,read}) {
 const reply=(status,value)=>Response.json(value,{status,headers:{'cache-control':'no-store'}});
 return async request=>{try{
  const u=new URL(request.url),m=/^\/parent\/devices\/([a-f0-9-]{36})\/operations$/.exec(u.pathname);
  if(!m||u.search||!['GET','POST'].includes(request.method))return reply(404,{status:'rejected',code:'UNSUPPORTED_OPERATION'});
  const authorization=request.headers.get('authorization')??'';
  if(!/^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(authorization)||!await verify(authorization))return reply(401,{status:'rejected',code:'UNAUTHORIZED'});
  if(request.method==='GET')return reply(200,await read(authorization,m[1]));
  if(request.headers.get('content-type')?.split(';')[0]!=='application/json')return reply(400,{status:'rejected',code:'INVALID_OPERATION'});
  let bytes=0;const chunks=[];for await(const c of request.body??[]){bytes+=c.length;if(bytes>65536)return reply(400,{status:'rejected',code:'INVALID_OPERATION'});chunks.push(c)}
  let b;try{b=JSON.parse(Buffer.concat(chunks).toString())}catch{return reply(400,{status:'rejected',code:'INVALID_OPERATION'})}
  const keys=['protocol_version','operation_id','device_id','kind','payload','expected_version'];
  if(!b||Object.keys(b).length!==keys.length||!keys.every(k=>Object.hasOwn(b,k))||b.protocol_version!==1||b.device_id!==m[1]||! /^[a-f0-9-]{36}$/.test(b.operation_id)||!['LOCK','UNLOCK','ADD_TIME','SET_DAILY_LIMIT'].includes(b.kind))return reply(400,{status:'rejected',code:'INVALID_OPERATION'});
  if(b.expected_version!==null&&(!Number.isSafeInteger(b.expected_version)||b.expected_version<0))return reply(400,{status:'rejected',code:'INVALID_OPERATION'});
  const result=await rpc(authorization,{p_operation_id:b.operation_id,p_device_id:m[1],p_kind:b.kind,p_payload:b.payload,p_expected_version:b.expected_version});
  if(result.ok)return reply(200,result.value);
  const code=['TARGET_DENIED','OPERATION_CONFLICT','PERIOD_CONFLICT','VERSION_CONFLICT','ALLOWANCE_CAP','POLICY_NOT_CONFIGURED','INVALID_OPERATION'].includes(result.value?.message)?result.value.message:'OPERATION_REJECTED';
  return reply(code==='TARGET_DENIED'?403:code.endsWith('CONFLICT')?409:400,{status:'rejected',code});
 }catch{return reply(503,{status:'failed',code:'TEMPORARILY_UNAVAILABLE'})}};
}
