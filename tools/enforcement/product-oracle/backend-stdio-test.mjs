// Actual isolated KR-004/Auth/gateway lifecycle. No device and no credential arguments/output.
import {spawn} from 'node:child_process';
const [docker='docker',host='unix:///var/run/docker.sock']=process.argv.slice(2);
const p=spawn(process.execPath,['tools/kr004/test-local-db.mjs',docker,host,'--enrollment-dev'],{
 env:{...process.env,KR_PRODUCT_LAB_STDIN:'1'},stdio:['pipe','pipe','pipe']});
let stdout='',stderr='',ready=false,timedOut=false;
const timer=setTimeout(()=>{timedOut=true;p.kill('SIGTERM');},300000);
p.stdout.on('data',b=>{
 stdout+=b.toString();
 if(stdout.length>2*1024*1024){timedOut=true;p.kill('SIGTERM');}
 if(!ready&&stdout.includes('PARENT_DEV_READY:')){ready=true;p.stdin.end('STOP\n');}
});
p.stderr.on('data',b=>{stderr+=b.toString();});
p.on('error',()=>{clearTimeout(timer);console.error('OD50_BACKEND_STDIN_START_FAILED');process.exitCode=1;});
p.on('close',code=>{
 clearTimeout(timer);
 if(code!==0||timedOut||!ready||stderr.trim()||!['ENROLLMENT_GATEWAY_CLEANUP_VERIFIED','AUTH_SERVICE_CLEANUP_VERIFIED','CLEANUP=VERIFIED_TASK_CONTAINER_REMOVED','TASK_NETWORK_REMOVED'].every(x=>stdout.includes(x))){
  console.error('OD50_BACKEND_STDIN_CLEANUP_NOT_PASSED');process.exitCode=1;return;
 }
 console.log('OD50_REAL_BACKEND_STDIN_STOP=PASS;DATABASE_AUTH_GATEWAY_CLEANUP=VERIFIED;DEVICE=NOT_RUN');
});
