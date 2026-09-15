// Compatibility describes canonical persisted/backend semantics, not host presentation.
import {readFileSync,readdirSync} from 'node:fs';
import {resolve,relative} from 'node:path';
import {createHash} from 'node:crypto';
export const leaseSchema='OD51:format1:source-schema-identity:exact-labels:pinned-images:dpapi-v1';
export function criticalFiles(root){
 const files=[];
 function walk(dir){for(const name of readdirSync(resolve(root,dir)).sort()){const path=dir+'/'+name;if(name.endsWith('.mjs')||name.endsWith('.sql'))files.push(path);else if(!name.includes('.'))walk(path);}}
 walk('supabase/migrations');walk('supabase/functions');
 files.push('tools/kr007/local-gateway.mjs','packages/protocol/CONTRACT.md');
 return files.sort();
}
export function compatibility(root,read=path=>readFileSync(resolve(root,path))){
 const files=criticalFiles(root);const hash=createHash('sha256');hash.update(leaseSchema+'\n');
 for(const path of files)hash.update(path+'\0').update(read(path)).update('\0');
 return {format:1,digest:hash.digest('hex'),files,leaseSchema};
}
export function authorizeCompatibility(current,ownerSource,executionSource,record){
 if(!/^[a-f0-9]{40}$/.test(ownerSource)||!record||record.format!==1||record.source!==ownerSource||record.digest!==current.digest)throw Error('BACKEND_COMPATIBILITY_MISMATCH');
 return {ownershipSource:ownerSource,executionSource,digest:current.digest};
}
