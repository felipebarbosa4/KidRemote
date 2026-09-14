// Actual parent JWT/PostgREST invoker projection; existing reports, never UI stand-ins.
export async function testParentPresentation({http,own,foreign,device}){
 let count=0;const ok=(v,c)=>{if(!v)throw Error('KR010_HTTP_FAILED:'+c);count++};
 const read=(token,body={})=>http('http://127.0.0.1:47362/rpc/parent_devices','POST',body,token?{authorization:'Bearer '+token}:{});
 const a=await read(own);ok(a.status===200,'OWN_READ');const value=JSON.parse(a.body);
 ok(value.protocol_version===1&&Number.isFinite(Date.parse(value.server_utc)),'SERVER_CLOCK_SCHEMA');
 ok(value.devices.length<=50,'BOUNDED_ROWS');const row=value.devices.find(x=>x.id===device);ok(!!row,'OWN_DEVICE');
 ok(row.report&&Number.isSafeInteger(row.report.remaining_ms)&&row.report.restriction_applied===false,'ACTUAL_ACK_REPORT_NO_ENFORCEMENT');
 const b=await read(foreign);ok(b.status===200&&!JSON.parse(b.body).devices.some(x=>x.id===device),'FOREIGN_RLS');
 ok((await read()).status===401,'ANONYMOUS_DENIED');
 const paged=await read(own,{p_after:device});ok(paged.status===200&&JSON.parse(paged.body).devices.every(x=>x.id>device),'PAGE_EXCLUSIVE');
 ok((await read(own,{p_after:'invalid'})).status===400,'MALFORMED_CURSOR');
 ok(Buffer.byteLength(a.body)<=65536&&!/credential|report_digest|secret_digest/.test(a.body),'BOUNDED_MINIMAL_RESPONSE');
 console.log('KR010_REAL_HTTP_PASS:assertions='+count+':auth=REAL:projection=RLS_EXISTING_ACK');
}
