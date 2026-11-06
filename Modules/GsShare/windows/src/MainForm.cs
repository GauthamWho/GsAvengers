// G's Avengers — Windows window in the "Frost" look (matches the Mac app), tray icon, clipboard.
// The whole window is drawn by hand (one double-buffered surface) so it can have soft glass cards,
// feathered shadows, springy buttons and toggles, and a draggable screen layout with snap zones.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Timer = System.Windows.Forms.Timer;

namespace GsAvengers
{
    public static class Theme
    {
        public static readonly Color BgTop = Color.FromArgb(0xF8, 0xF6, 0xF7), BgBottom = Color.FromArgb(0xEC, 0xF0, 0xF8);
        public static readonly Color Peach = Color.FromArgb(0xFF, 0xC4, 0xAE), Sky = Color.FromArgb(0xBF, 0xD3, 0xFF);
        public static readonly Color Text = Color.FromArgb(0x10, 0x13, 0x1F), Muted = Color.FromArgb(0x66, 0x6B, 0x7C);
        public static readonly Color Accent = Color.FromArgb(0xE4, 0x57, 0x2E), Accent2 = Color.FromArgb(0xFF, 0x94, 0x66);
        public static readonly Color Ok = Color.FromArgb(0x1F, 0xA4, 0x63);

        public static GraphicsPath Round(RectangleF r, float rad)
        {
            var p = new GraphicsPath(); float d = Math.Min(rad * 2, Math.Min(r.Width, r.Height));
            if (d <= 0) { p.AddRectangle(r); return p; }
            p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure(); return p;
        }

        /// Feathered shadow: many faint layers, no hard edge.
        public static void SoftShadow(Graphics g, RectangleF r, float rad, float spread, float dy, Color c, int strength)
        {
            int steps = 10;
            for (int i = steps; i >= 1; i--)
            {
                float k = i / (float)steps;
                var rr = new RectangleF(r.X - spread * k, r.Y - spread * k + dy, r.Width + 2 * spread * k, r.Height + 2 * spread * k);
                using (var p = Round(rr, rad + spread * k))
                using (var b = new SolidBrush(Color.FromArgb(Math.Max(1, (int)(strength * (1 - k) / steps * 2.2)), c))) g.FillPath(b, p);
            }
        }

        /// Frosted card: translucent white, soft top highlight, light hairline.
        public static void GlassCard(Graphics g, RectangleF r, float rad)
        {
            SoftShadow(g, r, rad, 16, 8, Color.FromArgb(0x3A, 0x4A, 0x7A), 60);
            using (var p = Round(r, rad))
            {
                using (var b = new SolidBrush(Color.FromArgb(150, 255, 255, 255))) g.FillPath(b, p);
                TopGloss(g, p, r, 110);
                using (var pen = new Pen(Color.FromArgb(220, 255, 255, 255), 1f)) g.DrawPath(pen, p);
            }
        }

        /// soft white gloss over the top half only (a gradient brush would otherwise repeat as a band)
        public static void TopGloss(Graphics g, GraphicsPath p, RectangleF r, int alpha)
        {
            var half = new RectangleF(r.X, r.Y, r.Width, r.Height / 2);
            var st = g.Save();
            g.SetClip(p, CombineMode.Intersect);
            g.SetClip(half, CombineMode.Intersect);
            using (var b = new LinearGradientBrush(new RectangleF(half.X, half.Y - 1, half.Width, half.Height + 2), Color.FromArgb(alpha, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f)) g.FillRectangle(b, half);
            g.Restore(st);
        }

        public static LinearGradientBrush AccentBrush(RectangleF r) { return new LinearGradientBrush(new RectangleF(r.X - 1, r.Y - 1, r.Width + 2, r.Height + 2), Accent2, Accent, 35f); }
        public static Color Mix(Color a, Color b, float t)
        {
            t = Math.Max(0, Math.Min(1, t));
            return Color.FromArgb((int)(a.A + (b.A - a.A) * t), (int)(a.R + (b.R - a.R) * t), (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t));
        }
    }

    /// Spring towards a target (gives the bouncy, physical feel).
    public class Spring
    {
        public float Value, Target, Vel;
        readonly float k, damp;
        public Spring(float v, float stiffness, float damping) { Value = Target = v; k = stiffness; damp = damping; }
        public bool Step(float dt)
        {
            float a = k * (Target - Value) - damp * Vel;
            Vel += a * dt; Value += Vel * dt;
            if (Math.Abs(Target - Value) < 0.0005f && Math.Abs(Vel) < 0.001f) { Value = Target; Vel = 0; return false; }
            return true;
        }
    }

    class Hit
    {
        public RectangleF R;
        public string Id;
        public Action Click;
        public Hit(RectangleF r, string id, Action click) { R = r; Id = id; Click = click; }
    }

    public class MainForm : Form
    {
        [DllImport("user32.dll")] static extern bool AddClipboardFormatListener(IntPtr h);
        [DllImport("user32.dll")] static extern bool RemoveClipboardFormatListener(IntPtr h);
        [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int val, int size);
        const int WM_CLIPBOARDUPDATE = 0x031D;

