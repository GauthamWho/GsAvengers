// G's Avengers — finding the other computer, the encrypted link, and the guest logic
import AppKit
import CryptoKit
import Foundation
import Network

let kTCPPort: UInt16 = 4810
let kUDPPort: UInt16 = 4811
let kMagic = Data("EDZS".utf8)
let kOSMac: UInt8 = 1, kOSWin: UInt8 = 2

enum Msg: UInt8 {
    case auth = 0x01, pairOK = 0x02, needPair = 0x03, ping = 0x05, layout = 0x06
    case enter = 0x10, leave = 0x11, releaseAll = 0x12, takeBack = 0x13
    case move = 0x20, button = 0x21, wheel = 0x22
    case key = 0x30
    case clipText = 0x40, clipPNG = 0x41
}

// MARK: - Discovery (UDP broadcast on 4811)

final class Discovery {
    private var fd: Int32 = -1
    private let myId: String, myName: String
    /// Broadcast only while no laptop is connected; while connected the
    /// thread just blocks in recvfrom (it still answers probes) and never wakes.
    private let lock = NSLock()
    private var searchingFlag = true
    private var stopped = false
    var searching: Bool {
        get { lock.lock(); defer { lock.unlock() }; return searchingFlag }
        set {
            lock.lock(); let changed = searchingFlag != newValue; searchingFlag = newValue; lock.unlock()
            if changed && newValue { wake() }
        }
    }
    var onPeer: ((String, String, String) -> Void)? // id, name, ip

    init(id: String, name: String) { myId = id; myName = name }

    func packet(type: UInt8) -> Data {
        var d = kMagic; d.append(type); d.append(kOSMac); d.append(le16(kTCPPort))
        let i = Data(myId.utf8), n = Data(myName.utf8.prefix(60))
        d.append(UInt8(i.count)); d.append(i); d.append(UInt8(n.count)); d.append(n)
        return d
    }

    func start() {
        fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(4))
        setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &on, socklen_t(4))
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &on, socklen_t(4))
        var a = sockaddr_in(); a.sin_family = sa_family_t(AF_INET); a.sin_port = kUDPPort.bigEndian; a.sin_addr.s_addr = INADDR_ANY
        _ = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        Thread.detachNewThread { [weak self] in self?.loop() }
    }

    /// Ends the thread: closing the socket returns recvfrom at once.
    func stop() {
        lock.lock(); stopped = true; lock.unlock()
        let s = fd; fd = -1
        if s >= 0 { shutdown(s, SHUT_RDWR); close(s) }
    }

    /// recvfrom may be blocked with no timeout; a tiny packet to ourselves
    /// returns it so the next broadcast goes out now.
    private func wake() {
        var a = sockaddr_in(); a.sin_family = sa_family_t(AF_INET); a.sin_port = kUDPPort.bigEndian
        a.sin_addr.s_addr = inet_addr("127.0.0.1")
        send(Data([0]), to: a)
    }

    private func setReceiveTimeout(seconds: Int) {
        var tv = timeval(tv_sec: seconds, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    }

    private func send(_ d: Data, to addr: sockaddr_in) {
        var a = addr
        _ = d.withUnsafeBytes { b in
            withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(fd, b.baseAddress, d.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        }
    }

    private func broadcastAddrs() -> [in_addr_t] {
        var out: [in_addr_t] = [INADDR_BROADCAST]
        var ifa: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifa) == 0 else { return out }
        var p = ifa
        while let i = p {
            let f = Int32(i.pointee.ifa_flags)
            if let ad = i.pointee.ifa_addr, ad.pointee.sa_family == sa_family_t(AF_INET),
               f & IFF_BROADCAST != 0, f & IFF_UP != 0, f & IFF_LOOPBACK == 0, let b = i.pointee.ifa_dstaddr {
                b.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { out.append($0.pointee.sin_addr.s_addr) }
            }
            p = i.pointee.ifa_next
        }
        freeifaddrs(ifa)
        return out
    }

    private func loop() {
        var last = Date.distantPast
        var buf = [UInt8](repeating: 0, count: 512)
        var timeout = -1
        while true {
            lock.lock(); let done = stopped; let search = searchingFlag; lock.unlock()
            if done || fd < 0 { return }
            // Searching: wake every 2 s to broadcast. Connected: block until a packet comes.
            let wanted = search ? 2 : 0
            if wanted != timeout { setReceiveTimeout(seconds: wanted); timeout = wanted }
            if search && Date().timeIntervalSince(last) >= 2 {
                last = Date()
                for b in broadcastAddrs() {
                    var a = sockaddr_in(); a.sin_family = sa_family_t(AF_INET); a.sin_port = kUDPPort.bigEndian; a.sin_addr.s_addr = b
                    send(packet(type: 1), to: a)
                }
            }
            var from = sockaddr_in(); var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &from) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(fd, &buf, buf.count, 0, $0, &len) } }
            guard n > 10 else { continue }
            let d = Data(buf[0..<n])
            guard d.prefix(4) == kMagic else { continue }
            let type = d.byte(4)
            let il = Int(d.byte(8)); guard n >= 9 + il + 1 else { continue }
            let id = String(decoding: d.subdata(in: 9..<(9 + il)), as: UTF8.self)
            let nl = Int(d.byte(9 + il)); guard n >= 10 + il + nl else { continue }
            let name = String(decoding: d.subdata(in: (10 + il)..<(10 + il + nl)), as: UTF8.self)
            if id == myId { continue }
            guard isLANv4(from.sin_addr.s_addr) else { continue } // home network only
            if type == 2 { send(packet(type: 3), to: from) } // probe -> reply straight back
            let ip = String(cString: inet_ntoa(from.sin_addr))
            onPeer?(id, name, ip)
        }
    }
}

