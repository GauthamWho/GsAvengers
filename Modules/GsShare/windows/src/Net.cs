// G's Avengers — settings, finding the Mac, and the encrypted link. No WinForms in here (so it can be tested headless).
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Numerics;
using System.Text;
using System.Threading;

namespace GsAvengers
{
    public enum Msg : byte
    {
        Auth = 0x01, PairOK = 0x02, NeedPair = 0x03, Ping = 0x05, Layout = 0x06,
        Enter = 0x10, Leave = 0x11, ReleaseAll = 0x12, TakeBack = 0x13,
        Move = 0x20, Button = 0x21, Wheel = 0x22,
        Key = 0x30,
        ClipText = 0x40, ClipPNG = 0x41
    }

    /// Sides: 0 left, 1 right, 2 top, 3 bottom
    public static class Sides
    {
        public static int Opposite(int s) { return s == 0 ? 1 : s == 1 ? 0 : s == 2 ? 3 : 2; }
        public static string Name(int s) { return s == 0 ? "left" : s == 1 ? "right" : s == 2 ? "top" : "bottom"; }
    }

    /// key=value text file in %APPDATA%\GsAvengers\config.txt
    public class Settings
    {
        public string DeviceId;
        public Dictionary<string, string> Pairings = new Dictionary<string, string>();
        public Dictionary<string, string> PeerNames = new Dictionary<string, string>();
        public Dictionary<string, int> PeerSide = new Dictionary<string, int>(); // where the peer sits relative to this PC
        public bool ShareClipboard = true;
        public string Path;

        public static Settings Load(string dir)
        {
            Directory.CreateDirectory(dir);
            var s = new Settings();
            s.Path = System.IO.Path.Combine(dir, "config.txt");
            if (File.Exists(s.Path))
            {
                foreach (var line in File.ReadAllLines(s.Path))
                {
                    int i = line.IndexOf('=');
                    if (i <= 0) continue;
                    string k = line.Substring(0, i), v = line.Substring(i + 1);
                    if (k == "deviceId") s.DeviceId = v;
                    else if (k == "shareClipboard") s.ShareClipboard = v == "1";
                    else if (k.StartsWith("pair.")) s.Pairings[k.Substring(5)] = v;
                    else if (k.StartsWith("name.")) s.PeerNames[k.Substring(5)] = v;
                    else if (k.StartsWith("side.")) { int n; if (int.TryParse(v, out n)) s.PeerSide[k.Substring(5)] = n; }
                }
            }
            if (string.IsNullOrEmpty(s.DeviceId)) { s.DeviceId = Guid.NewGuid().ToString().ToLowerInvariant(); s.Save(); }
            return s;
        }

        public void Save()
        {
            lock (this)
            {
                var sb = new StringBuilder();
                sb.AppendLine("deviceId=" + DeviceId);
                sb.AppendLine("shareClipboard=" + (ShareClipboard ? "1" : "0"));
                foreach (var kv in Pairings) sb.AppendLine("pair." + kv.Key + "=" + kv.Value);
                foreach (var kv in PeerNames) sb.AppendLine("name." + kv.Key + "=" + kv.Value.Replace("\n", " "));
                foreach (var kv in PeerSide) sb.AppendLine("side." + kv.Key + "=" + kv.Value);
                File.WriteAllText(Path, sb.ToString());
            }
        }
    }

    /// One link to the Mac. Windows always dials the Mac (so no inbound firewall rule is needed on Windows).
    public class Link
    {
        public const int TcpPort = 4810, UdpPort = 4811;
        static readonly byte[] Magic = Encoding.ASCII.GetBytes("EDZS");
        const byte OsMac = 1, OsWin = 2;

        public readonly Settings Cfg;
        public readonly string MyName;

        // events (raised on background threads)
        public Action<string> OnStatus;
        public Action<string, string> OnPairCode;      // code, peer name
        public Action<string, string> OnConnected;     // peer id, peer name
        public Action OnDisconnected;
        public Action<Msg, byte[]> OnMessage;
        public Action<string> OnLog;

        public volatile bool Trusted;
        public string PeerId = "", PeerName = "";

        TcpClient tcp;
        NetworkStream stream;
        SessionKeys keys;
        BlockingCollection<byte[]> outq;
        volatile bool connecting, connected;
        bool myPairOK, peerPairOK;
        DateTime lastHeard;
        readonly object stateLock = new object();
        UdpClient udp;
        public string FixedHost; // for tests: dial this address instead of using discovery

        public Link(Settings cfg, string name) { Cfg = cfg; MyName = name; }