        readonly Settings cfg;
        readonly Link link;
        Host host;
        readonly NotifyIcon tray;
        readonly Icon appIcon;
        Bitmap logo;               // made on first paint, dropped while hidden
        bool reallyQuit, ignoreClip;
        int lastClipHash;

        // UI state
        string pairCode;           // null = no pairing card
        string pairName = "";
        bool pairWaiting;
        bool hasPeer; string peerName = "";
        int side = 0;              // where the Mac sits relative to this PC
        readonly float s;          // DPI scale
        readonly List<Hit> hits = new List<Hit>();
        string hoverId, pressId;

        // animation: the timer only runs while a spring is still moving (or the connect ripple plays); it is
        // started by a repaint that finds something in motion and stops itself once everything has settled.
        // Nothing animates on its own: no drifting backdrop, no endless pulse. Hidden / minimised = no timer at all.
        readonly Timer anim = new Timer();
        DateTime lastTick = DateTime.UtcNow;
        readonly Dictionary<string, Spring> springs = new Dictionary<string, Spring>();
        readonly Spring pairIn = new Spring(0, 170, 22);
        readonly Spring macX = new Spring(0, 260, 24), macY = new Spring(0, 260, 24), lift = new Spring(0, 300, 22);
        bool dragging; PointF dragStart, dragBase;
        float ripple = -1;

        public MainForm(Settings cfg, bool showOnStart)
        {
            this.cfg = cfg;
            link = new Link(cfg, Environment.MachineName);
            try { appIcon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { appIcon = SystemIcons.Application; }
            s = 1f; try { using (var g0 = Graphics.FromHwnd(IntPtr.Zero)) s = g0.DpiX / 96f; } catch { } // no window handle yet

            Text = "G's Avengers"; if (!PreviewMode) Icon = appIcon;
            FormBorderStyle = FormBorderStyle.FixedSingle; MaximizeBox = false;
            AutoScaleMode = AutoScaleMode.None;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            BackColor = Theme.BgTop;
            ClientSize = new Size(S(520), S(700));
            StartPosition = FormStartPosition.CenterScreen;
            KeyPreview = true;

            var p0 = SidePos(side); macX.Value = macX.Target = p0.X; macY.Value = macY.Target = p0.Y;

            var menu = new ContextMenuStrip();
            menu.Items.Add("Open G's Avengers", null, (o, e) => ShowMe());
            menu.Items.Add("Bring the mouse back", null, (o, e) => { if (host != null) host.GoLocal(-1); });
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Uninstall…", null, (o, e) => Uninstall());
            menu.Items.Add("Quit", null, (o, e) => { reallyQuit = true; Close(); });
            tray = new NotifyIcon { Icon = appIcon, Text = "G's Avengers", Visible = !PreviewMode, ContextMenuStrip = menu };
            tray.DoubleClick += (o, e) => ShowMe();

            anim.Interval = 16;
            anim.Tick += (o, e) => Tick();

            if (!showOnStart) { WindowState = FormWindowState.Minimized; ShowInTaskbar = false; Load += (o, e) => Hide(); }
            VisibleChanged += (o, e) => ShownChanged();
            Resize += (o, e) => { bool m = WindowState == FormWindowState.Minimized; if (m != wasMinimized) { wasMinimized = m; ShownChanged(); } };
            WireLink();
        }

        public static bool PreviewMode;
        int S(float v) { return (int)Math.Round(v * s); }

        /// Draws the window into a PNG with sample data (design check; no hooks, no network).
        public void RenderPreview(string path, bool pairing)
        {
            hasPeer = true; peerName = "Gautham's MacBook Air"; side = 0; startWin = true;
            var q = SidePos(0); macX.Value = macX.Target = q.X; macY.Value = macY.Target = q.Y;
            if (pairing) { pairCode = "482913"; pairName = "Gautham's MacBook Air"; pairIn.Value = pairIn.Target = 1; }
            using (var bmp = new Bitmap(ClientSize.Width, S(900)))
            using (var g = Graphics.FromImage(bmp))
            {
                ClientSize = new Size(ClientSize.Width, S(900));
                OnPaint(new PaintEventArgs(g, new Rectangle(0, 0, bmp.Width, bmp.Height)));
                using (var crop = bmp.Clone(new Rectangle(0, 0, bmp.Width, Math.Min(bmp.Height, lastHeight)), bmp.PixelFormat)) crop.Save(path, ImageFormat.Png);
            }
        }
        float F(float v) { return v * s; }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            if (PreviewMode) return;
            try
            {
                int round = 2; DwmSetWindowAttribute(Handle, 33, ref round, 4);              // Windows 11 rounded corners
                int cap = 0x00F7F6F8; DwmSetWindowAttribute(Handle, 35, ref cap, 4);         // caption colour (BGR) to match
                int txt = 0x001F1310; DwmSetWindowAttribute(Handle, 36, ref txt, 4);
            }
            catch { }
            AddClipboardFormatListener(Handle);
            host = new Host(link, this);
            host.OnRemoteChanged = r => UI(Invalidate);
            host.Install();
            link.Start();
        }

