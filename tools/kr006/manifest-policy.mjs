// AndroidX Core adds a same-application, signature-only receiver compatibility guard.
// No broad signature permission or arbitrary second permission is accepted.
export function parentPermissionsAllowed(manifest) {
 const applicationId=manifest.match(/\bpackage="([^"]+)"/)?.[1];
 if(!/^dev\.kidremote\.parent\.unassigned(?:\.debug)?$/.test(applicationId??'')) return false;
 const local=applicationId+'.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION';
 const permissions=[...manifest.matchAll(/<uses-permission\b[^>]*android:name="([^"]+)"/g)].map(m=>m[1]);
 if(!permissions.includes('android.permission.INTERNET') || permissions.length>2 ||
  new Set(permissions).size!==permissions.length || !permissions.every(p=>p==='android.permission.INTERNET'||p===local)) return false;
 if(!permissions.includes(local)) return true;
 const declaration=[...manifest.matchAll(/<permission\b[^>]*>/g)].map(m=>m[0]).find(p=>p.includes('android:name="'+local+'"'));
 return declaration?.includes('android:protectionLevel="signature"')??false;
}
