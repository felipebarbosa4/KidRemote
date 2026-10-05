// Local fake ADB; never connects to a device. Pull copies an existing host test artifact.
using System;using System.IO;using System.Collections.Generic;using System.Text.RegularExpressions;
class NativeFixture {
 static int Main(string[] a){
  string line=String.Join(" ",a);string mode=Environment.GetEnvironmentVariable("KR_REVIEW_TEST_MODE");
  if(line=="devices"){Console.WriteLine("List of devices attached\nSYNTHETIC_PRIVATE_SERIAL device");return 0;}
  if(a.Length<3||a[0]!="-s"||a[1]!="SYNTHETIC_PRIVATE_SERIAL")return 9;
  if(a[2]=="pull") {if(mode=="badHash")File.WriteAllText(a[4],"invalid fixture");else File.Copy(Environment.GetEnvironmentVariable("KR_REVIEW_OLD_APK"),a[4]);Console.WriteLine("SYNTHETIC_PRIVATE_SERIAL copied");return 0;}
  if(line.Contains("shell -T run-as dev.kidremote.child.unassigned.debug sh")){
   string input=Console.In.ReadToEnd();if(mode=="denied"){Console.Error.WriteLine("PRIVATE_DENIAL");return 1;}
   var seen=new HashSet<string>();foreach(Match m in Regex.Matches(input,"printf '([A-Za-z_]+)\\|UNKNOWN")){string key=m.Groups[1].Value;if(!seen.Add(key))continue;Console.WriteLine(key+((mode=="present"&&key=="identity")?"|PRESENT|40":"|ABSENT|0"));}
   Console.WriteLine("LINKS|0\nTOTAL|"+(mode=="present"?"1":"0"));return 0;
  }
  string cmd=String.Join(" ",a,2,a.Length-2);string package=a[a.Length-1];
  if(cmd=="shell am get-current-user")Console.WriteLine("0");
  else if(cmd=="shell getprop ro.product.manufacturer")Console.WriteLine("samsung");
  else if(cmd=="shell getprop ro.product.model")Console.WriteLine("SM-X400");
  else if(cmd=="shell getprop ro.build.version.release")Console.WriteLine("16");
  else if(cmd=="shell getprop ro.build.version.sdk")Console.WriteLine("36");
  else if(cmd=="shell getprop ro.build.id")Console.WriteLine("BP4A.251205.006");
  else if(cmd=="shell getprop ro.build.version.security_patch")Console.WriteLine("2026-07-05");
  else if(cmd.EndsWith("get global low_power"))Console.WriteLine("0");
  else if(cmd.EndsWith("get global app_standby_enabled"))Console.WriteLine("1");
  else if(cmd.StartsWith("shell pm path "))Console.WriteLine("package:/data/app/"+(package.EndsWith("ordinary")?"fixture":"child")+"/base.apk");
  else if(cmd.StartsWith("shell pm list packages -u "))Console.WriteLine("package:"+package);
  else if(cmd.StartsWith("shell dumpsys package "))Console.WriteLine(" versionCode=1 minSdk=28\n versionName=0.0.1-local\n User 0: installed=true stopped=true");
  else if(cmd.StartsWith("shell sha256sum "))Console.WriteLine((cmd.Contains("/fixture/")?"223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc":"3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9")+"  "+package);
  else if(cmd.EndsWith("get secure enabled_accessibility_services"))Console.WriteLine("null");
  else if(cmd.EndsWith("get secure accessibility_enabled"))Console.WriteLine("0");
  else if(cmd.StartsWith("shell cmd appops get "))Console.WriteLine("GET_USAGE_STATS: ignore");
  else return 8;
  return 0;
 }
}