        // ---------- animation ----------

        Spring Sp(string id, float stiff, float damp)
        {
            Spring sp; if (!springs.TryGetValue(id, out sp)) { sp = new Spring(0, stiff, damp); springs[id] = sp; }
            return sp;
        }

        void Tick()
        {
            if (!OnScreen) { anim.Stop(); return; }
            var now = DateTime.UtcNow;
            float dt = (float)Math.Min(0.05, (now - lastTick).TotalSeconds);
            lastTick = now;
            bool moving = false;
            foreach (var kv in springs) moving |= kv.Value.Step(dt);
            moving |= pairIn.Step(dt); moving |= macX.Step(dt); moving |= macY.Step(dt); moving |= lift.Step(dt);
            if (ripple >= 0) { ripple += dt / 0.9f; if (ripple > 1) ripple = -1; moving = true; }
            Invalidate();                       // one more frame lands everything exactly on target
            if (!moving) anim.Stop();
        }

        bool OnScreen { get { return Visible && WindowState != FormWindowState.Minimized; } }

        static bool Settled(Spring sp) { return sp.Value == sp.Target && sp.Vel == 0; }

        /// called at the end of every paint: run the frame timer only if something is still in motion
        void KickIfMoving()
        {
            if (PreviewMode || anim.Enabled || !OnScreen) return;
            bool moving = ripple >= 0 || !Settled(pairIn) || !Settled(macX) || !Settled(macY) || !Settled(lift);
            if (!moving) foreach (var kv in springs) if (!Settled(kv.Value)) { moving = true; break; }
            if (moving) { lastTick = DateTime.UtcNow; anim.Start(); }
        }

        // ---------- hidden = light: no timer, no paint caches, small working set ----------

        [DllImport("kernel32.dll")] static extern bool SetProcessWorkingSetSize(IntPtr proc, IntPtr min, IntPtr max);
        [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
        bool wasMinimized, trimmed;

        void ShownChanged()
        {
            if (OnScreen)
            {
                trimmed = false;
                startWin = Installer.StartsWithWindows();   // registry read once per show, not once per paint
                Invalidate();
                return;
            }
            anim.Stop();
            ReleasePaintCache();
            if (!trimmed && !PreviewMode) { trimmed = true; UI(TrimMemory); }
        }

        void ReleasePaintCache()
        {
            foreach (var f in fonts.Values) f.Dispose();
            fonts.Clear();
            if (bg != null) { bg.Dispose(); bg = null; }
            if (logo != null) { logo.Dispose(); logo = null; }
            hits.Clear();
        }

        /// once after hiding: give the freed managed memory and the idle pages back to Windows
        void TrimMemory()
        {
            if (OnScreen) return;
            try
            {
                GC.Collect(); GC.WaitForPendingFinalizers(); GC.Collect();
                SetProcessWorkingSetSize(GetCurrentProcess(), (IntPtr)(-1), (IntPtr)(-1));
            }
            catch (Exception e) { Log.Write("trim: " + e.Message); }
        }

        // ---------- paint caches (rebuilt lazily on the next paint after a hide) ----------

        readonly Dictionary<string, Font> fonts = new Dictionary<string, Font>();
        Bitmap bg;                  // gradient + soft light, drawn once per window size
        bool startWin;
        readonly StringFormat Centered = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
        readonly StringFormat CenteredNoWrap = new StringFormat { Alignment = StringAlignment.Center, FormatFlags = StringFormatFlags.NoWrap };

        Font Fnt(string family, float size) { return Fnt(family, size, FontStyle.Regular); }
        Font Fnt(string family, float size, FontStyle style)
        {
            string key = family + "|" + size.ToString(System.Globalization.CultureInfo.InvariantCulture) + "|" + (int)style;
            Font f;
            if (!fonts.TryGetValue(key, out f)) { f = new Font(family, size, style); fonts[key] = f; }
            return f;
        }

        Bitmap Logo()
        {
            if (logo == null)
            {
                try { using (var ic = new Icon(appIcon, 256, 256)) logo = ic.ToBitmap(); } catch { logo = appIcon.ToBitmap(); }
            }
            return logo;
        }

        Bitmap Background(int w, int h)
        {
            if (bg != null && bg.Width == w && bg.Height == h) return bg;
            if (bg != null) bg.Dispose();
            bg = new Bitmap(Math.Max(1, w), Math.Max(1, h), PixelFormat.Format32bppPArgb);
            using (var g = Graphics.FromImage(bg))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                var rc = new Rectangle(0, 0, w, h);
                using (var b = new LinearGradientBrush(rc, Theme.BgTop, Theme.BgBottom, 90f)) g.FillRectangle(b, rc);
                Blob(g, w * 0.25f, F(130), F(300), Theme.Peach, 150);       // still light: placed once, never drifts
                Blob(g, w * 0.89f, F(452), F(340), Theme.Sky, 150);
            }
            return bg;
        }

        // ---------- layout + paint ----------

