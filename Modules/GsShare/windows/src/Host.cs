// G's Avengers — Windows side: watches the real mouse/keyboard and hands them to the Mac past the screen edge.
using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

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
        readonly bool[] localDown = new bool[256];    // keys pressed while local (their key-up stays local); plain arrays: no hashing on the hook
        readonly bool[] remoteDown = new bool[256];
        int buttonsDown;
        int cooldownEnd = Environment.TickCount;      // tick count; edge switching is off until then
        Rectangle vs;                                 // cached virtual screen (refreshed when displays change)
        readonly EventHandler displayChanged;
        readonly InputQueue q;                        // hook thread -> sender thread, no network work on the hook
        public int PeerSide = 0;        // where the Mac sits relative to this PC (0 left by default)
        public Action<bool> OnRemoteChanged;

        public Host(Link link, Control ui)
        {
            this.link = link; this.ui = ui;
            q = new InputQueue(link);
            goHome = () => GoLocal(-1);
            vs = SystemInformation.VirtualScreen;
            displayChanged = (o, e) => { vs = SystemInformation.VirtualScreen; };
        }
        public bool Remote { get { return remote; } }

        public void Install()
        {
            mouseProc = MouseHook; keyProc = KeyHook;
            IntPtr mod = GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName);
            mouseHook = SetWindowsHookEx(WH_MOUSE_LL, mouseProc, mod, 0);
            keyHook = SetWindowsHookEx(WH_KEYBOARD_LL, keyProc, mod, 0);
            SystemEvents.DisplaySettingsChanged += displayChanged;
        }

        public void Uninstall()
        {
            if (mouseHook != IntPtr.Zero) UnhookWindowsHookEx(mouseHook);
            if (keyHook != IntPtr.Zero) UnhookWindowsHookEx(keyHook);
            mouseHook = keyHook = IntPtr.Zero;
            SystemEvents.DisplaySettingsChanged -= displayChanged;
        }

        // ---- switching ----

        void GoRemote(Point at)
        {
            float ratio = (PeerSide == 0 || PeerSide == 1) ? (at.Y - vs.Top) / (float)Math.Max(1, vs.Height - 1)
                                                            : (at.X - vs.Left) / (float)Math.Max(1, vs.Width - 1);
            remote = true;
            Array.Clear(remoteDown, 0, 256);
            Rectangle pb = System.Windows.Forms.Screen.PrimaryScreen.Bounds;
            park = new Point(pb.Left + pb.Width / 2, pb.Top + pb.Height / 2);
            SetCursorPos(park.X, park.Y);
            q.Put(Msg.Enter, Sides.Opposite(PeerSide), 0, ratio);
            var h = OnRemoteChanged; if (h != null) h(true);
        }

        /// edge = the Mac's edge that was crossed; ratio along it. Pass -1 for "just come back to the edge",
        /// -2 for "stay where you are parked" (the Mac took control back with its own trackpad).
        public void GoLocal(float ratio)
        {
            if (!remote) return;
            remote = false;
            q.Put(Msg.ReleaseAll, 0, 0, 0);
            Array.Clear(remoteDown, 0, 256);
            if (ratio <= -2)
            {
                cooldownEnd = Environment.TickCount + 250;
                var hb = OnRemoteChanged; if (hb != null) hb(false);
                return;
            }
            vs = SystemInformation.VirtualScreen;
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
            cooldownEnd = Environment.TickCount + 250;
            var h = OnRemoteChanged; if (h != null) h(false);
        }

        bool AtEdge(int x, int y)
        {
            switch (PeerSide)
            {
                case 0: return x <= vs.Left;
                case 1: return x >= vs.Right - 1;
                case 2: return y <= vs.Top;
                default: return y >= vs.Bottom - 1;
            }
        }

        // ---- hooks (run on the UI thread; must return fast: read a few ints, queue a struct, done) ----
        // MSLLHOOKSTRUCT: pt.x @0, pt.y @4, mouseData @8, flags @12.  KBDLLHOOKSTRUCT: vkCode @0, scanCode @4, flags @8.

        IntPtr MouseHook(int code, IntPtr w, IntPtr l)
        {
            if (code < 0) return CallNextHookEx(mouseHook, code, w, l);
            int msg = (int)w.ToInt64();
            int px = Marshal.ReadInt32(l, 0), py = Marshal.ReadInt32(l, 4);
            uint mouseData = (uint)Marshal.ReadInt32(l, 8), flags = (uint)Marshal.ReadInt32(l, 12);
            bool injected = (flags & LLMHF_INJECTED) != 0;

            if (!remote)
            {
                if (msg == WM_LBUTTONDOWN || msg == WM_RBUTTONDOWN || msg == WM_MBUTTONDOWN) buttonsDown++;
                else if ((msg == WM_LBUTTONUP || msg == WM_RBUTTONUP || msg == WM_MBUTTONUP) && buttonsDown > 0) buttonsDown--;
                if (msg == WM_MOUSEMOVE && !injected && AtEdge(px, py) && buttonsDown == 0 && link.Trusted
                    && unchecked(Environment.TickCount - cooldownEnd) >= 0)
                {
                    GoRemote(new Point(px, py));
                    return (IntPtr)1;
                }
                return CallNextHookEx(mouseHook, code, w, l);
            }

            if (injected) return CallNextHookEx(mouseHook, code, w, l);
            switch (msg)
            {
                case WM_MOUSEMOVE:
                    int dx = px - park.X, dy = py - park.Y;
                    if (dx != 0 || dy != 0) q.Move(dx, dy);
                    break;
                case WM_LBUTTONDOWN: Btn(0, true); break;
                case WM_LBUTTONUP: Btn(0, false); break;
                case WM_RBUTTONDOWN: Btn(1, true); break;
                case WM_RBUTTONUP: Btn(1, false); break;
                case WM_MBUTTONDOWN: Btn(2, true); break;
                case WM_MBUTTONUP: Btn(2, false); break;
                case WM_XBUTTONDOWN: Btn(((mouseData >> 16) & 0xFFFF) == 1 ? 3 : 4, true); break;
                case WM_XBUTTONUP: Btn(((mouseData >> 16) & 0xFFFF) == 1 ? 3 : 4, false); break;
                case WM_MOUSEWHEEL: q.Put(Msg.Wheel, 0, (short)((mouseData >> 16) & 0xFFFF), 0); break;
                case WM_MOUSEHWHEEL: q.Put(Msg.Wheel, (short)((mouseData >> 16) & 0xFFFF), 0, 0); break;
            }
            return (IntPtr)1; // swallow: Windows doesn't see it
        }

        void Btn(int b, bool down) { q.Put(Msg.Button, b, down ? 1 : 0, 0); }

        IntPtr KeyHook(int code, IntPtr w, IntPtr l)
        {
            if (code < 0) return CallNextHookEx(keyHook, code, w, l);
            int msg = (int)w.ToInt64();
            bool down = msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN;
            bool up = msg == WM_KEYUP || msg == WM_SYSKEYUP;
            uint vkCode = (uint)Marshal.ReadInt32(l, 0), flags = (uint)Marshal.ReadInt32(l, 8);
            if ((flags & LLKHF_INJECTED) != 0 || (!down && !up)) return CallNextHookEx(keyHook, code, w, l);
            int vk = (int)(vkCode & 0xFF);

            if (!remote)
            {
                localDown[vk] = down;
                return CallNextHookEx(keyHook, code, w, l);
            }

            // a key that went down on Windows before the switch: let its key-up reach Windows
            if (up && localDown[vk] && !remoteDown[vk])
            {
                localDown[vk] = false;
                return CallNextHookEx(keyHook, code, w, l);
            }

            // safety: Ctrl+Alt+Esc always brings the mouse home
            if (down && vk == 0x1B && Held(0x11) && Held(0x12))
            {
                ui.BeginInvoke(goHome);
                return (IntPtr)1;
            }

            remoteDown[vk] = down;
            int scan = Marshal.ReadInt32(l, 4);
            q.Put(Msg.Key, (int)vkCode, scan, 0, down, (flags & LLKHF_EXTENDED) != 0);
            return (IntPtr)1;
        }
        Action goHome;

        bool Held(int vk)
        {
            // what the Mac side has been told is down (Windows itself doesn't see these keys while remote)
            if (vk == 0x11) return remoteDown[0xA2] || remoteDown[0xA3] || remoteDown[0x11];
            if (vk == 0x12) return remoteDown[0xA4] || remoteDown[0xA5] || remoteDown[0x12];
            return (GetAsyncKeyState(vk) & 0x8000) != 0;
        }
    }

    /// Hand-off from the hook thread to one sender thread. A fixed ring of small structs guarded by a lock that is held
    /// for a few instructions: the hook never allocates, never encrypts, never touches the socket. When the sender falls
    /// behind, consecutive mouse moves are merged into one (summed deltas), so a backlog never builds up.
    /// Everything Host sends goes through here, so ENTER / moves / keys / RELEASE_ALL keep their order.
    sealed class InputQueue
    {
        struct Ev { public Msg Type; public int A, B; public float F; public bool Down, Ext; }
        const int Size = 1024, Mask = Size - 1;
        readonly Ev[] ring = new Ev[Size];
        readonly Ev[] batch = new Ev[Size];
        int head, count;                               // head = oldest unsent
        readonly object gate = new object();
        readonly AutoResetEvent ready = new AutoResetEvent(false);
        readonly Link link;

        public InputQueue(Link link)
        {
            this.link = link;
            var t = new Thread(Run) { IsBackground = true, Name = "GsAvengers input sender", Priority = ThreadPriority.AboveNormal };
            t.Start();
        }

        public void Move(int dx, int dy)
        {
            bool wake;
            lock (gate)
            {
                if (count > 0)
                {
                    int last = (head + count - 1) & Mask;
                    if (ring[last].Type == Msg.Move)
                    {
                        int nx = ring[last].A + dx, ny = ring[last].B + dy;
                        if (nx >= short.MinValue && nx <= short.MaxValue && ny >= short.MinValue && ny <= short.MaxValue)
                        { ring[last].A = nx; ring[last].B = ny; return; }   // merged; the sender is already signalled
                    }
                }
                wake = Push(Msg.Move, dx, dy, 0, false, false);
            }
            if (wake) ready.Set();
        }

        public void Put(Msg type, int a, int b, float f) { Put(type, a, b, f, false, false); }

        public void Put(Msg type, int a, int b, float f, bool down, bool ext)
        {
            bool wake;
            lock (gate) wake = Push(type, a, b, f, down, ext);
            if (wake) ready.Set();
        }

        // caller holds gate; returns true when the queue went from empty to non-empty (the sender needs a nudge)
        bool Push(Msg type, int a, int b, float f, bool down, bool ext)
        {
            if (count == Size) return false;           // 1024 events behind: drop (RELEASE_ALL on the way home clears keys)
            int i = (head + count) & Mask;
            ring[i].Type = type; ring[i].A = a; ring[i].B = b; ring[i].F = f; ring[i].Down = down; ring[i].Ext = ext;
            count++;
            return count == 1;
        }

        void Run()
        {
            while (true)
            {
                ready.WaitOne();
                int n;
                lock (gate)
                {
                    n = count;
                    for (int i = 0; i < n; i++) batch[i] = ring[(head + i) & Mask];
                    head = (head + n) & Mask; count = 0;
                }
                for (int i = 0; i < n; i++)
                {
                    try { Send(ref batch[i]); } catch (Exception) { }
                }
            }
        }

        static readonly byte[] Empty = new byte[0];

        void Send(ref Ev e)
        {
            switch (e.Type)
            {
                case Msg.Move:
                case Msg.Wheel: link.Send(e.Type, Link.I16x2(e.A, e.B)); break;
                case Msg.Button: link.Send(Msg.Button, new byte[] { (byte)e.A, (byte)e.B }); break;
                case Msg.Key: link.Send(Msg.Key, Link.KeyMsg(e.A, e.B, e.Down, e.Ext)); break;
                case Msg.Enter: link.Send(Msg.Enter, Link.EdgeRatio(e.A, e.F)); break;
                default: link.Send(e.Type, Empty); break;
            }
        }
    }
}
