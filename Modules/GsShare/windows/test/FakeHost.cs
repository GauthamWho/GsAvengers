// Headless stand-in for the Windows app, run with Mono on the Mac to test the real Windows link code
// against the real Mac app. Usage: mono FakeHost.exe <mac-ip> [script]
using System;
using System.Threading;
namespace GsAvengers
{
    public static class Installer { public static string Dir = System.IO.Path.GetTempPath(); }
    static class FakeHost
    {
        static void Main(string[] args)
        {
            var cfg = Settings.Load(System.IO.Path.Combine(System.IO.Path.GetTempPath(), "gsav-fakehost"));
            var link = new Link(cfg, "FAKE-WINDOWS");
            if (args.Length > 0 && args[0] != "discover") link.FixedHost = args[0];
            var trusted = new ManualResetEvent(false);
            link.OnStatus = s => Console.WriteLine("status: " + s);
            link.OnLog = s => Console.WriteLine("log: " + s);
            link.OnPairCode = (c, n) => { Console.WriteLine("PAIRCODE " + c + " with " + n); Console.Out.Flush(); new Thread(() => { Thread.Sleep(500); link.ConfirmPair(); }).Start(); };
            link.OnConnected = (id, n) => { Console.WriteLine("TRUSTED " + n + " " + id); trusted.Set(); };
            link.OnDisconnected = () => Console.WriteLine("DISCONNECTED");
            link.OnMessage = (t, a) => Console.WriteLine("MSG " + t + " " + BitConverter.ToString(a).Replace("-", "").Substring(0, Math.Min(40, a.Length * 2)) + (t == Msg.ClipText ? " '" + System.Text.Encoding.UTF8.GetString(a) + "'" : ""));
            link.Start();
            if (!trusted.WaitOne(900000)) { Console.WriteLine("NO TRUST"); return; }
            string script = args.Length > 1 ? args[1] : "basic";
            link.Send(Msg.Layout, new byte[] { 0 }); // Mac is on our left
            Thread.Sleep(300);
            if (script == "basic" || script == "move")
            {
                link.Send(Msg.Enter, Link.EdgeRatio(1, 0.5f));    // appear at the Mac's right edge, middle
                Thread.Sleep(400);
                for (int i = 0; i < 40; i++) { link.Send(Msg.Move, Link.I16x2(-10, -3)); Thread.Sleep(10); }
                Thread.Sleep(400);
                Console.WriteLine("moved; now pushing back right to leave");
                for (int i = 0; i < 120; i++) { link.Send(Msg.Move, Link.I16x2(20, 0)); Thread.Sleep(8); }
            }
            if (script == "health") Health(link);
            if (script == "clip") link.Send(Msg.ClipText, System.Text.Encoding.UTF8.GetBytes("hello from fake windows ✓"));
            if (script == "keys")
            {
                link.Send(Msg.Enter, Link.EdgeRatio(1, 0.5f)); Thread.Sleep(300);
                // Ctrl+Space (should become Fn+Space on the Mac)
                link.Send(Msg.Key, Link.KeyMsg(0xA2, 0x1D, true, false)); Thread.Sleep(50);
                link.Send(Msg.Key, Link.KeyMsg(0x20, 0x39, true, false)); Thread.Sleep(1500);
                link.Send(Msg.Key, Link.KeyMsg(0x20, 0x39, false, false)); Thread.Sleep(50);
                link.Send(Msg.Key, Link.KeyMsg(0xA2, 0x1D, false, false));
            }
            if (script == "shift")
            {
                // A harmless key check: Shift down and up, then F13 (no default action on a Mac).
                link.Send(Msg.Enter, Link.EdgeRatio(1, 0.5f)); Thread.Sleep(300);
                Key(link, 0xA0, true); Key(link, 0xA0, false);
                Tap(link, 0x7C);
                Console.WriteLine("keys sent"); Console.Out.Flush();
            }
            if (script == "shortcuts")
            {
                // Run with an empty TextEdit document in front. Checks Windows habits end to end.
                link.Send(Msg.Enter, Link.EdgeRatio(1, 0.5f)); Thread.Sleep(400);
                foreach (char c in "HELLO WORLD") Tap(link, c == ' ' ? 0x20 : (int)c);
                Tap(link, 0x24);                                   // Home -> line start
                Tap(link, 0x27, 0xA2, 0xA0);                      // Ctrl+Shift+Right -> select "hello"
                Tap(link, 0x43, 0xA2);                            // Ctrl+C -> copy (Mac sends the clipboard back)
                Thread.Sleep(600);
                Tap(link, 0x23);                                   // End
                Tap(link, 0x08, 0xA2);                            // Ctrl+Backspace -> delete "world"
                Tap(link, 0x41, 0xA2); Tap(link, 0x43, 0xA2);     // Ctrl+A, Ctrl+C -> "hello "
                Thread.Sleep(600);
                Key(link, 0xA4, true); Tap(link, 0x09); Thread.Sleep(400); Tap(link, 0x1B); Key(link, 0xA4, false); // Alt+Tab, Esc: no switch
                Thread.Sleep(300);
                Key(link, 0x5B, true); Key(link, 0x20, true); Thread.Sleep(1500); Key(link, 0x20, false); Key(link, 0x5B, false); // Win+Space -> fn Space
                Console.WriteLine("shortcuts sent");
            }
            if (script == "takeback")
            {
                // 1) enter the Mac, move, leave again; 2) enter and wait: a local trackpad move must send TAKE_BACK.
                link.Send(Msg.Enter, Link.EdgeRatio(1, 0.5f)); Thread.Sleep(300);
                for (int i = 0; i < 20; i++) { link.Send(Msg.Move, Link.I16x2(-10, 0)); Thread.Sleep(10); }
                for (int i = 0; i < 80; i++) { link.Send(Msg.Move, Link.I16x2(20, 0)); Thread.Sleep(8); }
                Thread.Sleep(500);
                Console.WriteLine("LEFT; entering again, waiting for local Mac input");
                link.Send(Msg.Enter, Link.EdgeRatio(1, 0.5f)); Thread.Sleep(300);
                for (int i = 0; i < 20; i++) { link.Send(Msg.Move, Link.I16x2(-10, 0)); Thread.Sleep(10); }
                Console.WriteLine("READY_FOR_LOCAL"); Console.Out.Flush();
            }
            Thread.Sleep(args.Length > 2 ? int.Parse(args[2]) : 3000);
            Console.WriteLine("done");
        }