        PointF SidePos(int sd)
        {
            float gap = 18, pcW = 140, macW = 128, pcH = 86, macH = 84;
            switch (sd)
            {
                case 0: return new PointF(-((pcW + macW) / 2 + gap), 0);
                case 1: return new PointF((pcW + macW) / 2 + gap, 0);
                case 2: return new PointF(0, -((pcH + macH) / 2 + gap));
                default: return new PointF(0, (pcH + macH) / 2 + gap);
            }
        }

        int NearestSide(PointF p)
        {
            int best = 0; double bd = double.MaxValue;
            for (int i = 0; i < 4; i++) { var q = SidePos(i); double d = Math.Pow(q.X - p.X, 2) + Math.Pow(q.Y - p.Y, 2); if (d < bd) { bd = d; best = i; } }
            return best;
        }

        RectangleF stageRect;
        int lastHeight;

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            hits.Clear();

            // background: soft gradient + peach/sky light, cached as one bitmap
            g.DrawImageUnscaled(Background(ClientSize.Width, ClientSize.Height), 0, 0);

            g.ScaleTransform(s, s);
            float y = 24;

            // header
            g.DrawImage(Logo(), new RectangleF(20, y, 48, 48));
            using (var b = new SolidBrush(Theme.Text)) g.DrawString("G's Avengers", Fnt("Segoe UI Semibold", 17f), b, 80, y + 1);
            using (var b = new SolidBrush(Theme.Muted)) g.DrawString("One keyboard and mouse, two computers", Fnt("Segoe UI", 9.5f), b, 82, y + 30);
            Pill(g, 500, y + 12);
            y += 72;

            // pairing card (springs in)
            if (pairCode != null || pairIn.Value > 0.02f)
            {
                float k = pairIn.Value;
                float h = 210 * Math.Min(1, k);
                var st = g.Save();
                g.TranslateTransform(0, (1 - k) * -10);
                var r = new RectangleF(20, y, 480, 196);
                var cs = g.Save();
                g.SetClip(new RectangleF(0, y - 30, 520, h + 30));
                Theme.GlassCard(g, r, 22);
                Label(g, "PAIR WITH " + pairName.ToUpperInvariant(), 38, y + 18);
                using (var b = new SolidBrush(Theme.Text)) g.DrawString("Check the same number shows on the Mac.", Fnt("Segoe UI", 10f), b, 36, y + 38);
                string code = pairCode ?? "000000";
                for (int i = 0; i < 6; i++)
                {
                    float di = Math.Max(0, Math.Min(1, (k * 1.6f) - i * 0.1f));
                    var tr = new RectangleF(38 + i * 52 + (i >= 3 ? 12 : 0), y + 66 + (1 - di) * 14, 44, 54);
                    var ds = g.Save();
                    using (var p = Theme.Round(tr, 12))
                    {
                        Theme.SoftShadow(g, tr, 12, 6, 3, Color.FromArgb(0x3A, 0x4A, 0x7A), (int)(40 * di));
                        using (var b = new SolidBrush(Color.FromArgb((int)(220 * di), 255, 255, 255))) g.FillPath(b, p);
                        using (var pen = new Pen(Color.FromArgb((int)(255 * di), 255, 255, 255))) g.DrawPath(pen, p);
                    }
                    using (var b = new SolidBrush(Color.FromArgb((int)(255 * di), Theme.Text)))
                        g.DrawString(code[i].ToString(), Fnt("Segoe UI Semibold", 21f), b, tr, Centered);
                    g.Restore(ds);
                }
                if (pairWaiting)
                {
                    using (var b = new SolidBrush(Theme.Muted)) g.DrawString("Waiting for you to press Pair on the Mac…", Fnt("Segoe UI", 9.5f), b, 38, y + 146);
                }
                else Button(g, "pair", "Numbers match — Pair", new RectangleF(38, y + 136, 190, 40), true, () => { link.ConfirmPair(); pairWaiting = true; Invalidate(); });
                g.Restore(cs);
                g.Restore(st);
                y += h;
            }

            // screen layout card
            {
                var r = new RectangleF(20, y, 480, 330);
                Theme.GlassCard(g, r, 22);
                Label(g, "SCREEN LAYOUT", 38, y + 18);
                using (var b = new SolidBrush(Theme.Text))
                    g.DrawString(hasPeer ? "Drag the Mac to where it sits on your desk." : "Your Mac appears here once it connects.", Fnt("Segoe UI", 10f), b, 36, y + 38);
                stageRect = new RectangleF(36, y + 66, 448, 248);
                using (var p = Theme.Round(stageRect, 16))
                {
                    using (var b = new SolidBrush(Color.FromArgb(90, 255, 255, 255))) g.FillPath(b, p);
                    var cs = g.Save(); g.SetClip(p);
                    using (var b = new SolidBrush(Color.FromArgb(26, Theme.Text)))
                        for (float yy = stageRect.Y + 9; yy < stageRect.Bottom; yy += 18) for (float xx = stageRect.X + 9; xx < stageRect.Right; xx += 18) g.FillEllipse(b, xx, yy, 1.6f, 1.6f);
                    DrawStage(g);
                    g.Restore(cs);
                }
                y += 346;
            }

