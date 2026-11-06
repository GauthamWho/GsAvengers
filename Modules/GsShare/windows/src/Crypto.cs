// G's Avengers — crypto. Must match mac/Sources/Crypto.swift byte for byte (spec: docs/PROTOCOL.md).
// C# 5 only (built with the csc.exe that ships inside Windows), .NET Framework 4.x, no NuGet.
using System;
using System.Globalization;
using System.Numerics;
using System.Security.Cryptography;
using System.Text;

namespace GsAvengers
{
    /// Plain P-256 ECDH (affine maths with BigInteger). Used once per connection, so speed doesn't matter,
    /// and it avoids CNG key-blob formats. Peer points are checked to be on the curve.
    public static class P256
    {
        static readonly BigInteger P = H("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF");
        static readonly BigInteger A = P - 3;
        static readonly BigInteger B = H("5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B");
        static readonly BigInteger N = H("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551");
        static readonly BigInteger GX = H("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296");
        static readonly BigInteger GY = H("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5");

        static BigInteger H(string hex) { return BigInteger.Parse("0" + hex, NumberStyles.HexNumber); }
        static BigInteger Mod(BigInteger x) { x %= P; return x.Sign < 0 ? x + P : x; }
        static BigInteger Inv(BigInteger x) { return BigInteger.ModPow(Mod(x), P - 2, P); }

        // point: null = infinity
        static BigInteger[] Add(BigInteger[] p, BigInteger[] q)
        {
            if (p == null) return q;
            if (q == null) return p;
            BigInteger l;
            if (p[0] == q[0])
            {
                if (Mod(p[1] + q[1]).IsZero) return null;
                l = Mod((3 * p[0] * p[0] + A) * Inv(2 * p[1]));
            }
            else l = Mod((q[1] - p[1]) * Inv(q[0] - p[0]));
            BigInteger x = Mod(l * l - p[0] - q[0]);
            BigInteger y = Mod(l * (p[0] - x) - p[1]);
            return new BigInteger[] { x, y };
        }

        static BigInteger[] Mul(BigInteger k, BigInteger[] pt)
        {
            BigInteger[] r = null, a = pt;
            while (k > 0)
            {
                if (!k.IsEven) r = Add(r, a);
                a = Add(a, a);
                k >>= 1;
            }
            return r;
        }

        public static byte[] ToBE32(BigInteger v)
        {
            byte[] le = v.ToByteArray(); // little-endian, maybe with a sign byte
            byte[] be = new byte[32];
            for (int i = 0; i < 32 && i < le.Length; i++) be[31 - i] = le[i];
            return be;
        }

        public static BigInteger FromBE(byte[] b, int off, int len)
        {
            byte[] le = new byte[len + 1];
            for (int i = 0; i < len; i++) le[i] = b[off + len - 1 - i];
            return new BigInteger(le);
        }

        public static BigInteger NewPrivate()
        {
            byte[] r = new byte[32];
            using (var rng = new RNGCryptoServiceProvider()) rng.GetBytes(r);
            return FromBE(r, 0, 32) % (N - 1) + 1;
        }

        /// 65-byte X9.63 public key (04 || X || Y)
        public static byte[] PublicKey(BigInteger priv)
        {
            BigInteger[] q = Mul(priv, new BigInteger[] { GX, GY });
            byte[] o = new byte[65];
            o[0] = 4;
            Buffer.BlockCopy(ToBE32(q[0]), 0, o, 1, 32);
            Buffer.BlockCopy(ToBE32(q[1]), 0, o, 33, 32);
            return o;
        }

        /// shared X coordinate (32 bytes), or null if the peer key is invalid
        public static byte[] Shared(BigInteger priv, byte[] peer)
        {
            if (peer == null || peer.Length != 65 || peer[0] != 4) return null;
            BigInteger x = FromBE(peer, 1, 32), y = FromBE(peer, 33, 32);
            if (x >= P || y >= P) return null;
            if (Mod(y * y) != Mod(x * x * x + A * x + B)) return null; // not on the curve
            BigInteger[] s = Mul(priv, new BigInteger[] { x, y });
            if (s == null) return null;
            return ToBE32(s[0]);
        }
    }

