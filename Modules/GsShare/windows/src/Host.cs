// G's Avengers — Windows side: watches the real mouse/keyboard and hands them to the Mac past the screen edge.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace GsAvengers
{
    public class Host
    {
        // ---- Win32 ----
        delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);
        [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SetWindowsHookEx(int id, HookProc fn, IntPtr mod, uint thread);
        [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr h);
        [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int code, IntPtr w, IntPtr l);
        [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string name);
        [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
        [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);

        [StructLayout(LayoutKind.Sequential)] struct POINT { public int x, y; }
        [StructLayout(LayoutKind.Sequential)] struct MSLLHOOKSTRUCT { public POINT pt; public uint mouseData, flags, time; public IntPtr extra; }
        [StructLayout(LayoutKind.Sequential)] struct KBDLLHOOKSTRUCT { public uint vkCode, scanCode, flags, time; public IntPtr extra; }

        const int WH_KEYBOARD_LL = 13, WH_MOUSE_LL = 14;
        const int WM_MOUSEMOVE = 0x200, WM_LBUTTONDOWN = 0x201, WM_LBUTTONUP = 0x202, WM_RBUTTONDOWN = 0x204, WM_RBUTTONUP = 0x205,
                  WM_MBUTTONDOWN = 0x207, WM_MBUTTONUP = 0x208, WM_MOUSEWHEEL = 0x20A, WM_XBUTTONDOWN = 0x20B, WM_XBUTTONUP = 0x20C, WM_MOUSEHWHEEL = 0x20E;
        const int WM_KEYDOWN = 0x100, WM_KEYUP = 0x101, WM_SYSKEYDOWN = 0x104, WM_SYSKEYUP = 0x105;
        const uint LLMHF_INJECTED = 1, LLKHF_EXTENDED = 1, LLKHF_INJECTED = 0x10;

        // ---- state ----
        readonly Link link;
        readonly Control ui;            // to run things on the UI thread
        HookProc mouseProc, keyProc;    // kept alive so the GC can't collect them
        IntPtr mouseHook, keyHook;
        volatile bool remote;           // true while the cursor is on the Mac
        Point park;                     // where the Windows cursor waits while remote
        readonly HashSet<uint> localDown = new HashSet<uint>();   // keys pressed while local (their key-up stays local)
        readonly HashSet<uint> remoteDown = new HashSet<uint>();
        int buttonsDown;
        DateTime cooldownUntil = DateTime.MinValue;
        public int PeerSide = 0;        // where the Mac sits relative to this PC (0 left by default)
        public Action<bool> OnRemoteChanged;

        public Host(Link link, Control ui) { this.link = link; this.ui = ui; }
        public bool Remote { get { return remote; } }

        public void Install()
        {
            mouseProc = MouseHook; keyProc = KeyHook;
            IntPtr mod = GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName);
            mouseHook = SetWindowsHookEx(WH_MOUSE_LL, mouseProc, mod, 0);
            keyHook = SetWindowsHookEx(WH_KEYBOARD_LL, keyProc, mod, 0);
        }

        public void Uninstall()
        {
            if (mouseHook != IntPtr.Zero) UnhookWindowsHookEx(mouseHook);
            if (keyHook != IntPtr.Zero) UnhookWindowsHookEx(keyHook);
            mouseHook = keyHook = IntPtr.Zero;
        }

        static Rectangle Screen() { return SystemInformation.VirtualScreen; }

        // ---- switching ----

        void GoRemote(Point at)
        {
            Rectangle vs = Screen();
            float ratio = (PeerSide == 0 || PeerSide == 1) ? (at.Y - vs.Top) / (float)Math.Max(1, vs.Height - 1)
                                                            : (at.X - vs.Left) / (float)Math.Max(1, vs.Width - 1);
            remote = true;
            remoteDown.Clear();
            Rectangle pb = System.Windows.Forms.Screen.PrimaryScreen.Bounds;
            park = new Point(pb.Left + pb.Width / 2, pb.Top + pb.Height / 2);
            SetCursorPos(park.X, park.Y);
            link.Send(Msg.Enter, Link.EdgeRatio(Sides.Opposite(PeerSide), ratio));
            var h = OnRemoteChanged; if (h != null) h(true);
        }

        /// edge = the Mac's edge that was crossed; ratio along it. Pass -1 for "just come back to the edge",
        /// -2 for "stay where you are parked" (the Mac took control back with its own trackpad).
        public void GoLocal(float ratio)
        {
            if (!remote) return;
            remote = false;
            link.Send(Msg.ReleaseAll, new byte[0]);
            remoteDown.Clear();
            if (ratio <= -2)
            {
                cooldownUntil = DateTime.UtcNow.AddMilliseconds(250);
                var hb = OnRemoteChanged; if (hb != null) hb(false);
                return;
            }
            Rectangle vs = Screen();
            if (ratio < 0) ratio = 0.5f;
            int x, y;
            switch (PeerSide)
            {
                case 0: x = vs.Left + 3; y = vs.Top + (int)(ratio * (vs.Height - 1)); break;
                case 1: x = vs.Right - 4; y = vs.Top + (int)(ratio * (vs.Height - 1)); break;
                case 2: y = vs.Top + 3; x = vs.Left + (int)(ratio * (vs.Width - 1)); break;
                default: y = vs.Bottom - 4; x = vs.Left + (int)(ratio * (vs.Width - 1)); break;
            }
            SetCursorPos(x, y);
            cooldownUntil = DateTime.UtcNow.AddMilliseconds(250);
            var h = OnRemoteChanged; if (h != null) h(false);
        }

        bool AtEdge(Point p)
        {
            Rectangle vs = Screen();
            switch (PeerSide)
            {
                case 0: return p.X <= vs.Left;
                case 1: return p.X >= vs.Right - 1;
                case 2: return p.Y <= vs.Top;
                default: return p.Y >= vs.Bottom - 1;
            }
        }

        // ---- hooks (run on the UI thread; must stay fast) ----

        IntPtr MouseHook(int code, IntPtr w, IntPtr l)
        {
            if (code < 0) return CallNextHookEx(mouseHook, code, w, l);
            var m = (MSLLHOOKSTRUCT)Marshal.PtrToStructure(l, typeof(MSLLHOOKSTRUCT));
            int msg = w.ToInt32();
            bool injected = (m.flags & LLMHF_INJECTED) != 0;

            if (!remote)
            {
                if (msg == WM_LBUTTONDOWN || msg == WM_RBUTTONDOWN || msg == WM_MBUTTONDOWN) buttonsDown++;
                else if ((msg == WM_LBUTTONUP || msg == WM_RBUTTONUP || msg == WM_MBUTTONUP) && buttonsDown > 0) buttonsDown--;
                if (msg == WM_MOUSEMOVE && !injected && link.Trusted && buttonsDown == 0 && DateTime.UtcNow > cooldownUntil
                    && AtEdge(new Point(m.pt.x, m.pt.y)))
                {
                    GoRemote(new Point(m.pt.x, m.pt.y));
                    return (IntPtr)1;
                }
                return CallNextHookEx(mouseHook, code, w, l);
            }

            if (injected) return CallNextHookEx(mouseHook, code, w, l);
            switch (msg)
            {
                case WM_MOUSEMOVE:
                    int dx = m.pt.x - park.X, dy = m.pt.y - park.Y;
                    if (dx != 0 || dy != 0) link.Send(Msg.Move, Link.I16x2(dx, dy));
                    break;
                case WM_LBUTTONDOWN: Btn(0, true); break;
                case WM_LBUTTONUP: Btn(0, false); break;
                case WM_RBUTTONDOWN: Btn(1, true); break;
                case WM_RBUTTONUP: Btn(1, false); break;
                case WM_MBUTTONDOWN: Btn(2, true); break;
                case WM_MBUTTONUP: Btn(2, false); break;
                case WM_XBUTTONDOWN: Btn(((m.mouseData >> 16) & 0xFFFF) == 1 ? 3 : 4, true); break;
                case WM_XBUTTONUP: Btn(((m.mouseData >> 16) & 0xFFFF) == 1 ? 3 : 4, false); break;
                case WM_MOUSEWHEEL: link.Send(Msg.Wheel, Link.I16x2(0, (short)((m.mouseData >> 16) & 0xFFFF))); break;
                case WM_MOUSEHWHEEL: link.Send(Msg.Wheel, Link.I16x2((short)((m.mouseData >> 16) & 0xFFFF), 0)); break;
            }
            return (IntPtr)1; // swallow: Windows doesn't see it
        }

        void Btn(int b, bool down) { link.Send(Msg.Button, new byte[] { (byte)b, (byte)(down ? 1 : 0) }); }

        IntPtr KeyHook(int code, IntPtr w, IntPtr l)
        {
            if (code < 0) return CallNextHookEx(keyHook, code, w, l);
            var k = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(l, typeof(KBDLLHOOKSTRUCT));
            int msg = w.ToInt32();
            bool down = msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN;
            bool up = msg == WM_KEYUP || msg == WM_SYSKEYUP;
            if ((k.flags & LLKHF_INJECTED) != 0 || (!down && !up)) return CallNextHookEx(keyHook, code, w, l);

            if (!remote)
            {
                if (down) localDown.Add(k.vkCode); else localDown.Remove(k.vkCode);
                return CallNextHookEx(keyHook, code, w, l);
            }

            // a key that went down on Windows before the switch: let its key-up reach Windows
            if (up && localDown.Contains(k.vkCode) && !remoteDown.Contains(k.vkCode))
            {
                localDown.Remove(k.vkCode);
                return CallNextHookEx(keyHook, code, w, l);
            }

            // safety: Ctrl+Alt+Esc always brings the mouse home
            if (down && k.vkCode == 0x1B && Held(0x11) && Held(0x12))
            {
                ui.BeginInvoke((Action)(() => GoLocal(-1)));
                return (IntPtr)1;
            }

            if (down) remoteDown.Add(k.vkCode); else remoteDown.Remove(k.vkCode);
            link.Send(Msg.Key, Link.KeyMsg((int)k.vkCode, (int)k.scanCode, down, (k.flags & LLKHF_EXTENDED) != 0));
            return (IntPtr)1;
        }

        bool Held(int vk)
        {
            // what the Mac side has been told is down (Windows itself doesn't see these keys while remote)
            if (vk == 0x11) return remoteDown.Contains(0xA2) || remoteDown.Contains(0xA3) || remoteDown.Contains(0x11);
            if (vk == 0x12) return remoteDown.Contains(0xA4) || remoteDown.Contains(0xA5) || remoteDown.Contains(0x12);
            return (GetAsyncKeyState(vk) & 0x8000) != 0;
        }
    }
}