            // options card
            {
                var r = new RectangleF(20, y, 480, 132);
                Theme.GlassCard(g, r, 22);
                Label(g, "OPTIONS", 38, y + 18);
                Toggle(g, "clip", "Share the clipboard (text and pictures)", y + 44, cfg.ShareClipboard, () => { cfg.ShareClipboard = !cfg.ShareClipboard; cfg.Save(); });
                Toggle(g, "start", "Start with Windows", y + 84, startWin, () => { Installer.SetStartWithWindows(!startWin); startWin = Installer.StartsWithWindows(); });
                y += 148;
            }

            using (var b = new SolidBrush(Theme.Muted))
                g.DrawString("Push the pointer off the screen edge to move to the Mac; push it back to return. Ctrl+Alt+Esc always brings it home.", Fnt("Segoe UI", 8.5f), b, new RectangleF(24, y, 400, 44));
            LinkText(g, "uninstall", "Uninstall", 470, y + 2, Uninstall);
            y += 52;

            int want = S(y);
            lastHeight = want;
            if (!PreviewMode && Math.Abs(ClientSize.Height - want) > 1) Later(() => ClientSize = new Size(S(520), want));
            KickIfMoving();
        }

        void Blob(Graphics g, float cx, float cy, float rad, Color c, int alpha)
        {
            using (var path = new GraphicsPath())
            {
                path.AddEllipse(cx - rad, cy - rad, rad * 2, rad * 2);
                using (var b = new PathGradientBrush(path) { CenterColor = Color.FromArgb(alpha, c), SurroundColors = new[] { Color.FromArgb(0, c) } }) g.FillPath(b, path);
            }
        }

        void Label(Graphics g, string text, float x, float y)
        {
            var f = Fnt("Segoe UI Semibold", 7.6f);
            using (var b = new SolidBrush(Theme.Muted))
            {
                // letter-spaced caps
                float cx = x;
                foreach (char ch in text) { g.DrawString(ch.ToString(), f, b, cx, y); cx += g.MeasureString(ch.ToString(), f, PointF.Empty, StringFormat.GenericTypographic).Width + 1.6f; }
            }
        }

        void Pill(Graphics g, float right, float y)
        {
            bool on = link.Trusted;
            string txt = on ? (host != null && host.Remote ? "On the Mac" : "Connected") : "Searching";
            var f = Fnt("Segoe UI Semibold", 9f);
            {
                float w = g.MeasureString(txt, f).Width + 34;
                var r = new RectangleF(right - w, y, w, 26);
                using (var p = Theme.Round(r, 13))
                {
                    using (var b = new SolidBrush(Color.FromArgb(18, Theme.Text))) g.FillPath(b, p);
                    using (var pen = new Pen(Color.FromArgb(20, Theme.Text))) g.DrawPath(pen, p);
                }
                if (ripple >= 0 && on)
                {
                    float k = ripple; var rr = new RectangleF(r.X - 12 * k, r.Y - 6 * k, r.Width + 24 * k, r.Height + 12 * k);
                    using (var p = Theme.Round(rr, rr.Height / 2)) using (var pen = new Pen(Color.FromArgb((int)(150 * (1 - k)), Theme.Ok), 1.5f)) g.DrawPath(pen, p);
                }
                Color c = on ? Theme.Ok : Theme.Accent;
                const float pulse = 0.35f;   // a still halo while searching (an endless pulse kept the window repainting)
                if (!on) using (var b = new SolidBrush(Color.FromArgb((int)(110 * (1 - pulse)), c))) { float d = 8 + 10 * pulse; g.FillEllipse(b, r.X + 15 - d / 2, r.Y + 13 - d / 2, d, d); }
                using (var b = new SolidBrush(c)) g.FillEllipse(b, r.X + 11, r.Y + 9, 8, 8);
                using (var b = new SolidBrush(Theme.Text)) g.DrawString(txt, f, b, r.X + 24, r.Y + 4);
            }
        }

        void Button(Graphics g, string id, string text, RectangleF r, bool prominent, Action click)
        {
            var hov = Sp(id + ".h", 320, 20); hov.Target = hoverId == id ? 1 : 0;
            var prs = Sp(id + ".p", 500, 22); prs.Target = pressId == id ? 1 : 0;
            float sc = 1 + 0.03f * hov.Value - 0.05f * prs.Value;
            var rr = new RectangleF(r.X + r.Width * (1 - sc) / 2, r.Y + r.Height * (1 - sc) / 2, r.Width * sc, r.Height * sc);
            if (prominent)
            {
                Theme.SoftShadow(g, rr, rr.Height / 2, 10 + 6 * hov.Value, 4 + 2 * hov.Value, Theme.Accent, (int)(70 + 50 * hov.Value));
                using (var p = Theme.Round(rr, rr.Height / 2))
                {
                    using (var b = Theme.AccentBrush(rr)) g.FillPath(b, p);
                    Theme.TopGloss(g, p, rr, (int)(60 + 30 * hov.Value));
                }
            }
            else using (var p = Theme.Round(rr, rr.Height / 2)) using (var b = new SolidBrush(Color.FromArgb((int)(16 + 12 * hov.Value), Theme.Text))) g.FillPath(b, p);
            using (var b = new SolidBrush(prominent ? Color.White : Theme.Text))
                g.DrawString(text, Fnt("Segoe UI Semibold", 9.5f), b, rr, Centered);
            hits.Add(new Hit(r, id, click));
        }

