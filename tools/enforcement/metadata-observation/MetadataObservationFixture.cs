using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
class MetadataObservationFixture {
 static int Main(string[] original) {
  var mode=Environment.GetEnvironmentVariable("KR_METADATA_MODE");
  if(original.Length>0 && original[0].StartsWith("--enable-native-access",StringComparison.Ordinal)) {
   var signer=mode=="signerMismatch" ? new String('d',64) : Environment.GetEnvironmentVariable("KR_METADATA_SIGNER");
   Console.WriteLine("Verifies");Console.WriteLine("Number of signers: 1");Console.WriteLine("V2 Signer: certificate SHA-256 digest: "+signer);return 0;
  }
  var args=original.ToList();if(args.Count>=2 && args[0]=="-s"){args.RemoveRange(0,2);}var line=String.Join(" ",args);
  if(line=="devices")Console.WriteLine("List of devices attached\nSYNTHETIC_PRIVATE_SERIAL\tdevice");
  else if(line=="shell am get-current-user"){Console.WriteLine("0");if(mode=="readStderr")Console.Error.WriteLine("PRIVATE_ORDINARY_READ_STDERR");}
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
  else if(line=="reverse --list"){if(mode=="reversePresent")Console.WriteLine("SYNTHETIC_PRIVATE_SERIAL tcp:47366 tcp:47366");}
  else if(args.Count==3 && args[0]=="pull"){
   if(mode=="pullExitNonzero"){Console.Error.WriteLine("PRIVATE_PULL_EXIT_FAILURE");return 7;}
   if(mode=="pullOversized"){Console.Error.Write(new String('x',32769));return 0;}
   if(mode=="pullMissing")return 0;
   if(mode=="pullTooLarge"){using(var f=File.Create(args[2]))f.SetLength(200L*1024L*1024L+1L);return 0;}
   if(mode=="pullHashMismatch"){File.WriteAllText(args[2],"different synthetic bytes");return 0;}
   if(mode=="pullReparse"){
    var target=Environment.GetEnvironmentVariable("KR_METADATA_REPARSE_TARGET");Directory.CreateDirectory(target);
    var p=new Process();p.StartInfo.FileName="cmd.exe";p.StartInfo.UseShellExecute=false;p.StartInfo.CreateNoWindow=true;p.StartInfo.RedirectStandardOutput=true;p.StartInfo.RedirectStandardError=true;
    p.StartInfo.Arguments="/d /c mklink /J \""+args[2]+"\" \""+target+"\"";p.Start();p.StandardOutput.ReadToEnd();p.StandardError.ReadToEnd();p.WaitForExit();return p.ExitCode;
   }
   File.Copy(Environment.GetEnvironmentVariable("KR_METADATA_APK"),args[2],false);
   if(mode=="pullStderr")Console.Error.WriteLine("PRIVATE_NORMAL_PULL_PROGRESS");
  }
  else if(line=="shell -T run-as dev.kidremote.child.unassigned.debug sh"){
   Console.In.ReadToEnd();
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
