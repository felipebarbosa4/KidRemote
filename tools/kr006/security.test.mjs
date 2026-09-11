import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {parentPermissionsAllowed} from './manifest-policy.mjs';
const read=p=>readFileSync(p,'utf8');
test('manifest permits only INTERNET and the exact same-app signature guard',()=>{
 const base='<manifest package="dev.kidremote.parent.unassigned.debug"><uses-permission android:name="android.permission.INTERNET"/>';
 const local='dev.kidremote.parent.unassigned.debug.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION';
 const guard='<permission android:name="'+local+'" android:protectionLevel="signature"/><uses-permission android:name="'+local+'"/>';
 assert.ok(parentPermissionsAllowed(base+'</manifest>'));
 assert.ok(parentPermissionsAllowed(base+guard+'</manifest>'));
 assert.ok(!parentPermissionsAllowed(base+guard.replace('signature','normal')+'</manifest>'));
 assert.ok(!parentPermissionsAllowed(base+guard.replaceAll(local,'other.app.permission')+'</manifest>'));
 assert.ok(!parentPermissionsAllowed(base+'<uses-permission android:name="android.permission.READ_CONTACTS"/></manifest>'));
});
test('parent release disables backend and denies all cleartext; debug exception one emulator host only',()=>{
 assert.match(read('apps/parent-mobile/app/src/release/java/dev/kidremote/parent/BackendConfig.kt'),/enabled = false/);
 assert.doesNotMatch(read('apps/parent-mobile/app/src/release/java/dev/kidremote/parent/BackendConfig.kt'),/https?:/);
 assert.doesNotMatch(read('apps/parent-mobile/app/src/main/res/xml/network_security_config.xml'),/Permitted="true"/);
 const debug=read('apps/parent-mobile/app/src/debug/res/xml/network_security_config.xml');
 assert.equal((debug.match(/<domain /g)??[]).length,1);assert.match(debug,/>10\.0\.2\.2</);
});
test('Auth fixtures enforce confirmation and local SMTP; no admin auto-confirm or token forgery',()=>{
 const local=read('tools/kr006/local-auth.mjs');
 assert.match(local,/GOTRUE_MAILER_AUTOCONFIRM:false/);assert.match(local,/GOTRUE_SMTP_HOST:name\+'-mail'/);
 assert.doesNotMatch(read('tools/kr006/real-auth-tests.mjs'),/email_confirmed_at\s*=|createHmac|admin\/users/);
});
test('vault uses platform Keystore, atomic encrypted no-backup storage and deletes key on clear',()=>{
 const source=read('apps/parent-mobile/app/src/main/java/dev/kidremote/parent/SessionVault.kt');
 for(const s of ['AndroidKeyStore','AES/GCM/NoPadding','noBackupFilesDir','AtomicFile','deleteEntry']) assert.ok(source.includes(s));
 assert.doesNotMatch(source,/Log\.|println|SharedPreferences/);
});