        void Toggle(Graphics g, string id, string label, float y, bool on, Action click)
        {
            using (var b = new SolidBrush(Theme.Text)) g.DrawString(label, Fnt("Segoe UI", 10f), b, 36, y + 3);
            var k = Sp(id + ".k", 380, 20); k.Target = on ? 1 : 0;
            if (!initDone.Contains(id)) { k.Value = k.Target = on ? 1 : 0; initDone.Add(id); }
            var hov = Sp(id + ".h", 320, 20); hov.Target = hoverId == id ? 1 : 0;
            var r = new RectangleF(438, y, 46, 26);
            float v = Math.Max(0, Math.Min(1, k.Value));
            if (v > 0.01f) Theme.SoftShadow(g, r, 13, 6 + 3 * hov.Value, 2, Theme.Accent, (int)(60 * v));
            using (var p = Theme.Round(r, 13))
            {
                using (var b = new SolidBrush(Color.FromArgb(26, Theme.Text))) g.FillPath(b, p);
                if (v > 0.01f) using (var bb = new SolidBrush(Color.FromArgb((int)(255 * v), Theme.Mix(Theme.Accent2, Theme.Accent, 0.6f)))) g.FillPath(bb, p);
                using (var pen = new Pen(Color.FromArgb(200, 255, 255, 255), 0.8f)) g.DrawPath(pen, p);
            }
            float press = pressId == id ? 4 : 0;
            float kx = r.X + 2 + (r.Width - 26 - press) * k.Value;
            var kr = new RectangleF(kx, r.Y + 2, 22 + press, 22);
            Theme.SoftShadow(g, kr, 11, 3, 1.5f, Color.Black, 60);
            using (var p = Theme.Round(kr, 11)) using (var b = new LinearGradientBrush(kr, Color.White, Color.FromArgb(0xF3, 0xF4, 0xF8), 90f)) g.FillPath(b, p);
            hits.Add(new Hit(new RectangleF(30, y - 4, 460, 34), id, click));
        }
        readonly HashSet<string> initDone = new HashSet<string>();

        void LinkText(Graphics g, string id, string text, float x, float y, Action click)
        {
            var f = Fnt("Segoe UI", 8.5f, hoverId == id ? FontStyle.Underline : FontStyle.Regular);
            using (var b = new SolidBrush(hoverId == id ? Theme.Accent : Theme.Muted))
            {
                var sz = g.MeasureString(text, f);
                g.DrawString(text, f, b, x - sz.Width / 2, y);
                hits.Add(new Hit(new RectangleF(x - sz.Width / 2, y, sz.Width, sz.Height), id, click));
            }
        }

        void DrawStage(Graphics g)
        {
            var c = new PointF(stageRect.X + stageRect.Width / 2, stageRect.Y + stageRect.Height / 2);
            var basePos = SidePos(side);
            float ox = hasPeer && !dragging ? -macX.Value / 2 : (hasPeer ? -basePos.X / 2 : 0);
            float oy = hasPeer && !dragging ? -macY.Value / 2 : (hasPeer ? -basePos.Y / 2 : 0);
            c = new PointF(c.X + ox, c.Y + oy);

            if (dragging)
            {
                int near = NearestSide(new PointF(macX.Value, macY.Value));
                for (int i = 0; i < 4; i++)
                {
                    if (i == side) continue;
                    var q = SidePos(i);
                    var zr = new RectangleF(c.X + q.X - 64, c.Y + q.Y - 42, 128, 84);
                    using (var p = Theme.Round(zr, 12))
                    {
                        using (var b = new SolidBrush(Color.FromArgb(i == near ? 28 : 8, Theme.Accent))) g.FillPath(b, p);
                        using (var pen = new Pen(Color.FromArgb(i == near ? 200 : 70, Theme.Accent), 1.5f) { DashPattern = new float[] { 3, 3 } }) g.DrawPath(pen, p);
                    }
                }
            }

            bool remote = host != null && host.Remote;
            Screen(g, new RectangleF(c.X - 70, c.Y - 43, 140, 86), "This PC", remote ? "pointer is on the Mac" : Environment.MachineName, false, 0);
            if (hasPeer)
            {
                float lv = lift.Value;
                var mr = new RectangleF(c.X + macX.Value - 64, c.Y + macY.Value - 42, 128, 84);
                var mr2 = new RectangleF(mr.X - 3 * lv, mr.Y - 3 * lv, mr.Width + 6 * lv, mr.Height + 6 * lv);
                Screen(g, mr2, peerName.Length > 0 ? peerName : "Mac", link.Trusted ? (remote ? "pointer is here" : "connected") : "offline", true, lv);
                macRect = mr2;
            }
        }
        RectangleF macRect;