// MARK: - App state shown in the window

final class SharingAppState: ObservableObject {
    @Published var status = "Looking for your Windows laptop…"
    @Published var connected = false
    @Published var peerName = ""
    @Published var peerId = ""
    @Published var pairCode: String? = nil      // shown while waiting for the user to confirm
    @Published var iConfirmed = false
    @Published var active = false               // cursor is on this Mac (controlled from Windows)
    @Published var config = Config.load()
    @Published var trusted = AXIsProcessTrusted()
    @Published var lastPeerSeen = ""
    @Published var paused = false               // "Pause sharing": Windows can't move onto this Mac

    func save() { config.save() }
}

// MARK: - One TCP session with the Windows laptop

final class Session {
    let conn: NWConnection
    let q: DispatchQueue
    weak var server: Server?
    private var buf = Data()
    private let priv = P256.KeyAgreement.PrivateKey()
    var keys: SessionKeys?
    var peerId = "", peerName = ""
    var peerOS: UInt8 = 0
    var trusted = false
    private var gotAuth = false, peerAuthOK = false
    private var myPairOK = false, peerPairOK = false
    var lastHeard = Date()

    init(conn: NWConnection, q: DispatchQueue, server: Server) { self.conn = conn; self.q = q; self.server = server }

    func start() {
        conn.stateUpdateHandler = { [weak self] st in
            switch st {
            case .failed, .cancelled: self?.server?.closed(self)
            default: break
            }
        }
        conn.start(queue: q)
        sendHello()
        receive()
    }

    func close() { conn.cancel() }

    private func sendHello() {
        guard let s = server else { return }
        var b = kMagic; b.append(1); b.append(kOSMac)
        let i = Data(s.myId.utf8), n = Data(s.myName.utf8.prefix(60))
        b.append(UInt8(i.count)); b.append(i); b.append(UInt8(n.count)); b.append(n)
        b.append(priv.publicKey.x963Representation)
        conn.send(content: le16(UInt16(b.count)) + b, completion: .contentProcessed { _ in })
    }

