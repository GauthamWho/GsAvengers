// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 GauthamWho (G’s Avengers)

import AppKit

Defaults.register()

if CommandLine.arguments.contains("--selftest") {
    SelfTest.runAndExit()
}
#if VORSSAINT_DEVELOPMENT
if let flag = CommandLine.arguments.firstIndex(of: "--avengers-snapshot"), flag + 1 < CommandLine.arguments.count {
    let pages = CommandLine.arguments.firstIndex(of: "--pages").flatMap { index in
        index + 1 < CommandLine.arguments.count
            ? CommandLine.arguments[index + 1].split(separator: ",").compactMap { AvengersPage(rawValue: String($0)) }
            : nil
    } ?? [.home]
    AvengersSnapshot.runAndExit(folder: CommandLine.arguments[flag + 1], pages: pages)
}
#endif

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