        void Screen(Graphics g, RectangleF r, string title, string sub, bool accent, float lift)
        {
            Theme.SoftShadow(g, r, 12, 10 + 8 * lift, 5 + 5 * lift, accent ? Theme.Accent : Color.FromArgb(0x3A, 0x4A, 0x7A), (int)(50 + 50 * lift));
            using (var p = Theme.Round(r, 12))
            {
                using (var b = new SolidBrush(Color.FromArgb(225, 255, 255, 255))) g.FillPath(b, p);
                if (accent) using (var b = new SolidBrush(Color.FromArgb(20, Theme.Accent))) g.FillPath(b, p);
                if (accent) using (var b = Theme.AccentBrush(r)) using (var pen = new Pen(b, 1.5f)) g.DrawPath(pen, p);
                else using (var pen = new Pen(Color.FromArgb(36, Theme.Text))) g.DrawPath(pen, p);
            }
            var sf = CenteredNoWrap;
            var ft = Fnt("Segoe UI Semibold", 9.5f); var fs = Fnt("Segoe UI", 8f);
            using (var b = new SolidBrush(Theme.Text)) g.DrawString(Fit(g, title, ft, r.Width - 14), ft, b, new RectangleF(r.X + 6, r.Y + r.Height / 2 - 14, r.Width - 12, 18), sf);
            using (var b = new SolidBrush(Theme.Muted)) g.DrawString(Fit(g, sub, fs, r.Width - 14), fs, b, new RectangleF(r.X + 6, r.Y + r.Height / 2 + 5, r.Width - 12, 16), sf);
        }

        /// shorten with "…" at the end so names never get cut on both sides
        static string Fit(Graphics g, string text, Font f, float width)
        {
            if (g.MeasureString(text, f).Width <= width) return text;
            for (int n = text.Length - 1; n > 1; n--) { string c = text.Substring(0, n).TrimEnd() + "…"; if (g.MeasureString(c, f).Width <= width) return c; }
            return text.Substring(0, 1) + "…";
        }

        // ---------- mouse ----------

        PointF Logical(Point p) { return new PointF(p.X / s, p.Y / s); }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            var p = Logical(e.Location);
            if (dragging)
            {
                macX.Target = macX.Value = dragBase.X + (p.X - dragStart.X);
                macY.Target = macY.Value = dragBase.Y + (p.Y - dragStart.Y);
                macX.Vel = macY.Vel = 0;
                Invalidate();
                return;
            }
            string h = null;
            foreach (var hit in hits) if (hit.R.Contains(p)) h = hit.Id;
            var want = hasPeer && macRect.Contains(p) ? Cursors.SizeAll : h != null ? Cursors.Hand : Cursors.Default;
            if (Cursor != want) Cursor = want;
            if (h != hoverId) { hoverId = h; Invalidate(); }
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            var p = Logical(e.Location);
            if (hasPeer && macRect.Contains(p))
            {
                dragging = true; dragStart = p; dragBase = new PointF(macX.Value, macY.Value); lift.Target = 1;
                Invalidate();
                return;
            }
            foreach (var hit in hits) if (hit.R.Contains(p)) pressId = hit.Id;
            if (pressId != null) Invalidate();
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            var p = Logical(e.Location);
            if (dragging)
            {
                dragging = false; lift.Target = 0;
                int ns = NearestSide(new PointF(macX.Value, macY.Value));
                var q = SidePos(ns); macX.Target = q.X; macY.Target = q.Y;
                if (ns != side) SetSide(ns);
                Invalidate();
                return;
            }
            string id = pressId; pressId = null;
            if (id != null) Invalidate();
            foreach (var hit in hits) if (hit.Id == id && hit.R.Contains(p) && hit.Click != null) { hit.Click(); break; }
        }

        protected override void OnMouseLeave(EventArgs e) { if (hoverId != null) { hoverId = null; Invalidate(); } base.OnMouseLeave(e); }

        // ---------- link ----------

        void UI(Action a) { if (IsHandleCreated) BeginInvoke(a); }
        void Later(Action a) { if (IsHandleCreated) BeginInvoke(a); }

