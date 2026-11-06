# G's Avengers — Sharing

One Windows keyboard and mouse driving the Mac over the home network, with the clipboard shared both ways. Part of [G's Avengers](../../README.md).

- **Mac side** (`Sources/Vorssaint/Sharing`): Swift, compiled into the one G's Avengers app by the root `build.sh`. It starts only when the Sharing switch is on.
- **Windows app** (`windows/`): C# 5, one small exe built by the compiler that ships with Windows (`windows/build.cmd`). Install guide: [WINDOWS-INSTALL.md](WINDOWS-INSTALL.md).
- No IP addresses, no config: the two find each other on the network and pair with a 6-digit number shown on both screens.
- The Windows keyboard works the Windows way on the Mac. One table, `Sources/Vorssaint/Sharing/KeyRules.swift` (Ctrl = ⌘, ⊞ = fn, Home/End, Ctrl+arrows, Alt+Tab, Alt+F4, Finder F2/Delete/Enter, terminals keep Ctrl = ⌃ …); every rule is a switch in the Mac window. Windows translates nothing.
- Touching the Mac's own trackpad or keyboard takes control back at once; the cursor is never left hidden.

## How it works

| Part | Where |
|---|---|
| Finding each other: UDP broadcast on 4811 (Windows probes, Mac replies), private addresses only | `Sources/Vorssaint/Sharing/Net.swift` `Discovery`, `windows/src/Net.cs` |
| Link: Windows dials the Mac on TCP 4810; P-256 key exchange, AES-256-CBC + HMAC-SHA256 per message, sequence numbers | `Crypto.swift`, `Crypto.cs`; spec in [docs/PROTOCOL.md](docs/PROTOCOL.md) |
| Windows captures the mouse/keyboard past the screen edge (low-level hooks) | `windows/src/Host.cs` |
| The Mac turns them into real input, applies the key rules, hands back at its edge | `Sources/Vorssaint/Sharing/Injector.swift`, `Net.swift` |
| Settings | Mac `~/Library/Application Support/GsAvengers/config.json`; Windows `%LOCALAPPDATA%\GsAvengers\config.txt` (+ `log.txt`, connection messages only) |

## Tests

- `./build.sh --test --test-suite=sharing`: the key table, cursor hide/show balance and local-input detection.
- `tools/vector` makes a crypto test vector; `windows/src/SelfTest.cs` checks the Windows maths against it (`GsAvengers.exe --selftest`).
- `windows/test/FakeHost.cs`: the real Windows link code, run with Mono on the Mac as a stand-in PC against the real Mac app. Test-only launch flags of the Mac app: `--test-autopair` (pairs only `FAKE-WINDOWS` on loopback), `--test-local`, and `--keylog` (DEBUG builds only; release builds compile it out).

## Limits (v1)

- Only the Windows keyboard/mouse controls the Mac (not the other way yet).
- Apps on Windows running as administrator ignore the hooks unless G's Avengers also runs as administrator.
- Caps Lock state isn't synced; dragging files across the edge isn't supported.

## Licence

GPL-3.0-or-later, like the rest of G's Avengers. See [LICENSE](LICENSE).