        void Log(string s) { var l = OnLog; if (l != null) l(s); }
        void Status(string s) { var l = OnStatus; if (l != null) l(s); }

        public bool Connected { get { return connected; } }

        public void Start()
        {
            var t = new Thread(DiscoveryLoop); t.IsBackground = true; t.Start();
            var k = new Thread(KeepAliveLoop); k.IsBackground = true; k.Start();
        }

        // ---------- discovery ----------

        byte[] Packet(byte type)
        {
            var ms = new MemoryStream();
            ms.Write(Magic, 0, 4); ms.WriteByte(type); ms.WriteByte(OsWin);
            ms.Write(BitConverter.GetBytes((ushort)TcpPort), 0, 2);
            byte[] id = CryptoUtil.Utf8(Cfg.DeviceId), nm = CryptoUtil.Utf8(MyName.Length > 60 ? MyName.Substring(0, 60) : MyName);
            ms.WriteByte((byte)id.Length); ms.Write(id, 0, id.Length);
            ms.WriteByte((byte)nm.Length); ms.Write(nm, 0, nm.Length);
            return ms.ToArray();
        }

        static List<IPAddress> BroadcastAddresses()
        {
            var r = new List<IPAddress> { IPAddress.Broadcast };
            try
            {
                foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
                {
                    if (ni.OperationalStatus != OperationalStatus.Up || ni.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
                    foreach (var ua in ni.GetIPProperties().UnicastAddresses)
                    {
                        if (ua.Address.AddressFamily != AddressFamily.InterNetwork || ua.IPv4Mask == null) continue;
                        byte[] ip = ua.Address.GetAddressBytes(), m = ua.IPv4Mask.GetAddressBytes(), b = new byte[4];
                        for (int i = 0; i < 4; i++) b[i] = (byte)(ip[i] | ~m[i]);
                        r.Add(new IPAddress(b));
                    }
                }
            }
            catch { }
            return r;
        }

        void DiscoveryLoop()
        {
            while (true)
            {
                try
                {
                    udp = new UdpClient();
                    udp.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
                    udp.Client.Bind(new IPEndPoint(IPAddress.Any, UdpPort));
                    udp.EnableBroadcast = true;
                    udp.Client.ReceiveTimeout = 1000;
                    DateTime last = DateTime.MinValue;
                    while (true)
                    {
                        if (FixedHost != null) { if (!connected && !connecting) BeginConnect(FixedHost, TcpPort); Thread.Sleep(1000); continue; }
                        if ((DateTime.UtcNow - last).TotalSeconds > 2 && !connected)
                        {
                            last = DateTime.UtcNow;
                            byte[] p = Packet(2);
                            foreach (var b in BroadcastAddresses()) { try { udp.Send(p, p.Length, new IPEndPoint(b, UdpPort)); } catch { } }
                        }
                        IPEndPoint from = new IPEndPoint(IPAddress.Any, 0);
                        byte[] d;
                        try { d = udp.Receive(ref from); }
                        catch (SocketException) { continue; }
                        HandleDiscovery(d, from);
                    }
                }
                catch (Exception e)
                {
                    Log("discovery: " + e.Message);
                    try { if (udp != null) udp.Close(); } catch { }
                    Thread.Sleep(3000);
                }
            }
        }

        void HandleDiscovery(byte[] d, IPEndPoint from)
        {
            if (d.Length < 11 || d[0] != 'E' || d[1] != 'D' || d[2] != 'Z' || d[3] != 'S') return;
            byte type = d[4], os = d[5];
            int port = BitConverter.ToUInt16(d, 6);
            int il = d[8];
            if (d.Length < 10 + il) return;
            string id = Encoding.UTF8.GetString(d, 9, il);
            if (id == Cfg.DeviceId || os != OsMac || type == 2) return;
            if (!IsLan(from.Address)) return; // home network only
            if (!connected && !connecting) BeginConnect(from.Address.ToString(), port);
        }

        // ---------- connection ----------

        /// 10/8, 172.16/12, 192.168/16, 169.254/16 or loopback: never dial a computer outside the home network.
        static bool IsLan(IPAddress a)
        {
            if (IPAddress.IsLoopback(a)) return true;
            if (a.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork) return a.IsIPv6LinkLocal;
            byte[] b = a.GetAddressBytes();
            return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168) || (b[0] == 169 && b[1] == 254);
        }

        void BeginConnect(string host, int port)
        {
            lock (stateLock) { if (connecting || connected) return; connecting = true; }
            var t = new Thread(() => ConnectAndRun(host, port)); t.IsBackground = true; t.Start();
        }

