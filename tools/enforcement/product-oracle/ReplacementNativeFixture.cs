using System;
using System.IO;
public static class ReplacementNativeFixture {
 public static int Main(string[] args) {
  if(args.Length<3 || args[0]!="-s" || args[1]!="SYNTHETIC")return 2;
  if(Environment.GetEnvironmentVariable("OD50_FAKE_FAILURE")=="1"){Console.Error.Write("SYNTHETIC_DENIAL");return 1;}
  var command=String.Join(" ",args,2,args.Length-2);
  var state=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"synthetic-reverse");
  if(command=="uninstall dev.kidremote.child.unassigned.debug"){Console.Write("Success");return 0;}
  if(command=="reverse --list"){if(File.Exists(state))Console.Write("SYNTHETIC tcp:47366 tcp:47366");return 0;}
  if(command=="reverse --no-rebind tcp:47366 tcp:47366"){if(File.Exists(state))return 1;File.WriteAllText(state,"SYNTHETIC");return 0;}
  if(command=="reverse --remove tcp:47366"){if(!File.Exists(state))return 1;File.Delete(state);return 0;}
  return 3; // Cannot delegate to a real ADB or execute any supplied command.
 }
}
