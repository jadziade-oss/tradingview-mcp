// Activates an MSIX-packaged desktop app via IApplicationActivationManager, the same
// COM API Explorer/Start Menu use to launch packaged apps, passing extra arguments
// through to the app's own activation handler.
//
// Why this exists: on Windows, TradingView Desktop is MSIX-only (both the Microsoft
// Store install and the "standalone" download from tradingview.com are MSIX packages).
// MSIX enforces package identity, so:
//   - Running the exe directly from WindowsApps is denied.
//   - Copying the exe out to a writable folder (this repo's tv_launch fallback) lets
//     it start, but it exits immediately (no package identity) instead of opening a
//     window -- confirmed on TradingView.Desktop 3.4.1.x.
// IApplicationActivationManager is the documented, supported way to launch a packaged
// app as itself while still passing launch arguments (here, --remote-debugging-port).
// No Developer Mode, no admin rights, nothing installed.
// Docs: https://learn.microsoft.com/windows/win32/api/shobjidl_core/nn-shobjidl_core-iapplicationactivationmanager
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("2E941141-7F97-4756-BA1D-9DECDE894A3D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IApplicationActivationManager
{
    [PreserveSig]
    int ActivateApplication(
        [In] string appUserModelId,
        [In] string arguments,
        [In] uint options,
        [Out] out uint processId);
}

[ComImport, Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C")]
public class ApplicationActivationManagerClass
{
}

public class LaunchTvMsix
{
    public static int Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("Usage: LaunchTvMsix.exe <AUMID> <arguments>");
            Console.Error.WriteLine("Example: LaunchTvMsix.exe \"TradingView.Desktop_n534cwy3pjxzj!TradingView.Desktop\" \"--remote-debugging-port=9222\"");
            return 2;
        }
        string aumid = args[0];
        string arguments = args[1];

        var aam = (IApplicationActivationManager)new ApplicationActivationManagerClass();
        uint processId;
        int hr = aam.ActivateApplication(aumid, arguments, 0, out processId);
        if (hr != 0)
        {
            Console.Error.WriteLine("ActivateApplication failed, HRESULT 0x{0:X8}: {1}", hr, Marshal.GetExceptionForHR(hr).Message);
            return 1;
        }
        Console.WriteLine("Activated. PID: {0}", processId);
        return 0;
    }
}
