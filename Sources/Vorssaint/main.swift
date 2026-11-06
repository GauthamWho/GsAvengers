// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

// Select backup mode before cleanup and diagnostic arguments can act. Invalid
// backup commands must leave files, input mappings and recovery journals alone.
if let command = SettingsBackupSupport.command(in: CommandLine.arguments) {
    SettingsBackup.runCommandAndExit(command)
}

SuperKeyMappingGuard.runIfRequestedAndExit()
Defaults.register()
MouseAccelerationGuard.runIfRequestedAndExit()
MouseAccelerationService.recoverPendingAtLaunch()

if CommandLine.arguments.contains("--selftest") {
    SelfTest.runAndExit()
}
#if VORSSAINT_DEVELOPMENT
if let flag = CommandLine.arguments.firstIndex(of: "--avengers-snapshot"), flag + 1 < CommandLine.arguments.count {
    let pages = CommandLine.arguments.firstIndex(of: "--pages").flatMap { index in
        index + 1 < CommandLine.arguments.count
            ? CommandLine.arguments[index + 1].split(separator: ",").compactMap { AvengersPage(rawValue: String($0)) }
            : nil
    } ?? [.home, .sharing]
    AvengersSnapshot.runAndExit(folder: CommandLine.arguments[flag + 1], pages: pages)
}
#endif
if CommandLine.arguments.contains("--sensors") {
    SensorDump.runAndExit()
}
if CommandLine.arguments.contains("--uninstall") {
    Uninstaller.runAndExit()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