        static void ReadExact(Stream s, byte[] buf, int n)
        {
            int off = 0;
            while (off < n) { int r = s.Read(buf, off, n - off); if (r <= 0) throw new IOException("closed"); off += r; }
        }

        void ConnectAndRun(string host, int port)
        {
            TcpClient c = null;
            try
            {
                Status("Connecting to " + host + "…");
                c = new TcpClient();
                var ar = c.BeginConnect(host, port, null, null);
                if (!ar.AsyncWaitHandle.WaitOne(3000)) throw new IOException("timeout");
                c.EndConnect(ar);
                c.NoDelay = true;
                var s = c.GetStream();
                s.ReadTimeout = 8000;

                // hello: u16 len, "EDZS", ver 1, os, idLen, id, nameLen, name, pub(65)
                BigInteger priv = P256.NewPrivate();
                byte[] pub = P256.PublicKey(priv);
                var ms = new MemoryStream();
                ms.Write(Magic, 0, 4); ms.WriteByte(1); ms.WriteByte(OsWin);
                byte[] id = CryptoUtil.Utf8(Cfg.DeviceId), nm = CryptoUtil.Utf8(MyName.Length > 60 ? MyName.Substring(0, 60) : MyName);
                ms.WriteByte((byte)id.Length); ms.Write(id, 0, id.Length);
                ms.WriteByte((byte)nm.Length); ms.Write(nm, 0, nm.Length);
                ms.Write(pub, 0, 65);
                byte[] hello = ms.ToArray();
                s.Write(BitConverter.GetBytes((ushort)hello.Length), 0, 2);
                s.Write(hello, 0, hello.Length);

                byte[] lb = new byte[2]; ReadExact(s, lb, 2);
                int len = BitConverter.ToUInt16(lb, 0);
                byte[] h = new byte[len]; ReadExact(s, h, len);
                if (len < 8 || h[0] != 'E' || h[1] != 'D' || h[2] != 'Z' || h[3] != 'S' || h[4] != 1) throw new IOException("not G's Avengers");
                int il = h[6];
                string peerId = Encoding.UTF8.GetString(h, 7, il);
                int nl = h[7 + il];
                if (len != 8 + il + nl + 65) throw new IOException("bad hello");
                string peerName = Encoding.UTF8.GetString(h, 8 + il, nl);
                byte[] peerPub = new byte[65]; Buffer.BlockCopy(h, 8 + il + nl, peerPub, 0, 65);
                var k = SessionKeys.Create(priv, pub, Cfg.DeviceId, peerPub, peerId);
                if (k == null) throw new IOException("bad key");

                lock (stateLock)
                {
                    tcp = c; stream = s; keys = k; PeerId = peerId; PeerName = peerName;
                    outq = new BlockingCollection<byte[]>(4096);
                    myPairOK = peerPairOK = false; Trusted = false; pairingShown = false;
                    connected = true; connecting = false; lastHeard = DateTime.UtcNow;
                }
                s.ReadTimeout = Timeout.Infinite;
                var sender = new Thread(() => SendLoop(outq, s, k)); sender.IsBackground = true; sender.Start();

                string p64;
                byte[] tag = new byte[0];
                if (Cfg.Pairings.TryGetValue(peerId, out p64)) tag = k.AuthTag(Convert.FromBase64String(p64), Cfg.DeviceId);
                Send(Msg.Auth, tag);
                ReceiveLoop(s, k);
            }
            catch (Exception e) { Log("link: " + e.Message); }
            finally
            {
                bool was;
                lock (stateLock) { was = connected; connected = false; connecting = false; Trusted = false; if (outq != null) outq.CompleteAdding(); }
                try { if (c != null) c.Close(); } catch { }
                if (was) { var d = OnDisconnected; if (d != null) d(); }
                Status("Looking for your Mac…");
            }
        }

        void SendLoop(BlockingCollection<byte[]> q, NetworkStream s, SessionKeys k)
        {
            try
            {
                foreach (var plain in q.GetConsumingEnumerable())
                {
                    byte[] body = k.Seal(plain);
                    byte[] frame = new byte[4 + body.Length];
                    Buffer.BlockCopy(BitConverter.GetBytes((uint)body.Length), 0, frame, 0, 4);
                    Buffer.BlockCopy(body, 0, frame, 4, body.Length);
                    s.Write(frame, 0, frame.Length);
                }
            }
            catch (Exception e) { Log("send: " + e.Message); try { s.Close(); } catch { } }
        }

