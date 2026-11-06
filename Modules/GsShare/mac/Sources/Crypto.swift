// G's Avengers — crypto (must match windows/src/Crypto.cs byte for byte; spec in docs/PROTOCOL.md)
import CommonCrypto
import CryptoKit
import Foundation

enum Crypto {
    static func sha256(_ d: Data) -> Data { Data(SHA256.hash(data: d)) }

    static func hmac(_ key: Data, _ data: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key)))
    }

    static func random(_ n: Int) -> Data {
        var d = Data(count: n)
        _ = d.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, n, $0.baseAddress!) }
        return d
    }

    static func aes(_ op: Int, key: Data, iv: Data, _ input: Data) -> Data? {
        var out = Data(count: input.count + kCCBlockSizeAES128)
        var moved = 0
        let outCap = out.count
        let st = out.withUnsafeMutableBytes { o in
            input.withUnsafeBytes { i in
                key.withUnsafeBytes { k in
                    iv.withUnsafeBytes { v in
                        CCCrypt(CCOperation(op), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                                k.baseAddress, key.count, v.baseAddress, i.baseAddress, input.count,
                                o.baseAddress, outCap, &moved)
                    }
                }
            }
        }
        guard st == kCCSuccess else { return nil }
        out.count = moved
        return out
    }

    static func constEq(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var r: UInt8 = 0
        for i in 0..<a.count { r |= a[a.startIndex + i] ^ b[b.startIndex + i] }
        return r == 0
    }
}

/// Keys for one TCP session, derived from an ephemeral ECDH exchange.
final class SessionKeys {
    let transcript: Data
    let k0: Data
    let encOut, macOut, encIn, macIn: Data
    var seqOut: UInt64 = 0
    var seqIn: UInt64 = 0
    let code: String
    let pairKey: Data

    init?(myPriv: P256.KeyAgreement.PrivateKey, myId: String, peerPub: Data, peerId: String) {
        guard let peerKey = try? P256.KeyAgreement.PublicKey(x963Representation: peerPub),
              let shared = try? myPriv.sharedSecretFromKeyAgreement(with: peerKey) else { return nil }
        let z = shared.withUnsafeBytes { Data($0) }
        let k0 = Crypto.sha256(z); self.k0 = k0
        let myPub = myPriv.publicKey.x963Representation
        let iAmA = myId < peerId
        let (pubA, pubB, idA, idB) = iAmA ? (myPub, peerPub, myId, peerId) : (peerPub, myPub, peerId, myId)
        var t = Data(); t.append(pubA); t.append(pubB); t.append(Data(idA.utf8)); t.append(Data(idB.utf8))
        let tr = Crypto.sha256(t); transcript = tr
        func K(_ label: String) -> Data { Crypto.hmac(k0, Data(label.utf8) + tr) }
        if iAmA { encOut = K("encA"); macOut = K("macA"); encIn = K("encB"); macIn = K("macB") }
        else { encOut = K("encB"); macOut = K("macB"); encIn = K("encA"); macIn = K("macA") }
        let c = K("code")
        let v = (UInt32(c[0]) << 24) | (UInt32(c[1]) << 16) | (UInt32(c[2]) << 8) | UInt32(c[3])
        code = String(format: "%06u", v % 1_000_000)
        pairKey = K("pair")
    }

    func authTag(pairKey p: Data, senderId: String) -> Data {
        Crypto.hmac(p, Data("auth".utf8) + transcript + Data(senderId.utf8))
    }

    /// returns iv || ct || tag
    func seal(_ plain: Data) -> Data {
        let iv = Crypto.random(16)
        let ct = Crypto.aes(kCCEncrypt, key: encOut, iv: iv, plain)!
        var mac = Data(); mac.append(le64(seqOut)); mac.append(iv); mac.append(ct)
        seqOut += 1
        return iv + ct + Crypto.hmac(macOut, mac)
    }

    func open(_ body: Data) -> Data? {
        guard body.count >= 16 + 16 + 32 else { return nil }
        let b = Data(body)
        let iv = b.subdata(in: 0..<16)
        let ct = b.subdata(in: 16..<(b.count - 32))
        let tag = b.subdata(in: (b.count - 32)..<b.count)
        var mac = Data(); mac.append(le64(seqIn)); mac.append(iv); mac.append(ct)
        guard Crypto.constEq(Crypto.hmac(macIn, mac), tag) else { return nil }
        seqIn += 1
        return Crypto.aes(kCCDecrypt, key: encIn, iv: iv, ct)
    }
}

func le64(_ v: UInt64) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
func le32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
func le16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }

extension Data {
    func u16(_ o: Int) -> UInt16 { UInt16(self[startIndex + o]) | (UInt16(self[startIndex + o + 1]) << 8) }
    func i16(_ o: Int) -> Int16 { Int16(bitPattern: u16(o)) }
    func u32(_ o: Int) -> UInt32 {
        UInt32(self[startIndex + o]) | (UInt32(self[startIndex + o + 1]) << 8) |
            (UInt32(self[startIndex + o + 2]) << 16) | (UInt32(self[startIndex + o + 3]) << 24)
    }
    func f32(_ o: Int) -> Float { Float(bitPattern: u32(o)) }
    func byte(_ o: Int) -> UInt8 { self[startIndex + o] }
}
