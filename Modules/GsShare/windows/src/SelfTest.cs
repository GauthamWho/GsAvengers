// G's Avengers — checks that this PC's crypto matches the Mac's exactly (vector made by tools/vector on the Mac).
// Run: GsAvengers.exe --selftest   (prints PASS/FAIL to selftest.txt next to log.txt and to the console)
using System;
using System.IO;
using System.Text;

namespace GsAvengers
{
    public static class SelfTest
    {
        static byte[] X(string h) { byte[] b = new byte[h.Length / 2]; for (int i = 0; i < b.Length; i++) b[i] = Convert.ToByte(h.Substring(i * 2, 2), 16); return b; }
        static string Hex(byte[] b) { var sb = new StringBuilder(); foreach (var x in b) sb.Append(x.ToString("x2")); return sb.ToString(); }

        public static bool Run()
        {
            var o = new StringBuilder();
            bool ok = true;
            Action<string, bool> check = (name, pass) => { o.AppendLine((pass ? "PASS " : "FAIL ") + name); if (!pass) ok = false; };
            try
            {
                var dA = P256.FromBE(X("c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721"), 0, 32);
                var dB = P256.FromBE(X("0f56db78ca460b055c500064824bed999a25aaf48ebb519ac201537b85479813"), 0, 32);
                byte[] pubA = P256.PublicKey(dA), pubB = P256.PublicKey(dB);
                check("public key A", Hex(pubA) == "0460fed4ba255a9d31c961eb74c6356d68c049b8923b61fa6ce669622e60f29fb67903fe1008b8bc99a41ae9e95628bc64f2f1b20c2d7e9f5177a3c294d4462299");
                check("public key B", Hex(pubB) == "04e266ddfdc12668db30d4ca3e8f7749432c416044f2d2b8c10bf3d4012aeffa8abfa86404a2e9ffe67d47c587ef7a97a7f456b863b4d02cfc6928973ab5b1cb39");
                check("shared secret", Hex(P256.Shared(dB, pubA)) == "90223373f75e989ab8965d8cc88f01ceb4c622875861771da7bf1a0faccae374");
                var k = SessionKeys.Create(dB, pubB, "bbbb-win", pubA, "aaaa-mac");
                check("pairing code", k.Code == "977947");
                check("pair key", Hex(k.PairKey) == "2a843b2aacee75720232f0c46e4b40fe54ca36e5e76d501a122aec13960e3ff9");
                check("auth tag", Hex(k.AuthTag(k.PairKey, "aaaa-mac")) == "8ae2f82e0753ff7939bb2deb359f8a9c04f79ef812a30f7daf3fd9c126b2f78b");
                byte[] plain = k.Open(X("d60196fd2dd2b5634b6cb85ced694d9b1d2c1db718f16fcd031e5c4df459e296fade03034c5a88b1ba8bd429de545cc2400db48cbc1d85cfca40459cf4413434"));
                check("decrypt Mac frame", plain != null && Encoding.UTF8.GetString(plain) == "hello from mac");
                byte[] bad = new byte[33]; bad[0] = 4;
                check("rejects bad key", P256.Shared(dB, bad) == null);
            }
            catch (Exception e) { o.AppendLine("FAIL exception " + e); ok = false; }
            o.AppendLine(ok ? "ALL PASS" : "SOME FAILED");
            Console.Write(o.ToString());
            try { File.WriteAllText(Path.Combine(Installer.Dir, "selftest.txt"), o.ToString()); } catch { }
            return ok;
        }
    }
}