    public static class CryptoUtil
    {
        public static byte[] Sha256(byte[] d) { using (var h = SHA256.Create()) return h.ComputeHash(d); }
        public static byte[] Hmac(byte[] key, byte[] d) { using (var h = new HMACSHA256(key)) return h.ComputeHash(d); }
        public static byte[] Cat(params byte[][] parts)
        {
            int n = 0; foreach (var p in parts) n += p.Length;
            byte[] o = new byte[n]; int off = 0;
            foreach (var p in parts) { Buffer.BlockCopy(p, 0, o, off, p.Length); off += p.Length; }
            return o;
        }
        public static byte[] Utf8(string s) { return Encoding.UTF8.GetBytes(s); }
        public static bool ConstEq(byte[] a, byte[] b)
        {
            if (a == null || b == null || a.Length != b.Length) return false;
            int r = 0; for (int i = 0; i < a.Length; i++) r |= a[i] ^ b[i];
            return r == 0;
        }
        public static byte[] Random(int n) { byte[] r = new byte[n]; using (var g = new RNGCryptoServiceProvider()) g.GetBytes(r); return r; }
    }

    public class SessionKeys
    {
        public byte[] Transcript, K0, EncOut, MacOut, EncIn, MacIn, PairKey;
        public string Code;
        ulong seqOut, seqIn;
        readonly Aes aesOut, aesIn;
        readonly object sealLock = new object();

        /// returns null if the peer key is bad
        public static SessionKeys Create(BigInteger myPriv, byte[] myPub, string myId, byte[] peerPub, string peerId)
        {
            byte[] z = P256.Shared(myPriv, peerPub);
            if (z == null) return null;
            return new SessionKeys(z, myPub, myId, peerPub, peerId);
        }

        SessionKeys(byte[] z, byte[] myPub, string myId, byte[] peerPub, string peerId)
        {
            K0 = CryptoUtil.Sha256(z);
            bool iAmA = string.CompareOrdinal(myId, peerId) < 0;
            byte[] pubA = iAmA ? myPub : peerPub, pubB = iAmA ? peerPub : myPub;
            string idA = iAmA ? myId : peerId, idB = iAmA ? peerId : myId;
            Transcript = CryptoUtil.Sha256(CryptoUtil.Cat(pubA, pubB, CryptoUtil.Utf8(idA), CryptoUtil.Utf8(idB)));
            if (iAmA) { EncOut = K("encA"); MacOut = K("macA"); EncIn = K("encB"); MacIn = K("macB"); }
            else { EncOut = K("encB"); MacOut = K("macB"); EncIn = K("encA"); MacIn = K("macA"); }
            byte[] c = K("code");
            uint v = ((uint)c[0] << 24) | ((uint)c[1] << 16) | ((uint)c[2] << 8) | c[3];
            Code = (v % 1000000).ToString("D6");
            PairKey = K("pair");
            aesOut = Aes.Create(); aesOut.KeySize = 256; aesOut.Mode = CipherMode.CBC; aesOut.Padding = PaddingMode.PKCS7; aesOut.Key = EncOut;
            aesIn = Aes.Create(); aesIn.KeySize = 256; aesIn.Mode = CipherMode.CBC; aesIn.Padding = PaddingMode.PKCS7; aesIn.Key = EncIn;
        }

        byte[] K(string label) { return CryptoUtil.Hmac(K0, CryptoUtil.Cat(CryptoUtil.Utf8(label), Transcript)); }

        public byte[] AuthTag(byte[] pairKey, string senderId)
        {
            return CryptoUtil.Hmac(pairKey, CryptoUtil.Cat(CryptoUtil.Utf8("auth"), Transcript, CryptoUtil.Utf8(senderId)));
        }

        static byte[] Le64(ulong v) { return BitConverter.GetBytes(v); } // Windows is little-endian

        /// iv || ct || tag
        public byte[] Seal(byte[] plain)
        {
            lock (sealLock)
            {
                byte[] iv = CryptoUtil.Random(16);
                byte[] ct;
                using (var enc = aesOut.CreateEncryptor(EncOut, iv)) ct = enc.TransformFinalBlock(plain, 0, plain.Length);
                byte[] tag = CryptoUtil.Hmac(MacOut, CryptoUtil.Cat(Le64(seqOut), iv, ct));
                seqOut++;
                return CryptoUtil.Cat(iv, ct, tag);
            }
        }

        public byte[] Open(byte[] body)
        {
            if (body.Length < 64) return null;
            byte[] iv = new byte[16], ct = new byte[body.Length - 48], tag = new byte[32];
            Buffer.BlockCopy(body, 0, iv, 0, 16);
            Buffer.BlockCopy(body, 16, ct, 0, ct.Length);
            Buffer.BlockCopy(body, body.Length - 32, tag, 0, 32);
            if (!CryptoUtil.ConstEq(CryptoUtil.Hmac(MacIn, CryptoUtil.Cat(Le64(seqIn), iv, ct)), tag)) return null;
            seqIn++;
            try { using (var dec = aesIn.CreateDecryptor(EncIn, iv)) return dec.TransformFinalBlock(ct, 0, ct.Length); }
            catch (CryptographicException) { return null; }
        }
    }
}
