// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The playback commands a player's own scripting dictionary declares. Only
/// the installed dictionary's vocabulary is accepted: event codes are data
/// supplied by that dictionary, never inferred from an application's name.
struct MusicAutomationCapabilities: Equatable {
    struct Event: Equatable { let eventClass: UInt32; let eventID: UInt32 }
    var commands: [String: Event] = [:]

    /// Starts playback rather than toggling it, unless the dictionary only
    /// declares the toggle.
    var playCommand: Event? { commands["play"] ?? commands["playpause"] }

    static func load(bundleURL: URL) -> Self? {
        guard bundleURL.isFileURL, let bundle = Bundle(url: bundleURL),
              let name = bundle.object(forInfoDictionaryKey: "OSAScriptingDefinition") as? String,
              !name.isEmpty, name.utf8.count <= 255, !name.contains("/"), !name.contains("\\"),
              let resources = bundle.resourceURL,
              let url = bundle.url(forResource: name.hasSuffix(".sdef") ? String(name.dropLast(5)) : name,
                                   withExtension: "sdef") else { return nil }
        var relationship = FileManager.URLRelationship.other
        guard (try? FileManager.default.getRelationship(&relationship,
            ofDirectoryAt: resources.resolvingSymlinksInPath(), toItemAt: url.resolvingSymlinksInPath())) != nil,
              relationship == .contains, let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maximumBytes + 1) else { return nil }
        return parse(data)
    }

    static let maximumBytes = 256 * 1024

    static func parse(_ data: Data) -> Self? {
        guard data.count <= maximumBytes else { return nil }
        let reader = MusicDictionaryReader()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = reader
        guard parser.parse(), reader.isDictionary, !reader.result.commands.isEmpty else { return nil }
        return reader.result
    }
}

private final class MusicDictionaryReader: NSObject, XMLParserDelegate {
    var result = MusicAutomationCapabilities()
    var isDictionary = false
    private var path: [String] = []
    private var elements = 0
    private var command: (name: String, event: MusicAutomationCapabilities.Event, valid: Bool)?
    private var seenCommands = Set<String>()
    private let names: Set<String> = ["playpause", "play"]

    private func code(_ value: String?) -> UInt32? {
        guard let value, value.utf8.count == 4,
              value.utf8.allSatisfy({ (0x20...0x7E).contains($0) }) else { return nil }
        return value.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        elements += 1
        path.append(element)
        guard path.count <= 24, elements <= 4096, attributes.count <= 32 else { parser.abortParsing(); return }
        if path.count == 1 { isDictionary = element == "dictionary" }
        if element == "command", path == ["dictionary", "suite", "command"],
           let name = attributes["name"], names.contains(name) {
            guard let raw = attributes["code"], raw.utf8.count == 8,
                  let eventClass = code(String(raw.prefix(4))), let eventID = code(String(raw.suffix(4))) else {
                seenCommands.insert(name); result.commands[name] = nil; return
            }
            command = (name, .init(eventClass: eventClass, eventID: eventID), true)
        }
        if command != nil, element == "direct-parameter" || element == "parameter",
           attributes["optional"] != "yes" { command?.valid = false }
    }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
        if element == "command", let command {
            if !seenCommands.insert(command.name).inserted { result.commands[command.name] = nil }
            else if command.valid { result.commands[command.name] = command.event }
            self.command = nil
        }
        path.removeLast()
    }

    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        parser.abortParsing()
    }

    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?,
                systemID: String?) {
        parser.abortParsing()
    }
}
