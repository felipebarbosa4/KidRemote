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
prior_services=run(['shell','settings','get','secure','enabled_accessibility_services']).stdout.strip()
prior_enabled=run(['shell','settings','get','secure','accessibility_enabled']).stdout.strip()
e={'scope':'OD49_OWNED_EMULATOR_SERVICE_FIXTURE','source':source,'hashes':meta['apks'],'result':'NOT_PASSED','cleanup':'UNVERIFIED'}
try:
 fixture=root/'ordinary-fixture-od49.apk'
 import shutil
 shutil.copyfile('spikes/android-enforcement/ordinary-fixture/build/outputs/apk/debug/ordinary-fixture-debug.apk',fixture)
 e['fixtureSha256']=hashlib.sha256(fixture.read_bytes()).hexdigest()
 r=run(['install','-r','-t','C:'+str(fixture)[6:].replace('/','\\')]);assert r.returncode==0 and 'Success' in r.stdout
 for f in ['child-debug.apk','child-debug-androidTest.apk']:
  p=str(bundle/f);r=run(['install','-r','-t','C:'+p[6:].replace('/','\\')]);assert r.returncode==0 and 'Success' in r.stdout
 methods=['killWhileRestricted','restartAfterDeath'] if len(sys.argv)>2 and sys.argv[2]=='death' else ['serviceLifecycle']
 e['stages']=[]
 for method in methods:
  r=run(['shell','am','instrument','-w','-r','-e','class','dev.kidremote.child.enforcement.EnforcementRuntimeTest#'+method,app+'.test/androidx.test.runner.AndroidJUnitRunner'])
  output=r.stdout+r.stderr;codes=re.findall(r'enforcement=([A-Z0-9_]+)',output)
  row={'method':method,'codes':codes,'failure':re.findall(r'ENFORCEMENT_RUNTIME_FAILED_LINE_[0-9]+',output),'result':'NOT_PASSED'};e['stages'].append(row)
  if method=='killWhileRestricted':
   marker=run(['exec-out','run-as',app,'cat','no_backup/enforcement-crash']).stdout.strip()
   assert marker=='EXPECTED_PRODUCT_ENFORCEMENT_KILL' and marker in codes and 'Process crashed' in output
   row['result']='EXPECTED_PROCESS_DEATH'
   own=run(['shell','dumpsys','package',app]).stdout
   e['afterKill']={'packageStopped':re.search(r'stopped=(true|false)',own).group(1) if re.search(r'stopped=(true|false)',own) else 'UNSPECIFIED','serviceStillEnabled':app+'/dev.kidremote.child.enforcement.ChildEnforcementService' in run(['shell','settings','get','secure','enabled_accessibility_services']).stdout}
  else:
   assert r.returncode==0 and 'OK (1 test)' in output and not re.search(r'FAILURES!!!|INSTRUMENTATION_FAILED|Process crashed',output)
   row['result']='PASS'
 e['result']='PASS'
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
 p=Path('/tmp/enforcement-android-'+str(time.time_ns())+'.json');p.write_text(json.dumps(e,indent=2)+'\n');print(json.dumps(e));print(p)
