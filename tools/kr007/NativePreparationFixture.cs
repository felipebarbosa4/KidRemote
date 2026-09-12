// Synthetic host process only: never communicates with a device.
using System;
using System.Threading;
class NativePreparationFixture {
    static int Main(string[] args) {
        string mode = args[0];
        if (mode == "info") { Console.Error.WriteLine("informational stderr"); Console.Out.WriteLine("Success"); return 0; }
        if (mode == "reject") { Console.Error.WriteLine("Failure [INSTALL_FAILED_USER_RESTRICTED: PRIVATE_SYNTHETIC_DETAIL]"); return 7; }
        if (mode == "missing") { Console.Out.WriteLine("completed without success marker"); return 0; }
        if (mode == "slow") { Thread.Sleep(30000); return 0; }
        if (mode == "args") { Console.Out.WriteLine(args[1]); return 0; }
        return 8;
    }
}
