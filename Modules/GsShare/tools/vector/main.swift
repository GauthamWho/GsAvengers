// Prints a crypto test vector made by the Mac code, for windows/src/SelfTest.cs
import CryptoKit
import Foundation
func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }
func unhex(_ s: String) -> Data { var d = Data(); var i = s.startIndex; while i < s.endIndex { let j = s.index(i, offsetBy: 2); d.append(UInt8(s[i..<j], radix: 16)!); i = j }; return d }
let dA = unhex("c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721")
let dB = unhex("0f56db78ca460b055c500064824bed999a25aaf48ebb519ac201537b85479813")
let a = try! P256.KeyAgreement.PrivateKey(rawRepresentation: dA)
let b = try! P256.KeyAgreement.PrivateKey(rawRepresentation: dB)
let idA = "aaaa-mac", idB = "bbbb-win"
let ka = SessionKeys(myPriv: a, myId: idA, peerPub: b.publicKey.x963Representation, peerId: idB)!
let z = try! a.sharedSecretFromKeyAgreement(with: b.publicKey).withUnsafeBytes { Data($0) }
let frame = ka.seal(Data("hello from mac".utf8))
let tag = ka.authTag(pairKey: ka.pairKey, senderId: idA)
print("dA=\(hex(dA))\ndB=\(hex(dB))\npubA=\(hex(a.publicKey.x963Representation))\npubB=\(hex(b.publicKey.x963Representation))\nz=\(hex(z))\ncode=\(ka.code)\npair=\(hex(ka.pairKey))\nauthA=\(hex(tag))\nframe=\(hex(frame))")
