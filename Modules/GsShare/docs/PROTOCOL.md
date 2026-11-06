# G's Avengers wire protocol v1

All integers little-endian. Mac = guest (cursor arrives here), Windows = host (owns the keyboard/mouse).

## Discovery — UDP 4811
`"EDZS" | type u8 (1 announce, 2 probe, 3 reply) | os u8 (1 mac, 2 win) | tcpPort u16 | idLen u8 | id | nameLen u8 | name`
Windows broadcasts probes every 2 s; the Mac answers each probe straight back (unicast reply to a broadcast passes the
Windows firewall) and announces every 2 s. Windows dials the first Mac it hears.

## Handshake — TCP 4810
Each side sends `len u16 | "EDZS" | ver u8 = 1 | os u8 | idLen u8 | id | nameLen u8 | name | pub[65]` (P-256 X9.63).
- `k0 = SHA256(ECDH x-coordinate)`; A = the side whose id sorts lower (ordinal).
- `T = SHA256(pubA | pubB | idA | idB)`; `K(label) = HMAC-SHA256(k0, label | T)`.
- A sends with `encA`/`macA`, B with `encB`/`macB`. Pairing number = `BE-u32(K("code")[0..4]) % 1000000`, 6 digits.
- Pair key (stored per peer id after both sides click Pair) = `K("pair")`.

## Frames
`len u32 | iv[16] | AES-256-CBC-PKCS7(type u8 | payload) | HMAC-SHA256(mac, seq u64 | iv | ct)`; seq counts per direction.

| type | name | payload |
|---|---|---|
| 01 | AUTH | 32-byte `HMAC(pairKey, "auth" | T | senderId)`, or empty if not paired |
| 02 | PAIR_OK | — (user clicked Pair) |
| 03 | NEED_PAIR | — (your AUTH failed; forget the old pairing) |
| 05 | PING | — every 1 s; 5 s silence = drop |
| 06 | LAYOUT | side u8: where the RECEIVER sits relative to the sender (0 left, 1 right, 2 top, 3 bottom) |
| 10 | ENTER | edge u8 (receiver's edge the cursor appears at), ratio f32 |
| 11 | LEAVE | edge u8 (sender's edge crossed), ratio f32 |
| 12 | RELEASE_ALL | — |
| 13 | TAKE_BACK | — Mac → Windows: the Mac's own trackpad/keyboard was used while Windows was driving it. The Mac has already released all keys, shown its cursor (every hide matched by a show, mouse re-associated) and moved it off the shared edge; Windows stops forwarding and keeps its pointer where it is. |
| 20 | MOVE | dx i16, dy i16 (Windows pixels) |
| 21 | BUTTON | button u8 (0 L, 1 R, 2 M, 3 back, 4 fwd), down u8 |
| 22 | WHEEL | dx i16, dy i16 (120 per notch, dy > 0 = away from you) |
| 30 | KEY | vk u16, scan u16, flags u8 (1 down, 2 extended) |
| 40 | CLIP_TEXT | UTF-8, LF line ends |
| 41 | CLIP_PNG | PNG bytes |

Nothing but AUTH / PAIR_OK / NEED_PAIR / PING is accepted before both sides trust each other.

## Rules on the Mac side
- Every event the Mac injects carries `kCGEventSourceUserData = 0x47534156` ("GSAV"). A listen-only session tap treats any
  other mouse/keyboard event (no auto-repeat) as local input → TAKE_BACK. 0.3 s grace after ENTER.
- On LEAVE, TAKE_BACK and link loss the Mac releases everything, restores the cursor (CursorGuard) and moves it ~12% off the shared edge.
- All key translation happens on the Mac (`mac/Sources/KeyRules.swift`, tests `bash mac/test.sh`). Windows sends raw VKs.

## Rules on the Windows side
- The low-level hooks only send input to the Mac while the link is healthy: connected, trusted, and a frame heard from
  the Mac within the last 3 s (the Mac pings every second). If not, the next mouse or key event brings the pointer home
  and passes through to Windows, so a sleeping, frozen or vanished Mac can never hold Windows input.
- Ctrl+Alt+Esc brings the pointer home directly inside the key hook (the hooks run on the UI thread), never via a posted message.
- LEAVE, TAKE_BACK and link loss reach the UI thread through its SynchronizationContext, never through the main window's
  handle (hiding the window can rebuild that handle and lose posted messages).
