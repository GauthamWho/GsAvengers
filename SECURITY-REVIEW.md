# Security review — G's Avengers 1.0.0 (2026-11-06)

Five checks before the first push. Fixed items are in the 1.0.0 code.

## 1. Secrets
- Scanned the working tree and all 2,000+ commits of history (gitleaks is not installed; regex scan for AWS/GitHub/Slack/OpenAI/Anthropic/Google keys, private-key and certificate blocks, password/secret/token assignments, and key/cert/profile file types: .p12 .pem .cer .p8 .key .mobileprovision .keychain .pfx .env).
- **Result: no secrets found.** Only false positives (translated "admin password" UI strings). `.gitignore` blocks signing material. Signing uses the local keychain; no identity, team ID or password is in the repo.

## 2. Personal data
- Removed from the published tree and history: home-network IP, laptop name, local user paths, private email, hand-over notes, the Claude prompt for Windows (replaced by a generic [WINDOWS-INSTALL.md](Modules/GsShare/WINDOWS-INSTALL.md)), design-picker files and servers, agent files, dictation-app notes, and screenshots that showed real names. Internal files were moved out of the repo, not deleted.
- **Fixed:** offscreen README screenshots now use sample names ("Alex", "MacBook Air", "WINDOWS-PC") instead of the real user and computer names.
- G's Avengers commits are published as one squashed commit on top of upstream Vorssaint, with a GitHub no-reply email. Upstream Vorssaint history is unchanged; it is already public.

## 3. Code
**Sharing link (Mac `Modules/GsShare/mac/Sources/Net.swift`, Windows `windows/src/Net.cs`)**
- Verified: before both sides trust each other, only AUTH / PAIR_OK / NEED_PAIR / PING are handled. Mouse, key, clipboard and layout frames are dropped (`guard trusted` on the Mac, `if (!Trusted) return` on Windows).
- Verified: encrypt-then-MAC (AES-256-CBC + HMAC-SHA256) with a per-direction sequence number inside the MAC, so replayed, reordered or altered frames fail; constant-time tag compare; fresh P-256 keys per connection, so old traffic cannot be replayed into a new session.
- **Fixed — LAN only:** the Mac accepted TCP connections and discovery packets from any address. Now both sides accept only private, link-local or loopback addresses (10/8, 172.16/12, 192.168/16, 169.254/16, IPv6 link-local/ULA). Windows never dials a non-private address.
- **Fixed — unauthenticated "forget pairing":** a NEED_PAIR frame (not signed by the pair key) made each side delete its stored pairing, so anyone on the network could un-pair your devices. Now it only starts a new pairing; the old key is replaced only when the user confirms a new pairing.
- **Fixed — pre-pairing limits:** frames before pairing are capped at 4 KB (was 64 MB) on both sides, and the Mac keeps at most 4 connections waiting to pair, so a noisy device on the network cannot exhaust memory or flood pairing prompts.
- Note: a device on the same network can still make the Windows app try to pair with it (a prompt the user can ignore) and, while it is connected, delay the connection to the real Mac. Pairing still needs the user's click on both sides.

**No logging of typed keys or screen text**
- **Fixed:** the Mac helper's `--keylog` test flag (writes posted key codes to a file) is now compiled only into DEBUG builds; release builds cannot log keys.
- Windows `log.txt` holds connection and error messages only. The clipboard helper's local diagnostic log holds counts, lengths and app names, never clipboard text.

**Privileged pieces**
- Lid-closed mode installs `/etc/sudoers.d/gsmac-clamshell` with exactly `#<uid> ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 1, /usr/bin/pmset disablesleep 0`: one user, two fixed commands, no wildcards; validated with `visudo -c` and removed on failure. OK.
- The fan-control LaunchDaemon helper is inherited from Vorssaint unchanged.
- **Fixed:** the embedded clipboard helper still had its old self-updater (downloads a zip from GitHub and replaces itself). Inside the signed G's Avengers bundle it now never checks or installs updates on its own.
- Windows app: per-user install (`%LOCALAPPDATA%`, HKCU Run key), no admin rights. `INSTALL.cmd` stops Deskflow if it is running, so the two don't fight over the mouse.

## 4. Supply chain and binaries
- Dependencies: **none from outside**. Mac: Apple SDKs only (AppKit, SwiftUI, CryptoKit, CommonCrypto, Network, ScreenCaptureKit…), Swift Package Manager with no remote packages. Windows: .NET Framework 4 (System.Windows.Forms, System.Drawing, System.Core, System.Numerics), compiled by the `csc.exe` that ships with Windows. Release build tools: Xcode command-line tools, `hdiutil`, Mono `mcs` (for the prebuilt Windows exe).
- Build scripts (`build.sh`, `Modules/*/build.sh`, `build.cmd`, `INSTALL.cmd`) download nothing and run nothing from the internet. The old stand-alone clipboard `install.sh` (curl | bash style) and release script were removed from the repo.
- Committed binaries: images only (icons, README pictures, UI assets). Removed the upstream demo GIF (29 MB), showcase video and README assets. No exe, dll, dylib, zip or dmg is committed.
- Release assets are built fresh from this commit: `./build.sh` for the Mac, `mcs` for the Windows exe.
- GitHub Actions: CI is manual-only (macOS runners are costly on a private repo); actions are pinned to commit SHAs. The upstream release workflow (signing secrets) was removed.

## 5. GitHub repository
- Created **private**. Issues and Discussions on; wiki off; 10 topics.
- **On:** Dependabot alerts and Dependabot security updates.
- **Not available on a free private repo** (GitHub answered "not available" / "upgrade to Pro or make public"): secret scanning, push protection, private vulnerability reporting, branch protection and rulesets. All are free once the repo is public. After making it public, run:

```sh
R=GauthamWho/GsAvengers
gh api -X PATCH repos/$R -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
gh api -X PUT repos/$R/private-vulnerability-reporting
gh api -X POST repos/$R/rulesets --input - <<'JSON'
{"name":"Protect main","target":"branch","enforcement":"active",
 "conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},
 "rules":[{"type":"deletion"},{"type":"non_fast_forward"}]}
JSON
```
