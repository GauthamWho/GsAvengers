// G's Avengers — Windows entry point + one-click installer (the exe installs itself on first run)
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

namespace GsAvengers
{
    public static class Installer
    {
        public static readonly string Dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "GsAvengers");
        public static readonly string Exe = Path.Combine(Dir, "GsAvengers.exe");
        const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        static string Shortcut { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "G's Avengers.lnk"); } }

        public static bool IsInstalledCopy()
        {
            return string.Equals(Path.GetFullPath(Application.ExecutablePath), Path.GetFullPath(Exe), StringComparison.OrdinalIgnoreCase);
        }

        public static bool StartsWithWindows()
        {
            using (var k = Registry.CurrentUser.OpenSubKey(RunKey)) return k != null && k.GetValue("GsAvengers") != null;
        }

        public static void SetStartWithWindows(bool on)
        {
            using (var k = Registry.CurrentUser.CreateSubKey(RunKey))
            {
                if (on) k.SetValue("GsAvengers", "\"" + Exe + "\" --background");
                else k.DeleteValue("GsAvengers", false);
            }
        }

        static void StopOthers()
        {
            int me = Process.GetCurrentProcess().Id;
            foreach (var p in Process.GetProcessesByName("GsAvengers"))
            {
                if (p.Id == me) continue;
                try { p.Kill(); p.WaitForExit(3000); } catch { }
            }
        }

        static void RunPowerShell(string script)
        {
            try
            {
                var psi = new ProcessStartInfo("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -Command \"" + script.Replace("\"", "\\\"") + "\"")
                { CreateNoWindow = true, UseShellExecute = false, WindowStyle = ProcessWindowStyle.Hidden };
                using (var p = Process.Start(psi)) p.WaitForExit(15000);
            }
            catch (Exception e) { Log.Write("powershell: " + e.Message); }
        }

        /// Copy to %LOCALAPPDATA%\GsAvengers, add Start menu + start-with-Windows, launch it.
        public static void Install()
        {
            StopOthers();
            Directory.CreateDirectory(Dir);
            for (int i = 0; i < 10; i++)
            {
                try { File.Copy(Application.ExecutablePath, Exe, true); break; }
                catch (IOException) { Thread.Sleep(300); }
            }
            SetStartWithWindows(true);
            RunPowerShell("$s=(New-Object -ComObject WScript.Shell).CreateShortcut('" + Shortcut.Replace("'", "''") + "');$s.TargetPath='" + Exe.Replace("'", "''") + "';$s.IconLocation='" + Exe.Replace("'", "''") + ",0';$s.Save()");
            Process.Start(new ProcessStartInfo(Exe, "--show") { UseShellExecute = false });
        }

        public static void Uninstall()
        {
            SetStartWithWindows(false);
            try { File.Delete(Shortcut); } catch { }
            // delete the folder after we exit
            try
            {
                Process.Start(new ProcessStartInfo("cmd.exe", "/c timeout /t 2 >nul & rmdir /s /q \"" + Dir + "\"")
                { CreateNoWindow = true, UseShellExecute = false, WindowStyle = ProcessWindowStyle.Hidden });
            }
            catch { }
        }
    }

    static class Program
    {
        [DllImport("user32.dll")] static extern bool SetProcessDPIAware();

        [STAThread]
        static void Main(string[] args)
        {
            try { SetProcessDPIAware(); } catch { }
            Directory.CreateDirectory(Installer.Dir);
            Log.PathName = Path.Combine(Installer.Dir, "log.txt");
            string a = string.Join(" ", args);

            if (a.Contains("--selftest")) { Environment.Exit(SelfTest.Run() ? 0 : 1); return; }
            if (args.Length >= 2 && args[0] == "--render-preview")
            {
                MainForm.PreviewMode = true;
                var f = new MainForm(Settings.Load(Path.Combine(Path.GetTempPath(), "gsav-preview")), false);
                f.RenderPreview(args[1], args.Length > 2);
                return;
            }

            if (!Installer.IsInstalledCopy() && !a.Contains("--portable"))
            {
                Installer.Install();
                return;
            }

            bool created;
            using (var m = new Mutex(true, "Local\\GsAvengers-single", out created))
            {
                if (!created) return; // already running
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                var cfg = Settings.Load(Installer.Dir);
                Application.Run(new MainForm(cfg, !a.Contains("--background")));
            }
        }
    }
}
