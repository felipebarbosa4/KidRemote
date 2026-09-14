// Native fake executable for device-free entrypoint tests. Never talks to adb or a device.
using System;
class InventoryFixture {
 static int Main(string[] args) {
  string line=String.Join(" ",args);string mode=Environment.GetEnvironmentVariable("KR_INVENTORY_TEST_MODE");
  if(mode=="reject"){Console.Error.WriteLine("SYNTHETIC_PRIVATE_SERIAL_DETAIL");return 7;}
  if(line=="devices"){Console.WriteLine("List of devices attached\nSYNTHETIC_PRIVATE_SERIAL device");return 0;}
  if(!line.StartsWith("-s SYNTHETIC_PRIVATE_SERIAL shell "))return 8;
  line=line.Substring("-s SYNTHETIC_PRIVATE_SERIAL shell ".Length);
  if(line=="am get-current-user")Console.WriteLine("0");
  else if(line=="getprop ro.product.manufacturer")Console.WriteLine("samsung");
  else if(line=="getprop ro.product.model")Console.WriteLine(mode=="mismatch"?"OTHER":"SM-X400");
  else if(line=="getprop ro.build.version.release")Console.WriteLine("16");
  else if(line=="getprop ro.build.version.sdk")Console.WriteLine("36");
  else if(line=="getprop ro.build.id")Console.WriteLine("BP4A.251205.006");
  else if(line=="getprop ro.build.version.security_patch")Console.WriteLine("2026-07-05");
  else if(line=="settings --user current get global low_power")Console.WriteLine("0");
  else if(line=="settings --user current get global app_standby_enabled")Console.WriteLine("1");
  else if(line.StartsWith("pm path dev.kidremote.") || line.StartsWith("pm list packages -u dev.kidremote."))Console.WriteLine("");
  else return 9;
  return 0;
 }
}