        // "health": the Windows hooks give the input back as soon as Link.Healthy turns false. Freeze the Mac app
        // (kill -STOP) while this runs: the socket stays open but pings stop; Healthy must turn false within ~3 s.
        static void Health(Link link)
        {
            Console.WriteLine("HEALTHY " + link.Healthy + " (expect True)"); Console.Out.Flush();
            var t0 = DateTime.UtcNow; bool seenFalse = false;
            while ((DateTime.UtcNow - t0).TotalSeconds < 20)
            {
                if (!link.Healthy) { Console.WriteLine("UNHEALTHY after " + (int)(DateTime.UtcNow - t0).TotalMilliseconds + " ms"); seenFalse = true; break; }
                Thread.Sleep(100);
            }
            if (!seenFalse) Console.WriteLine("STILL HEALTHY after 20 s");
            Console.Out.Flush();
        }

        static void Key(Link link, int vk, bool down)
        {
            bool ext = vk == 0x24 || vk == 0x23 || vk == 0x25 || vk == 0x26 || vk == 0x27 || vk == 0x28 || vk == 0x2E || vk == 0x5B;
            link.Send(Msg.Key, Link.KeyMsg(vk, 0, down, ext)); Thread.Sleep(40);
        }
        static void Tap(Link link, int vk, params int[] mods)
        {
            foreach (int m in mods) Key(link, m, true);
            Key(link, vk, true); Key(link, vk, false);
            for (int i = mods.Length - 1; i >= 0; i--) Key(link, mods[i], false);
        }
    }
}
