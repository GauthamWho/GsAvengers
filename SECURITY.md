# Security policy

## Report a problem privately

Please do not open a public issue for a security problem.

- **[Report a vulnerability privately](https://github.com/GauthamWho/GsAvengers/security/advisories/new)** (GitHub private vulnerability reporting).
- Include what you found, how to reproduce it, the G's Avengers version and your macOS / Windows versions.

You will get a reply as soon as possible. Please allow time for a fix before talking about it in public. Credit is given gladly if you want it.

## What is in scope

- The Mac app and its two helpers (sharing, clipboard).
- The Windows app (`Modules/GsShare/windows`).
- The sharing link: discovery, pairing, encryption ([protocol](Modules/GsShare/docs/PROTOCOL.md)).

## How the sharing link is protected

- Works only on your home network: both sides ignore computers with non-private (internet) addresses. No cloud, no relay, no account.
- New computers pair only after you compare the same 6-digit number on both screens and click **Pair** on both.
- Every message is encrypted and signed: P-256 key exchange per connection, AES-256-CBC + HMAC-SHA256, a counter against replayed messages.
- Before pairing, only pairing messages are accepted; no mouse, keyboard or clipboard data.
- Nothing you type is written to disk or sent anywhere except to your paired computer.

The last review is in [SECURITY-REVIEW.md](SECURITY-REVIEW.md).

## Supported versions

Fixes land on the latest release.