    private func receive() {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, done, err in
            guard let self = self else { return }
            if let d = data { self.buf.append(d); self.process() }
            if done || err != nil { self.server?.closed(self); return }
            self.receive()
        }
    }

    private func process() {
        while true {
            if keys == nil {
                guard buf.count >= 2 else { return }
                let len = Int(buf.u16(0)); guard buf.count >= 2 + len else { return }
                let h = buf.subdata(in: (buf.startIndex + 2)..<(buf.startIndex + 2 + len))
                buf = Data(buf.dropFirst(2 + len))
                guard handleHello(h) else { close(); return }
            } else {
                guard buf.count >= 4 else { return }
                // Before pairing only tiny control frames are expected; big frames (clipboard) only once trusted.
                let len = Int(buf.u32(0)); guard len < (trusted ? 64 << 20 : 4096) else { close(); return }
                guard buf.count >= 4 + len else { return }
                let body = buf.subdata(in: (buf.startIndex + 4)..<(buf.startIndex + 4 + len))
                buf = Data(buf.dropFirst(4 + len))
                guard let plain = keys!.open(body), !plain.isEmpty else { close(); return }
                lastHeard = Date()
                handle(plain)
            }
        }
    }

    private func handleHello(_ h: Data) -> Bool {
        guard let s = server, h.count > 8, h.prefix(4) == kMagic, h.byte(4) == 1 else { return false }
        peerOS = h.byte(5)
        let il = Int(h.byte(6)); guard h.count >= 7 + il + 1 else { return false }
        peerId = String(decoding: h.subdata(in: (h.startIndex + 7)..<(h.startIndex + 7 + il)), as: UTF8.self)
        let nl = Int(h.byte(7 + il)); guard h.count == 8 + il + nl + 65 else { return false }
        peerName = String(decoding: h.subdata(in: (h.startIndex + 8 + il)..<(h.startIndex + 8 + il + nl)), as: UTF8.self)
        let pub = h.subdata(in: (h.startIndex + 8 + il + nl)..<h.endIndex)
        guard peerId != s.myId, let k = SessionKeys(myPriv: priv, myId: s.myId, peerPub: pub, peerId: peerId) else { return false }
        keys = k
        // prove we know the pair key (empty if never paired)
        var tag = Data()
        if let p64 = s.state.config.pairings[peerId], let p = Data(base64Encoded: p64) { tag = k.authTag(pairKey: p, senderId: s.myId) }
        send(.auth, tag)
        return true
    }

    func send(_ t: Msg, _ payload: Data = Data()) {
        guard let k = keys else { return }
        var p = Data([t.rawValue]); p.append(payload)
        let body = k.seal(p)
        conn.send(content: le32(UInt32(body.count)) + body, completion: .contentProcessed { _ in })
    }

    private var pairingShown = false
    func enterPairing() {
        guard !pairingShown, let k = keys else { return }
        pairingShown = true
        server?.needsPairing(self, code: k.code)
    }

    func confirmPair() {
        myPairOK = true
        send(.pairOK)
        finishPairingIfReady()
    }

    private func finishPairingIfReady() {
        guard myPairOK, peerPairOK, let k = keys, let s = server else { return }
        s.storePairing(peerId: peerId, name: peerName, key: k.pairKey)
        trusted = true
        s.becameTrusted(self)
    }

    private func handle(_ p: Data) {
        guard let t = Msg(rawValue: p.byte(0)) else { return }
        let a = p.dropFirst()
        switch t {
        case .ping: return
        case .auth:
            guard let s = server, let k = keys else { return }
            gotAuth = true
            if let p64 = s.state.config.pairings[peerId], let pk = Data(base64Encoded: p64), a.count == 32,
               Crypto.constEq(Data(a), k.authTag(pairKey: pk, senderId: peerId)) {
                trusted = true
                s.becameTrusted(self)
            } else {
                send(.needPair)
                enterPairing()
            }
            return
        case .needPair:
            // Windows doesn't know us (any more): pair again. The old pairing is NOT deleted here, since this
            // frame is not authenticated by the pair key (anyone on the network could send it); a new pairing
            // the user confirms replaces it.
            if let s = server, trusted { trusted = false; s.untrusted(self) }
            enterPairing()
            return
        case .pairOK:
            peerPairOK = true
            finishPairingIfReady()
            return
        default: break
        }
        guard trusted else { return } // nothing else is accepted until paired
        server?.guestHandle(t, Data(a), from: self)
    }
}

// MARK: - Server: listener + discovery + guest behaviour

