using System;
using System.IO;
using System.Linq;
class MetadataObservationFixture {
 static int Main(string[] original) {
  if(original.Length>0 && original[0].StartsWith("--enable-native-access",StringComparison.Ordinal)) {
   Console.WriteLine("Verifies");Console.WriteLine("Number of signers: 1");Console.WriteLine("V2 Signer: certificate SHA-256 digest: "+Environment.GetEnvironmentVariable("KR_METADATA_SIGNER"));return 0;
  }
  var args=original.ToList();if(args.Count>=2 && args[0]=="-s"){args.RemoveRange(0,2);}var line=String.Join(" ",args);
  if(line=="devices")Console.WriteLine("List of devices attached\nSYNTHETIC_PRIVATE_SERIAL\tdevice");
  else if(line=="shell am get-current-user")Console.WriteLine("0");
  else if(line=="shell getprop ro.product.manufacturer")Console.WriteLine("samsung");
  else if(line=="shell getprop ro.product.model")Console.WriteLine("SM-X400");
  else if(line=="shell getprop ro.build.version.release")Console.WriteLine("16");
  else if(line=="shell getprop ro.build.version.sdk")Console.WriteLine("36");
  else if(line=="shell getprop ro.build.id")Console.WriteLine("BP4A.251205.006");
  else if(line=="shell getprop ro.build.version.security_patch")Console.WriteLine("2026-07-05");
  else if(line=="shell pm path dev.kidremote.child.unassigned.debug")Console.WriteLine("package:/data/app/~~child/base.apk");
  else if(line=="shell pm path dev.kidremote.spike.ordinary")Console.WriteLine("package:/data/app/~~fixture/base.apk");
  else if(line=="shell dumpsys package dev.kidremote.child.unassigned.debug")Console.WriteLine("  versionCode=2 minSdk=28\n  versionName=0.0.2-local-physical-lab");
  else if(line=="shell dumpsys package dev.kidremote.spike.ordinary")Console.WriteLine("  versionCode=1 minSdk=28\n  versionName=0.0.1-fixture");
  else if(line.StartsWith("shell sha256sum /data/app/~~child/",StringComparison.Ordinal))Console.WriteLine(Environment.GetEnvironmentVariable("KR_METADATA_CHILD_HASH")+"  /data/app/~~child/base.apk");
  else if(line.StartsWith("shell sha256sum /data/app/~~fixture/",StringComparison.Ordinal))Console.WriteLine(Environment.GetEnvironmentVariable("KR_METADATA_FIXTURE_HASH")+"  /data/app/~~fixture/base.apk");
  else if(line=="reverse --list"){if(Environment.GetEnvironmentVariable("KR_METADATA_MODE")=="reversePresent")Console.WriteLine("SYNTHETIC_PRIVATE_SERIAL tcp:47366 tcp:47366");}
  else if(args.Count==3 && args[0]=="pull")File.Copy(Environment.GetEnvironmentVariable("KR_METADATA_APK"),args[2],false);
  else if(line=="shell -T run-as dev.kidremote.child.unassigned.debug sh"){
   Console.In.ReadToEnd();var mode=Environment.GetEnvironmentVariable("KR_METADATA_MODE");
   if(mode=="runFail"){Console.Error.WriteLine("PRIVATE_RAW_FAILURE");return 1;}
   if(mode=="reversePresent"){Console.Error.WriteLine("METADATA_SHOULD_NOT_RUN");return 9;}
   Console.WriteLine("OD51META|1");
   if(mode=="unexpected"){Console.WriteLine("UNEXPECTED|files|bounded-extra.dat|7");Console.WriteLine("COUNTS|1|0|1");}
   else {Console.WriteLine("COUNTS|0|0|0");}
   Console.WriteLine("END|1");
  } else {Console.Error.WriteLine("UNEXPECTED_COMMAND");return 9;}
  return 0;
 }
}