        void WireLink()
        {
            link.OnStatus = st => UI(Invalidate);   // the pill reflects the link state
            link.OnLog = st => Log.Write(st);
            link.OnPairCode = (code, name) => UI(() =>
            {
                pairName = name; pairCode = code; pairWaiting = false; pairIn.Target = 1;
                ShowMe(); Invalidate();
            });
            link.OnConnected = (id, name) => UI(() =>
            {
                pairCode = null; pairIn.Target = 0;
                int sd; if (!cfg.PeerSide.TryGetValue(id, out sd)) sd = 0; // default: Mac on the left
                side = sd; host.PeerSide = sd; hasPeer = true; peerName = name;
                var q = SidePos(sd); macX.Target = q.X; macY.Target = q.Y;
                ripple = 0;
                link.Send(Msg.Layout, new byte[] { (byte)sd }); // payload = where the receiver (Mac) sits relative to us
                tray.Text = "G's Avengers — connected to " + (name.Length > 30 ? name.Substring(0, 30) : name);
                Invalidate();
            });
            link.OnDisconnected = () => UI(() => { if (host != null) host.GoLocal(-1); tray.Text = "G's Avengers — looking for your Mac"; Invalidate(); });
            link.OnMessage = (tp, a) =>
            {
                switch (tp)
                {
                    case Msg.Leave:
                        float ratio = a.Length >= 5 ? BitConverter.ToSingle(a, 1) : -1;
                        UI(() => host.GoLocal(ratio));
                        break;
                    case Msg.TakeBack: // someone used the Mac's own trackpad/keyboard: stop sending, pointer stays here
                        UI(() => host.GoLocal(-2));
                        break;
                    case Msg.Layout:
                        if (a.Length < 1) return;
                        int macSide = Sides.Opposite(a[0]); // payload = where this PC sits relative to the Mac
                        UI(() =>
                        {
                            cfg.PeerSide[link.PeerId] = macSide; cfg.Save(); host.PeerSide = macSide; side = macSide;
                            var q = SidePos(macSide); macX.Target = q.X; macY.Target = q.Y;
                            Invalidate();
                        });
                        break;
                    case Msg.ClipText:
                        if (!cfg.ShareClipboard) return;
                        string text = Encoding.UTF8.GetString(a).Replace("\r\n", "\n").Replace("\n", "\r\n");
                        UI(() => SetClip(() => Clipboard.SetText(text, TextDataFormat.UnicodeText), text.GetHashCode()));
                        break;
                    case Msg.ClipPNG:
                        if (!cfg.ShareClipboard) return;
                        UI(() =>
                        {
                            try
                            {
                                var ms = new MemoryStream(a);
                                using (var img = Image.FromStream(ms))
                                {
                                    var bmp = new Bitmap(img);
                                    var data = new DataObject();
                                    data.SetData(DataFormats.Bitmap, bmp);
                                    data.SetData("PNG", new MemoryStream(a));
                                    SetClip(() => Clipboard.SetDataObject(data, true), a.Length);
                                }
                            }
                            catch (Exception ex) { Log.Write("clip png: " + ex.Message); }
                        });
                        break;
                }
            };
        }

        void SetSide(int sd)
        {
            side = sd;
            cfg.PeerSide[link.PeerId] = sd; cfg.Save();
            if (host != null) host.PeerSide = sd;
            link.Send(Msg.Layout, new byte[] { (byte)sd });
        }

        void SetClip(Action set, int hash)
        {
            ignoreClip = true;
            for (int i = 0; i < 5; i++)
            {
                try { set(); break; } catch (ExternalException) { Thread.Sleep(60); }
            }
            lastClipHash = hash;
            var tm = new Timer { Interval = 300 }; tm.Tick += (o, e) => { ignoreClip = false; tm.Dispose(); }; tm.Start();
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_CLIPBOARDUPDATE && !ignoreClip && cfg.ShareClipboard && link.Trusted) OnLocalClipboard();
            base.WndProc(ref m);
        }

        void OnLocalClipboard()
        {
            try
            {
                if (Clipboard.ContainsText(TextDataFormat.UnicodeText))
                {
                    string tx = Clipboard.GetText(TextDataFormat.UnicodeText);
                    if (tx.GetHashCode() == lastClipHash || tx.Length > (8 << 20)) return;
                    lastClipHash = tx.GetHashCode();
                    link.Send(Msg.ClipText, Encoding.UTF8.GetBytes(tx.Replace("\r\n", "\n")));
                }
                else if (Clipboard.ContainsImage())
                {
                    using (var img = Clipboard.GetImage())
                    {
                        if (img == null) return;
                        var ms = new MemoryStream();
                        img.Save(ms, ImageFormat.Png);
                        byte[] png = ms.ToArray();
                        if (png.Length > (16 << 20) || png.Length == lastClipHash) return;
                        lastClipHash = png.Length;
                        link.Send(Msg.ClipPNG, png);
                    }
                }
            }
            catch (Exception ex) { Log.Write("clipboard: " + ex.Message); }
        }

        void ShowMe()
        {
            ShowInTaskbar = true; Show(); WindowState = FormWindowState.Normal; Activate(); BringToFront();
        }

        void Uninstall()
        {
            if (MessageBox.Show("Remove G's Avengers from this PC?", "G's Avengers", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
            Installer.Uninstall();
            reallyQuit = true; Close();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (!reallyQuit && e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; Hide(); ShowInTaskbar = false; return; }
            anim.Stop();
            if (host != null) { host.GoLocal(-1); host.Uninstall(); }
            RemoveClipboardFormatListener(Handle);
            tray.Visible = false;
            base.OnFormClosing(e);
        }
    }

    public static class Log
    {
        static readonly object l = new object();
        public static string PathName;
        public static void Write(string s)
        {
            try { lock (l) File.AppendAllText(PathName, DateTime.Now.ToString("HH:mm:ss ") + s + "\r\n"); } catch { }
        }
    }
}
