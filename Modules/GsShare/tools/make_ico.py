"""Packs the code-drawn icon PNGs into windows/icon.ico (PNG-in-ICO, Vista+). Usage: python3 tools/make_ico.py <icon1024.png>"""
import struct, subprocess, sys, tempfile, os
src = sys.argv[1]; sizes = [16, 24, 32, 48, 64, 128, 256]; blobs = []
with tempfile.TemporaryDirectory() as d:
    for s in sizes:
        out = os.path.join(d, f"{s}.png")
        subprocess.run(["sips", "-z", str(s), str(s), src, "--out", out], check=True, capture_output=True)
        blobs.append(open(out, "rb").read())
hdr = struct.pack("<HHH", 0, 1, len(sizes)); off = 6 + 16 * len(sizes); ent = b""
for s, b in zip(sizes, blobs):
    ent += struct.pack("<BBBBHHII", s % 256, s % 256, 0, 0, 1, 32, len(b), off); off += len(b)
open(os.path.join(os.path.dirname(__file__), "..", "windows", "icon.ico"), "wb").write(hdr + ent + b"".join(blobs))
print("windows/icon.ico written")