final class Server {
    let state: SharingAppState
    let q = DispatchQueue(label: "edz.share.net")
    let myId: String, myName: String
    private var listener: NWListener?
    private var discovery: Discovery?
    private(set) var session: Session?
    private var pending: [Session] = []
    lazy var injector: Injector = {
        let i = Injector(config: { [weak self] in self?.cfg ?? Config() })
        let front = FrontApp()
        i.context = { front.context() }
        i.perform = { a in
            DispatchQueue.main.async {
                switch a { case .openFinder: NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory())) }
            }
        }
        i.log = keyLog
        return i
    }()
    let cursor = CursorGuard()
    private let watcher = LocalInputWatcher()
    private var enteredAt = Date.distantPast
    /// `--keylog` (DEBUG builds only, for tests): what we post goes to keys.log. Release builds compile it out,
    /// so typing is never written down.
    #if DEBUG
    let keyLog: ((String) -> Void)? = CommandLine.arguments.contains("--keylog") ? { line in
        let u = Config.dir.appendingPathComponent("keys.log")
        let d = Data("\(String(format: "%.3f", Date().timeIntervalSince1970)) \(line)\n".utf8)
        if let h = try? FileHandle(forWritingTo: u) { h.seekToEndOfFile(); h.write(d); try? h.close() } else { try? d.write(to: u) }
    } : nil
    #else
    let keyLog: ((String) -> Void)? = nil
    #endif
    private var cfg: Config            // copy readable from the net queue
    private var active = false
    private var paused = false
    private var hostSide: Side = .right // where Windows is, relative to this Mac
    let clipboard = Clipboard()

    init(state: SharingAppState) {
        self.state = state
        cfg = state.config
        myId = state.config.deviceId
        myName = Host.current().localizedName ?? "Mac"
    }

    func configChanged() {
        let c = state.config
        q.async { self.cfg = c; if let s = self.session { self.hostSide = c.peerSide[s.peerId] ?? .right } }
    }

    func start() {
        let p = NWParameters.tcp
        p.allowLocalEndpointReuse = true
        if let opt = p.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options { opt.noDelay = true }
        listener = try? NWListener(using: p, on: NWEndpoint.Port(rawValue: kTCPPort)!)
        listener?.newConnectionHandler = { [weak self] c in
            guard let self = self else { return }
            // Home network only, and only a few links waiting to pair at once.
            guard Server.isLocalNetwork(c.endpoint), self.pending.count < 4 else { c.cancel(); return }
            let s = Session(conn: c, q: self.q, server: self)
            self.pending.append(s)
            s.start()
            self.startKeepAlive()
        }
        listener?.start(queue: q)

        discovery = Discovery(id: myId, name: myName)
        discovery?.onPeer = { [weak self] _, name, ip in
            DispatchQueue.main.async { self?.state.lastPeerSeen = "\(name) (\(ip))" }
        }
        discovery?.start()

        clipboard.onLocalChange = { [weak self] item in
            guard let self = self else { return }
            self.q.async {
                guard self.cfg.shareClipboard, let s = self.session, s.trusted else { return }
                switch item {
                case .text(let t): s.send(.clipText, Data(t.utf8))
                case .png(let d): s.send(.clipPNG, d)
                }
            }
        }
        // The take-back tap is NOT installed here: it only exists while Windows
        // has control of this Mac (see .enter), so normal Mac use never passes
        // through it.
        watcher.onLocal = { [weak self] in self?.q.async { self?.takeBack() } }
        if CommandLine.arguments.contains("--test-local") {
            // Test-only: post one UNMARKED mouse move, as the Mac's own trackpad would, so the real tap -> take-back path runs.
            DistributedNotificationCenter.default().addObserver(forName: Notification.Name("com.edz.gsavengers.test.local"), object: nil, queue: .main) { _ in
                let p = Injector.cursor()
                CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: p.x - 2, y: p.y + 2), mouseButton: .left)?.post(tap: .cghidEventTap)
            }
        }

    }

    /// Stops everything: listener, discovery thread, links, keep-alive, the
    /// clipboard watch and the take-back tap. Nothing of sharing stays running.
    func stop() {
        listener?.cancel(); listener = nil
        discovery?.stop(); discovery = nil
        clipboard.stop()
        q.async {
            if self.active { self.giveBackToMac(); self.active = false }
            self.watcher.stop()
            for s in self.pending + (self.session.map { [$0] } ?? []) { s.close() }
            self.pending.removeAll(); self.session = nil
            self.timer?.cancel(); self.timer = nil
        }
        state.connected = false; state.active = false; state.pairCode = nil
    }

    /// keep-alive + timeout (PROTOCOL.md: ping every second), only while a link exists. Called on q.
    private func startKeepAlive() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: q)
        timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let links = self.pending + (self.session.map { [$0] } ?? [])
            if links.isEmpty { self.timer?.cancel(); self.timer = nil; return }
            for s in links {
                s.send(.ping)
                if Date().timeIntervalSince(s.lastHeard) > 5 { s.close(); self.closed(s) }
            }
        }
        timer.resume()
        self.timer = timer
    }
    private var timer: DispatchSourceTimer?

    /// Private, link-local or loopback addresses only: the link never accepts a computer from the internet.
    static func isLocalNetwork(_ e: NWEndpoint) -> Bool {
        guard case .hostPort(let h, _) = e else { return false }
        switch h {
        case .ipv4(let a): return a.isLoopback || isLANv4(a.rawValue.withUnsafeBytes { $0.load(as: in_addr_t.self) })
        case .ipv6(let a):
            if a.isLoopback || a.isLinkLocal { return true }
            if let v4 = a.asIPv4 { return v4.isLoopback || isLANv4(v4.rawValue.withUnsafeBytes { $0.load(as: in_addr_t.self) }) }
            return (a.rawValue.first ?? 0) & 0xFE == 0xFC // unique local fc00::/7
        default: return false
        }
    }

    static func isLoopback(_ e: NWEndpoint) -> Bool {
        guard case .hostPort(let h, _) = e else { return false }
        switch h {
        case .ipv4(let a): return a.isLoopback
        case .ipv6(let a): return a.isLoopback || a.asIPv4?.isLoopback == true
        default: return false
        }
    }

    /// Someone touched the Mac's own trackpad or keyboard while Windows was driving it: the Mac wins at once.
    /// Called on q.
    /// Pause sharing: hand control back now and refuse the cursor until resumed.
    func setPaused(_ on: Bool) {
        q.async {
            self.paused = on
            if on && self.active { self.enteredAt = .distantPast; self.takeBack() }
        }
        state.paused = on
    }

    func takeBack() {
        guard active, Date().timeIntervalSince(enteredAt) > 0.3 else { return }
        active = false
        watcher.stop()
        injector.releaseAll()
        cursor.restore()
        moveOffSharedEdge()
        session?.send(.takeBack)
        keyLog?("takeBack: local Mac input, cursor shown at \(Injector.cursor())")
        DispatchQueue.main.async { self.state.active = false }
    }

    /// The pointer sits where Windows left it, on the shared edge. Bring it a little inside so it's easy to find.
    private func moveOffSharedEdge() {
        let p = Injector.cursor()
        guard let d = Injector.displays().first(where: { $0.insetBy(dx: -1, dy: -1).contains(p) }) else { return }
        var n = p
        let inX = d.width * 0.12, inY = d.height * 0.12
        switch hostSide {
        case .right: if p.x > d.maxX - 4 { n.x = d.maxX - inX }
        case .left: if p.x < d.minX + 4 { n.x = d.minX + inX }
        case .top: if p.y < d.minY + 4 { n.y = d.minY + inY }
        case .bottom: if p.y > d.maxY - 4 { n.y = d.maxY - inY }
        }
        if n != p { CGWarpMouseCursorPosition(n) }
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    /// Control leaves the Mac for any reason: nothing held down, cursor visible, pointer off the edge.
    private func giveBackToMac() {
        watcher.stop()
        injector.releaseAll()
        cursor.restore()
        moveOffSharedEdge()
    }

    // called on q
    func closed(_ s: Session?) {
        guard let s = s else { return }
        s.conn.cancel()
        let wasPairing = pending.contains { $0 === s } && !s.trusted
        pending.removeAll { $0 === s }
        if wasPairing && session == nil {
            DispatchQueue.main.async { if self.state.pairCode == s.keys?.code { self.state.pairCode = nil; self.state.status = "Looking for your Windows laptop…" } }
        }
        if session === s {
            session = nil
            if active { giveBackToMac(); active = false }
            discovery?.searching = true
            DispatchQueue.main.async {
                self.clipboard.stop()
                self.state.connected = false; self.state.active = false; self.state.pairCode = nil
                self.state.status = "Looking for your Windows laptop…"
            }
        }
    }

    func untrusted(_ s: Session) {
        if session === s {
            session = nil
            if active { giveBackToMac(); active = false }
            if !pending.contains(where: { $0 === s }) { pending.append(s) }
            DispatchQueue.main.async { self.state.connected = false; self.state.active = false }
        }
    }

    func needsPairing(_ s: Session, code: String) {
        // Test-only: `--test-autopair` pairs the FakeHost (mono, same Mac, loopback) without a click. Never a real laptop.
        if CommandLine.arguments.contains("--test-autopair"), s.peerName == "FAKE-WINDOWS", Server.isLoopback(s.conn.endpoint) {
            DispatchQueue.main.async { self.state.pairCode = code; self.state.peerName = s.peerName; self.state.peerId = s.peerId; self.confirmPair() }
            return
        }
        DispatchQueue.main.async {
            self.state.pairCode = code; self.state.iConfirmed = false
            self.state.peerName = s.peerName; self.state.peerId = s.peerId
            self.state.status = "New computer wants to pair: \(s.peerName)"
            SharingEngine.shared.onPairingRequest?()
        }
    }

    func confirmPair() {
        let code = state.pairCode
        q.async {
            // the link whose number is on screen (never an old, closed one)
            (self.pending.last(where: { !$0.trusted && $0.keys?.code == code }) ?? self.pending.last(where: { !$0.trusted }))?.confirmPair()
        }
        DispatchQueue.main.async { self.state.iConfirmed = true }
    }

    func storePairing(peerId: String, name: String, key: Data) {
        DispatchQueue.main.async {
            self.state.config.pairings[peerId] = key.base64EncodedString()
            self.state.config.peerNames[peerId] = name
            self.state.save()
            self.configChanged()
        }
    }

    func becameTrusted(_ s: Session) {
        if let old = session, old !== s { old.close() }
        pending.removeAll { $0 === s }
        session = s
        hostSide = cfg.peerSide[s.peerId] ?? .right
        discovery?.searching = false
        // Windows owns the layout on connect and sends it to us; we only send when the user drags here.
        DispatchQueue.main.async {
            self.clipboard.start()
            self.state.connected = true; self.state.pairCode = nil
            self.state.peerName = s.peerName; self.state.peerId = s.peerId
            self.state.status = "Connected to \(s.peerName)"
        }
    }

    /// The user dragged the screens in our window.
    func setLayout(peerSide: Side) {
        q.async {
            self.hostSide = peerSide
            self.session?.send(.layout, Data([UInt8(peerSide.rawValue)]))
        }
    }

    // MARK: guest (cursor on this Mac, driven by Windows)

    private func edgePoint(_ edge: Side, _ ratio: CGFloat) -> CGPoint {
        let ds = Injector.displays()
        // pick the display that is furthest toward that edge
        let d: CGRect
        switch edge {
        case .right: d = ds.max { $0.maxX < $1.maxX } ?? CGDisplayBounds(CGMainDisplayID())
        case .left: d = ds.min { $0.minX < $1.minX } ?? CGDisplayBounds(CGMainDisplayID())
        case .top: d = ds.min { $0.minY < $1.minY } ?? CGDisplayBounds(CGMainDisplayID())
        case .bottom: d = ds.max { $0.maxY < $1.maxY } ?? CGDisplayBounds(CGMainDisplayID())
        }
        let r = min(max(ratio, 0), 1)
        switch edge {
        case .right: return CGPoint(x: d.maxX - 2, y: d.minY + r * (d.height - 1))
        case .left: return CGPoint(x: d.minX + 1, y: d.minY + r * (d.height - 1))
        case .top: return CGPoint(x: d.minX + r * (d.width - 1), y: d.minY + 1)
        case .bottom: return CGPoint(x: d.minX + r * (d.width - 1), y: d.maxY - 2)
        }
    }

    func guestHandle(_ t: Msg, _ a: Data, from s: Session) {
        switch t {
        case .layout:
            guard a.count >= 1, let side = Side(rawValue: Int(a.byte(0))) else { return }
            hostSide = side.opposite // payload = where WE are relative to Windows
            let id = s.peerId
            DispatchQueue.main.async { self.state.config.peerSide[id] = side.opposite; self.state.save(); self.configChanged() }
        case .enter:
            guard a.count >= 5, let edge = Side(rawValue: Int(a.byte(0))) else { return }
            if paused { s.send(.takeBack); return }
            active = true
            enteredAt = Date()
            watcher.start()
            injector.warp(to: edgePoint(edge, CGFloat(a.f32(1))))
            keyLog?("enter at \(Injector.cursor()) accessibility=\(AXIsProcessTrusted())")
            DispatchQueue.main.async { self.state.active = true }
        case .releaseAll:
            injector.releaseAll()
        case .move:
            guard active, a.count >= 4 else { return }
            let sp = cfg.mouseSpeed
            let dx = Double(a.i16(0)) * sp, dy = Double(a.i16(2)) * sp
            moveBy(dx: dx, dy: dy, s: s)
        case .button:
            guard active, a.count >= 2 else { return }
            injector.button(Int(a.byte(0)), down: a.byte(1) != 0)
        case .wheel:
            guard active, a.count >= 4 else { return }
            injector.wheel(dx: Int(a.i16(0)), dy: Int(a.i16(2)))
        case .key:
            guard active, a.count >= 5 else { return }
            injector.key(vk: a.u16(0), extended: a.byte(4) & 2 != 0, down: a.byte(4) & 1 != 0)
        case .clipText:
            guard cfg.shareClipboard else { return }
            let t = String(decoding: a, as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n")
            DispatchQueue.main.async { self.clipboard.set(.text(t)) }
        case .clipPNG:
            guard cfg.shareClipboard else { return }
            DispatchQueue.main.async { self.clipboard.set(.png(a)) }
        default: break
        }
    }

    private var frac = CGPoint.zero
    private func moveBy(dx: Double, dy: Double, s: Session) {
        let cur = Injector.cursor()
        frac.x += CGFloat(dx); frac.y += CGFloat(dy)
        let ix = frac.x.rounded(.towardZero), iy = frac.y.rounded(.towardZero)
        frac.x -= ix; frac.y -= iy
        var n = CGPoint(x: cur.x + ix, y: cur.y + iy)
        let ds = Injector.displays()
        let home = ds.first { $0.contains(cur) } ?? ds.first ?? CGDisplayBounds(CGMainDisplayID())
        if !ds.contains(where: { $0.contains(n) }) {
            // left the screens: did we cross the edge where Windows is?
            var crossed: Side?
            if n.x >= home.maxX { crossed = .right } else if n.x < home.minX { crossed = .left }
            else if n.y >= home.maxY { crossed = .bottom } else if n.y < home.minY { crossed = .top }
            if let c = crossed, c == hostSide {
                let ratio: Float = (c == .left || c == .right) ? Float((cur.y - home.minY) / home.height) : Float((cur.x - home.minX) / home.width)
                active = false
                var p = Data([UInt8(c.rawValue)]); p.append(le32(ratio.bitPattern))
                s.send(.leave, p)
                watcher.stop()
                keyLog?("leave at \(cur)")
                giveBackToMac()
                DispatchQueue.main.async { self.state.active = false }
                return
            }
            n.x = min(max(n.x, home.minX), home.maxX - 1)
            n.y = min(max(n.y, home.minY), home.maxY - 1)
        }
        injector.move(to: n, dx: Int(ix), dy: Int(iy))
    }
}

/// 10/8, 172.16/12, 192.168/16, 169.254/16 (link-local) or 127/8. `addr` is in network byte order.
func isLANv4(_ addr: in_addr_t) -> Bool {
    let a = UInt32(bigEndian: addr)
    let b0 = a >> 24, b1 = (a >> 16) & 0xFF
    return b0 == 10 || b0 == 127 || (b0 == 172 && (16...31).contains(b1)) || (b0 == 192 && b1 == 168) || (b0 == 169 && b1 == 254)
}
