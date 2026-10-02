from pathlib import Path
import json,subprocess,re,hashlib,time
root=Path('/mnt/c/Users/3feli/AppData/Local/KidRemote/kr006-runtime/e03b4820-193b-4132-b1fc-f7950eeed7fe')
owner=json.loads((root/'owner.json').read_text(encoding='utf-8-sig'))
assert owner['Scope']=='KR006_RUNTIME' and owner['Port']==5584 and owner['AvdName']=='kr006_'+owner['Id'].replace('-','')
assert owner['Sdk']=='C:\\Users\\3feli\\AppData\\Local\\Android\\Sdk'
adb='/mnt/c/Users/3feli/AppData/Local/Android/Sdk/platform-tools/adb.exe'; app='dev.kidremote.child.unassigned.debug'
def raw(args):return subprocess.run([adb,'-s','emulator-5584',*args],capture_output=True,text=True,timeout=180)
def run(args):
    n=raw(['emu','avd','name']);assert n.returncode==0 and n.stdout.strip().splitlines()[0]==owner['AvdName']
    q=raw(['shell','getprop','ro.kernel.qemu']);assert q.returncode==0 and q.stdout.strip()=='1'
    return raw(args)

import sys
source=sys.argv[1];bundle=root/('apks-kr010-'+source[:7]);meta=json.loads((bundle/'source.json').read_text())
assert re.fullmatch(r'[a-f0-9]{40}',source) and meta['source']==source
for f in ['child-debug.apk','child-debug-androidTest.apk']:
 assert hashlib.sha256((bundle/f).read_bytes()).hexdigest()==meta['apks'][f]
