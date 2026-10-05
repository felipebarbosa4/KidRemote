// Synthetic host QR bytes only. No displayed/physical capture, device or secret.
import {spawnSync} from 'node:child_process';import {mkdtempSync,readdirSync,readFileSync,rmSync} from 'node:fs';import {tmpdir,homedir} from 'node:os';import {join,resolve} from 'node:path';import assert from 'node:assert/strict';
const base=join(process.env.GRADLE_USER_HOME??join(homedir(),'.gradle'),'caches/modules-2/files-2.1/com.google.zxing/core/3.5.4');
const jars=readdirSync(base).flatMap(d=>readdirSync(join(base,d)).filter(f=>f==='core-3.5.4.jar').map(f=>join(base,d,f)));assert.equal(jars.length,1);
const out=mkdtempSync(join(tmpdir(),'od51-qr-'));try{
 let r=spawnSync('javac',['-cp',jars[0],'-d',out,'tools/enforcement/product-oracle/HostQr.java'],{encoding:'utf8'});assert.equal(r.status,0);
 const java=input=>spawnSync('java',['-cp',out+':'+jars[0],'HostQr'],{input,encoding:'utf8'});
 const plain=java('{"synthetic":true}'),bom=java('\uFEFF{"synthetic":true}');assert.equal(plain.status,0);assert.equal(bom.status,0);assert.equal(plain.stdout,bom.stdout);
 const png=Buffer.from(plain.stdout,'base64');assert.equal(png.subarray(0,8).toString('hex'),'89504e470d0a1a0a');assert.equal(png.readUInt32BE(16),512);assert.equal(png.readUInt32BE(20),512);
 assert.equal(java('').status,2);assert.equal(java('x'.repeat(257)).status,2);assert.equal(java('\uFEFF'+'x'.repeat(257)).status,2);
 console.log('HOST_QR_CHECKS=5;PLAIN_BOM_EQUIVALENT;BOUNDS_ENFORCED;DEVICE=NOT_RUN');
}finally{rmSync(out,{recursive:true});}