        void ReceiveLoop(NetworkStream s, SessionKeys k)
        {
            byte[] lb = new byte[4];
            while (true)
            {
                ReadExact(s, lb, 4);
                int len = (int)BitConverter.ToUInt32(lb, 0);
                if (len < 0 || len > (Trusted ? (64 << 20) : 4096)) throw new IOException("frame too big"); // big frames only once paired
                byte[] body = new byte[len]; ReadExact(s, body, len);
                byte[] p = k.Open(body);
                if (p == null || p.Length == 0) throw new IOException("bad frame");
                lastHeard = DateTime.UtcNow;
                Handle((Msg)p[0], Sub(p, 1));
            }
        }

        static byte[] Sub(byte[] p, int off) { byte[] o = new byte[p.Length - off]; Buffer.BlockCopy(p, off, o, 0, o.Length); return o; }

        void Handle(Msg t, byte[] a)
        {
            if (t == Msg.Ping) return;
            if (t == Msg.Auth)
            {
                string p64;
                if (Cfg.Pairings.TryGetValue(PeerId, out p64) && a.Length == 32 &&
                    CryptoUtil.ConstEq(a, keys.AuthTag(Convert.FromBase64String(p64), PeerId)))
                    BecomeTrusted();
                else { Send(Msg.NeedPair, new byte[0]); EnterPairing(); }
                return;
            }
            if (t == Msg.NeedPair)
            {
                // the Mac doesn't know us (any more): pair again. The old pairing is NOT deleted here, since this
                // frame is not authenticated by the pair key; a new pairing the user confirms replaces it.
                if (Trusted) { Trusted = false; var d = OnDisconnected; if (d != null) d(); }
                EnterPairing();
                return;
            }
            if (t == Msg.PairOK) { peerPairOK = true; FinishPairing(); return; }
            if (!Trusted) return;
            var m = OnMessage; if (m != null) m(t, a);
        }

        void EnterPairing()
        {
            if (pairingShown) return;
            pairingShown = true;
            var pc = OnPairCode; if (pc != null) pc(keys.Code, PeerName);
            Status("Pair with " + PeerName + "?");
        }
        bool pairingShown;

        void BecomeTrusted()
        {
            Trusted = true;
            Status("Connected to " + PeerName);
            var c = OnConnected; if (c != null) c(PeerId, PeerName);
        }

        public void ConfirmPair()
        {
            myPairOK = true;
            Send(Msg.PairOK, new byte[0]);
            FinishPairing();
        }

        void FinishPairing()
        {
            if (!myPairOK || !peerPairOK || Trusted) return;
            Cfg.Pairings[PeerId] = Convert.ToBase64String(keys.PairKey);
            Cfg.PeerNames[PeerId] = PeerName;
            Cfg.Save();
            BecomeTrusted();
        }

        public void Send(Msg t, byte[] payload)
        {
            var q = outq;
            if (q == null || q.IsAddingCompleted) return;
            byte[] p = new byte[1 + payload.Length];
            p[0] = (byte)t;
            Buffer.BlockCopy(payload, 0, p, 1, payload.Length);
            try { q.TryAdd(p); } catch (InvalidOperationException) { }
        }

        public void Disconnect()
        {
            try { if (tcp != null) tcp.Close(); } catch { }
        }

        void KeepAliveLoop()
        {
            while (true)
            {
                Thread.Sleep(1000);
                if (!connected) continue;
                Send(Msg.Ping, new byte[0]);
                if ((DateTime.UtcNow - lastHeard).TotalSeconds > 5) { Log("timeout"); Disconnect(); }
            }
        }

        // ---------- message builders ----------
        public static byte[] I16x2(int a, int b)
        {
            short x = (short)Math.Max(short.MinValue, Math.Min(short.MaxValue, a));
            short y = (short)Math.Max(short.MinValue, Math.Min(short.MaxValue, b));
            byte[] o = new byte[4];
            Buffer.BlockCopy(BitConverter.GetBytes(x), 0, o, 0, 2);
            Buffer.BlockCopy(BitConverter.GetBytes(y), 0, o, 2, 2);
            return o;
        }
        public static byte[] EdgeRatio(int edge, float ratio)
        {
            byte[] o = new byte[5]; o[0] = (byte)edge;
            Buffer.BlockCopy(BitConverter.GetBytes(ratio), 0, o, 1, 4);
            return o;
        }
        public static byte[] KeyMsg(int vk, int scan, bool down, bool extended)
        {
            byte[] o = new byte[5];
            Buffer.BlockCopy(BitConverter.GetBytes((ushort)vk), 0, o, 0, 2);
            Buffer.BlockCopy(BitConverter.GetBytes((ushort)scan), 0, o, 2, 2);
            o[4] = (byte)((down ? 1 : 0) | (extended ? 2 : 0));
            return o;
        }
    }
}