prior_services=run(['shell','settings','get','secure','enabled_accessibility_services']).stdout.strip()
prior_enabled=run(['shell','settings','get','secure','accessibility_enabled']).stdout.strip()
no_restart=len(sys.argv)>2 and sys.argv[2]=='no-restart'
network='network' in sys.argv[3:]
e={'networkFixture':network,'observerModuleSha256':hashlib.sha256((Path(__file__).parent/'recovery_observer.py').read_bytes()).hexdigest(),'observerVersion':4,'harnessSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'instrumentationNoRestart':no_restart,'scope':'OD49_HOST_RECOVERY_DIAGNOSIS','source':source,'hashes':meta['apks'],'result':'NOT_PASSED','cleanup':'UNVERIFIED'}
try:
 fixture=root/'ordinary-fixture-od49.apk'
 import shutil
 shutil.copyfile('spikes/android-enforcement/ordinary-fixture/build/outputs/apk/debug/ordinary-fixture-debug.apk',fixture)
 e['fixtureSha256']=hashlib.sha256(fixture.read_bytes()).hexdigest()
 r=run(['install','-r','-t','C:'+str(fixture)[6:].replace('/','\\')]);assert r.returncode==0 and 'Success' in r.stdout
 for f in ['child-debug.apk','child-debug-androidTest.apk']:
  p=str(bundle/f);r=run(['install','-r','-t','C:'+p[6:].replace('/','\\')]);assert r.returncode==0 and 'Success' in r.stdout
 methods=['killNetworkRestricted' if network else 'killWhileRestricted']
 if not network:
  for p in [app,app+'.test','dev.kidremote.spike.ordinary']:
   assert 'Success' in run(['shell','pm','clear',p]).stdout
 e['stages']=[]
 if no_restart:
  assert run(['shell','am','start','-W','-n',app+'/dev.kidremote.child.ChildActivity']).returncode==0
 for method in methods:
  r=run(['shell','am','instrument',*(['--no-restart'] if no_restart else []),'-w','-r','-e','class','dev.kidremote.child.enforcement.EnforcementRuntimeTest#'+method,app+'.test/androidx.test.runner.AndroidJUnitRunner'])
  death_return=time.monotonic()
  output=r.stdout+r.stderr;codes=re.findall(r'enforcement=([A-Z0-9_]+)',output)
  row={'method':method,'codes':codes,'failure':re.findall(r'ENFORCEMENT_RUNTIME_FAILED_LINE_[0-9]+',output),'result':'NOT_PASSED'};e['stages'].append(row)
  if method in ['killWhileRestricted','killNetworkRestricted']:
   marker=run(['exec-out','run-as',app,'cat','no_backup/enforcement-crash']).stdout.strip()
   assert marker=='EXPECTED_PRODUCT_ENFORCEMENT_KILL' and marker in codes and 'Process crashed' in output
   row['result']='EXPECTED_PROCESS_DEATH'
   before=json.loads(run(['exec-out','run-as',app,'cat','no_backup/enforcement-death-state']).stdout)
   identity_hash=run(['exec-out','run-as',app,'sha256sum','no_backup/device-identity']).stdout.split()[0]
   assert re.fullmatch(r'[a-f0-9]{64}',identity_hash)
   e['oldPid']=before['pid'];e['timeOrigin']='HOST_INSTRUMENTATION_COMMAND_RETURN_AFTER_EXPECTED_DEATH'
   def observe(phase):
    own=run(['shell','dumpsys','package',app]).stdout
    access=run(['shell','dumpsys','accessibility']).stdout
    def section(name):
     m=re.search(r'^\s*'+name+r':(.*?)(?=^\s*[A-Z][A-Za-z ]+:|\Z)',access,re.M|re.S)
     return m.group(1) if m else None
    sections={n:section(n) for n in ['Bound services','Enabled services','Binding services','Crashed services']}
    assert all(v is not None for v in sections.values()),'UNRECOGNIZED_OS_DUMP_SCHEMA'
    pid=run(['shell','pidof',app]).stdout.strip()
    assert not pid or re.fullmatch(r'[0-9]+(?: [0-9]+)*',pid)
    active=run(['shell','dumpsys','activity','instrumentation']).stdout
    service=run(['shell','dumpsys','activity','services',app+'/dev.kidremote.child.enforcement.ChildEnforcementService']).stdout
    from recovery_observer import binding
    b=binding(sections['Bound services'],service,app)
    return {'phase':phase,'elapsedSeconds':round(time.monotonic()-death_return,3),'pids':[int(p) for p in pid.split()],
     'stopped':re.search(r'stopped=(true|false)',own).group(1),
     **b,'enabled':app in sections['Enabled services'],
     'binding':app in sections['Binding services'],'crashed':app in sections['Crashed services'],
     'instrumentationPresent':app+'.test' in active}
   e['observations']=[]
   def window(phase):
    until=time.monotonic()+60
    while True:
     o=observe(phase);e['observations'].append(o)
     assert not o['instrumentationPresent'] and o['stopped']=='false' and o['enabled']
     if o['bound'] and o['servicePid'] in o['pids'] and before['pid'] not in o['pids']:return o
     if time.monotonic()>=until:return None
     time.sleep(2)
   recovered=window('AUTOMATIC_NO_INTERVENTION')
   e['classification']='AUTOMATIC_RECOVERY_OBSERVED' if recovered else 'NO_RECOVERY_OBSERVED'
   if not recovered:
    e['appReopenAtSeconds']=round(time.monotonic()-death_return,3)
    assert run(['shell','am','start','-W','-n',app+'/dev.kidremote.child.ChildActivity']).returncode==0
    recovered=window('APP_REOPEN_CONTROL')
    if recovered:e['classification']='RECOVERY_ONLY_AFTER_APP_REOPEN'
   if recovered:
    e['firstObservedConnection']=recovered
    e['encryptedIdentityUnchanged']=identity_hash==run(['exec-out','run-as',app,'sha256sum','no_backup/device-identity']).stdout.split()[0]
    assert e['encryptedIdentityUnchanged']
    v=run(['shell','am','instrument','--no-restart','-w','-r','-e','host_pid',str(recovered['servicePid']),'-e','network_recovery',str(network).lower(),'-e','class','dev.kidremote.child.enforcement.EnforcementRuntimeTest#verifyHostRecovery',app+'.test/androidx.test.runner.AndroidJUnitRunner'])
    out=v.stdout+v.stderr
    e['verification']={'codes':re.findall(r'enforcement=([A-Z0-9_]+)',out),'failure':re.findall(r'ENFORCEMENT_RUNTIME_FAILED_LINE_[0-9]+',out),'result':'PASS' if v.returncode==0 and 'OK (1 test)' in out and 'FAILURES!!!' not in out else 'NOT_PASSED'}
  else:
   assert r.returncode==0 and 'OK (1 test)' in output and not re.search(r'FAILURES!!!|INSTRUMENTATION_FAILED|Process crashed',output)
   row['result']='PASS'
 e['result']='PASS_AUTOMATIC_RECOVERY' if e.get('classification')=='AUTOMATIC_RECOVERY_OBSERVED' and e.get('verification',{}).get('result')=='PASS' else 'DIAGNOSTIC_COMPLETED_ONLY'
except Exception as ex:e['error']=type(ex).__name__
finally:
 try:
  # The host owns restoration even when instrumentation intentionally dies before finally.
  for key,value in [('enabled_accessibility_services',prior_services),('accessibility_enabled',prior_enabled)]:
   assert run(['shell','settings','delete' if value=='null' else 'put','secure',key,*([] if value=='null' else [value])]).returncode==0
  assert run(['shell','appops','set',app,'GET_USAGE_STATS','default']).returncode==0
  for p in [app,app+'.test','dev.kidremote.spike.ordinary']:
   assert run(['shell','am','force-stop',p]).returncode==0
   assert 'Success' in run(['shell','pm','clear',p]).stdout
  assert run(['shell','settings','get','secure','enabled_accessibility_services']).stdout.strip()==prior_services
  assert run(['shell','settings','get','secure','accessibility_enabled']).stdout.strip()==prior_enabled
  e['cleanup']='TASK_CHILD_DATA_CLEARED_SETTINGS_READBACK_VERIFIED'
 except Exception:e['cleanup']='UNVERIFIED'
 p=Path('/tmp/od49-host-recovery-'+str(time.time_ns())+'.json');p.write_text(json.dumps(e,indent=2)+'\n');print(json.dumps(e));print(p)
