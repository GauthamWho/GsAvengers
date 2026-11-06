// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// The few audio HAL helpers the recorder's system-audio capture shares with
// the removed mixer.

import AppKit
import CoreAudio
import Darwin

/// Names Core Audio listener registrations by number.
///
/// A listener registered with a plain callback gets its client pointer back
/// on a HAL thread, and a callback can still be on its way when its owner
/// goes away. The pointer is a number looked up here, never an address, so a
/// late callback finds nothing rather than freed memory, and the owner is
/// held weakly, so a registration the HAL never gives back keeps nothing
/// alive. A listener block is no way out: handing one back for removal is
/// reported done while it keeps firing (measured 2026-10-07).
enum AudioListenerClients {
    private struct Entry {
        weak var owner: AnyObject?
    }

    private static let lock = NSLock()
    private static var entries: [UInt: Entry] = [:]
    private static var counter: UInt = 0

    /// A client pointer no other registration holds. Never dereferenced.
    static func reserve(for owner: AnyObject) -> UnsafeMutableRawPointer {
        lock.withLock {
            counter &+= 1
            if counter == 0 { counter = 1 }
            entries[counter] = Entry(owner: owner)
            // A counter that never reaches zero always makes a usable value.
            return UnsafeMutableRawPointer(bitPattern: counter).unsafelyUnwrapped
        }
    }

    static func owner(of client: UnsafeMutableRawPointer?) -> AnyObject? {
        guard let client else { return nil }
        return lock.withLock { entries[UInt(bitPattern: client)]?.owner }
    }

    static func forget(_ client: UnsafeMutableRawPointer) {
        lock.withLock { entries[UInt(bitPattern: client)] = nil }
    }
}

enum MixerRoutingSupport {
    static let owningAppSearchDepth = 6

    /// The regular app a helper's audio belongs to. Normally that is the
    /// helper's responsible process, but some browsers detach their helpers
    /// from the responsibility chain, macOS reports each one as responsible
    /// for itself, and the browser vanished from the mixer (issue #256). The BSD
    /// parent chain still leads to the app that spawned the helper, so walk
    /// it and bill the helper to the nearest regular app.
    static func owningRegularAppPid(responsiblePid: pid_t,
                                    isRegularApp: (pid_t) -> Bool,
                                    parentPid: (pid_t) -> pid_t) -> pid_t? {
        guard responsiblePid > 0 else { return nil }
        if isRegularApp(responsiblePid) { return responsiblePid }
        var current = responsiblePid
        for _ in 0..<owningAppSearchDepth {
            current = parentPid(current)
            guard current > 1 else { return nil }
            if isRegularApp(current) { return current }
        }
        return nil
    }

}

enum AppVolumeMixer {
    /// Every process object the audio HAL knows about.
    static func audioProcessObjects() -> [AudioObjectID] {
        objectList(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList)
    }

    /// A property holding a list of objects, empty when it cannot be read.
    /// Only what the HAL actually returned counts, and never a zero ID.
    static func objectList(_ object: AudioObjectID,
                                       _ selector: AudioObjectPropertySelector,
                                       scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(mSelector: selector,
                                                 mScope: scope,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr,
              size >= UInt32(MemoryLayout<AudioObjectID>.size) else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &objects) == noErr else {
            return []
        }
        return objects.prefix(Int(size) / MemoryLayout<AudioObjectID>.size).filter { $0 != 0 }
    }

}
