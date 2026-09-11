import {randomBytes,randomUUID} from 'node:crypto';
export async function testParentAuth({http,sql,mailAvailable,restAvailable}) {
 let count=0;const check=(ok,label)=>{if(!ok) throw Error('AUTH_TEST_FAILED:'+label);count++;};
 const auth='http://127.0.0.1:57361',rest='http://127.0.0.1:57362',mail='http://127.0.0.1:57365';
 const json=r=>{try{return JSON.parse(r.body);}catch{return {};}};
 const bearer=s=>({authorization:'Bearer '+s.access_token});
 const password=()=>randomBytes(24).toString('base64url')+'aA1!';
 async function emailLink(email) {
  for(let i=0;i<20;i++) {
   const messages=json(await http(mail+'/api/v1/messages')).messages??[];
   const hit=messages.find(m=>m.To?.some(t=>t.Address===email));
   if(hit) {
    const detail=json(await http(mail+'/api/v1/message/'+hit.ID));
    const content=(detail.HTML??detail.Text??'').replaceAll('&amp;','&');
    const link=content.match(/http:\/\/127\.0\.0\.1:57361\/verify\?[^\s"<>]+/)?.[0];
    if(link) return new URL(link);
   }
   await new Promise(r=>setTimeout(r,200));
  }
  throw Error('LOCAL_CONFIRMATION_EMAIL_NOT_RECEIVED');
 }
 async function signup() {
  const email='kr006-'+randomUUID()+'@example.test',pass=password();
  const created=await http(auth+'/signup','POST',{email,password:pass,data:{role:'owner',household_id:randomUUID()}});
  check(created.status===200,'SIGNUP_REAL_AUTH');check(!json(created).access_token,'NO_UNVERIFIED_SESSION');
  check((await http(auth+'/token?grant_type=password','POST',{email,password:pass})).status===400,'UNCONFIRMED_LOGIN_DENIED');
  const link=await emailLink(email);
  const verified=await http(auth+'/verify','POST',{token_hash:link.searchParams.get('token'),type:'signup'});
  check(verified.status===200,'EMAIL_CONFIRMATION_REAL_TOKEN');
  check((await http(auth+'/verify','POST',{token_hash:link.searchParams.get('token'),type:'signup'})).status!==200,'CONFIRMATION_REPLAY_DENIED');
  const login=await http(auth+'/token?grant_type=password','POST',{email,password:pass});
  check(login.status===200,'CONFIRMED_LOGIN');return {email,pass,session:json(login)};
 }
 const a=await signup(),b=await signup();
 check((await http(auth+'/token?grant_type=password','POST',{email:a.email,password:password()})).status===400,'INVALID_PASSWORD');
 check((await http(rest+'/rpc/bootstrap_household','POST',{p_timezone:'Etc/UTC'},{authorization:'Bearer invalid'})).status===401,'INVALID_JWT_DENIED');
 const results=await Promise.all(Array.from({length:10},()=>http(rest+'/rpc/bootstrap_household','POST',{p_timezone:'Etc/UTC'},bearer(a.session))));
 check(results.every(r=>r.status===200),'CONCURRENT_BOOTSTRAP_HTTP_SUCCESS');
 check(results.filter(r=>json(r).created).length===1,'EXACTLY_ONE_BOOTSTRAP_CREATION');
 const household=json(results[0]).household_id;
 check(results.every(r=>json(r).household_id===household),'RETRY_SAME_HOUSEHOLD');
 check(sql(`select count(*) from public.household_members where user_id='${a.session.user.id}';`)==='1','ACTUAL_SINGLE_MEMBERSHIP');
 const other=await http(rest+'/rpc/bootstrap_household','POST',{p_timezone:'Etc/UTC'},bearer(b.session));
 check(other.status===200,'SECOND_CONFIRMED_HOUSEHOLD');
 check(json(await http(rest+'/households?select=id','GET',undefined,bearer(a.session))).length===1,'OWN_HOUSEHOLD_READ');
 check(json(await http(rest+'/profiles?select=user_id','GET',undefined,bearer(a.session))).length===1,'OWN_PROFILE_READ');
 check(json(await http(rest+'/devices?select=id','GET',undefined,bearer(a.session))).length===0,'ACTUAL_EMPTY_DEVICES');
 check(json(await http(rest+'/households?id=eq.'+json(other).household_id,'GET',undefined,bearer(a.session))).length===0,'FOREIGN_HOUSEHOLD_DENIED');
 check((await http(rest+'/rpc/bootstrap_household','POST',{p_timezone:'Etc/UTC',actor_user_id:b.session.user.id},bearer(a.session))).status!==200,'ACTOR_OVERRIDE_REJECTED');
 check((await http(auth+'/recover','POST',{email:a.email})).status===200,'RECOVERY_REQUEST_REAL_SMTP');
 let link=await emailLink(a.email);
 // Mailpit newest message first. Require recovery rather than recycling signup mail.
 check(link.searchParams.get('type')==='recovery','RECOVERY_MAIL_TYPE');
 const recovered=await http(auth+'/verify','POST',{token_hash:link.searchParams.get('token'),type:'recovery'});
 check(recovered.status===200,'RECOVERY_TOKEN_REAL_AUTH');
 check((await http(auth+'/verify','POST',{token_hash:link.searchParams.get('token'),type:'recovery'})).status!==200,'STALE_RECOVERY_REPLAY_DENIED');
 const newPass=password();
 check((await http(auth+'/user','PUT',{password:newPass},bearer(json(recovered)))).status===200,'PASSWORD_UPDATED_WITH_RECOVERY_SESSION');
 check((await http(auth+'/token?grant_type=password','POST',{email:a.email,password:a.pass})).status===400,'OLD_PASSWORD_DENIED');
 const newLogin=await http(auth+'/token?grant_type=password','POST',{email:a.email,password:newPass});
 check(newLogin.status===200,'NEW_PASSWORD_LOGIN');
 const refreshed=await http(auth+'/token?grant_type=refresh_token','POST',{refresh_token:json(newLogin).refresh_token});
 check(refreshed.status===200,'SESSION_REFRESH');
 check((await http(auth+'/logout?scope=local','POST',{},bearer(json(refreshed)))).status===204,'LOCAL_SCOPE_LOGOUT');
 check((await http(auth+'/token?grant_type=refresh_token','POST',{refresh_token:json(refreshed).refresh_token})).status!==200,'LOGGED_OUT_REFRESH_DENIED');
 const residual=await http(rest+'/households?select=id','GET',undefined,bearer(json(refreshed)));
 check(residual.status===200,'SIGNED_ACCESS_TOKEN_RESIDUAL_UNTIL_EXPIRY_DOCUMENTED');
 await new Promise(r=>setTimeout(r,1100));
 check((await http(auth+'/recover','POST',{email:b.email})).status===200,'EXPIRY_TEST_RECOVERY_MAIL');
 link=await emailLink(b.email);
 // Failure injection on synthetic issuance timestamp only, never fake confirmation/login.
 sql(`update auth.users set recovery_sent_at=clock_timestamp()-interval '1 hour' where id='${b.session.user.id}';`);
 check((await http(auth+'/verify','POST',{token_hash:link.searchParams.get('token'),type:'recovery'})).status!==200,'EXPIRED_RECOVERY_DENIED');
 sql(`update public.household_members set active=false where user_id='${a.session.user.id}';`);
 check(json(await http(rest+'/households?select=id','GET',undefined,bearer(a.session))).length===0,'INACTIVE_MEMBERSHIP_STILL_VALID_JWT_DENIED');
 check((await http(rest+'/rpc/bootstrap_household','POST',{p_timezone:'Etc/UTC'},bearer(a.session))).status===403,'BOOTSTRAP_CANNOT_REACTIVATE_MEMBER');
 sql(`delete from public.household_members where user_id='${a.session.user.id}';`);
 check(json(await http(rest+'/households?select=id','GET',undefined,bearer(a.session))).length===0,'DELETED_MEMBERSHIP_STALE_JWT_DENIED');
 check((await http(rest+'/rpc/bootstrap_household','POST',{p_timezone:'Etc/UTC'},bearer(a.session))).status===403,'NO_REENROLL_AFTER_MEMBERSHIP_REMOVAL');
 await new Promise(r=>setTimeout(r,1100));
 mailAvailable(false);
 try { check((await http(auth+'/recover','POST',{email:b.email})).status>=500,'ACTUAL_SMTP_FAILURE_REPORTED'); }
 finally { mailAvailable(true); }
 restAvailable(false);
 try {check((await http(rest+'/')).status===0,'UNAVAILABLE_OWNED_REST_ENDPOINT');}
 finally {restAvailable(true);}
 await new Promise(r=>setTimeout(r,1200));
 check((await http(rest+'/')).status===200,'OWNED_REST_RECOVERED');
 console.log('REAL_AUTH_POSTGREST_TESTS_PASS:assertions='+count+':autoConfirm=false:externalSMTP=false');
}
