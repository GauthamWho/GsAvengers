// G's Avengers — unit tests for the key translation table and the cursor/local-input rules.
// Run: bash mac/test.sh
import Foundation

var failures = 0, passes = 0
func check(_ name: String, _ got: KeyResult, _ want: KeyResult, file: String = #file, line: Int = #line) {
    if got == want { passes += 1 } else { failures += 1; print("FAIL \(name) (line \(line))\n  got  \(got)\n  want \(want)") }
}
func expect(_ name: String, _ ok: Bool, line: Int = #line) {
    if ok { passes += 1 } else { failures += 1; print("FAIL \(name) (line \(line))") }
}
func chord(_ mods: Set<MacMod>, _ key: UInt16, latch: Latch? = nil) -> KeyResult { .chord(KeyChord(mods: mods, key: key), latch: latch) }
func mac(_ c: Character) -> UInt16 { KeyMap.table[KeyRules.vk(c)]! }

let R = KeyRules.self
let opts = KeyOptions()
let app = KeyContext(app: "com.apple.TextEdit")
let finder = KeyContext(app: KeyContext.finder)
let finderTyping = KeyContext(app: KeyContext.finder, editingText: true)
let term = KeyContext(app: "com.apple.Terminal")
func t(_ vk: UInt16, _ held: Set<HostMod> = [], _ ctx: KeyContext = app, _ o: KeyOptions = opts, latch: Latch? = nil, custom: [Remap] = []) -> KeyResult {
    R.translate(vk: vk, held: held, latch: latch, ctx: ctx, opts: o, custom: custom)
}

// Ctrl works as ⌘
for c in "CVXZASFNOPTWRL" { check("Ctrl+\(c)", t(R.vk(c), [.ctrl]), chord([.command], mac(c))) }
check("Ctrl+Shift+T", t(R.vk("T"), [.ctrl, .shift]), chord([.command, .shift], mac("T")))
check("Ctrl+Y redo", t(R.vk("Y"), [.ctrl]), chord([.command, .shift], R.mZ))
check("plain letter", t(R.vk("A")), chord([], mac("A")))
check("Shift+letter", t(R.vk("A"), [.shift]), chord([.shift], mac("A")))

// ⊞ works as fn
check("⊞+Space = fn Space (dictation)", t(R.vkSpace, [.win]), chord([.fn], R.mSpace))
check("⊞+V = fn V (G's Clipboard)", t(R.vk("V"), [.win]), chord([.fn], mac("V")))
check("⊞+E = fn E (emoji) by default", t(R.vk("E"), [.win]), chord([.fn], mac("E")))
check("⊞+E opens Finder when switched on", t(R.vk("E"), [.win], app, KeyOptions(overrides: ["wine": true])), .action(.openFinder))
check("⊞+. = fn E", t(R.vkPeriod, [.win]), chord([.fn], R.mE))
check("Ctrl+Space = fn Space", t(R.vkSpace, [.ctrl]), chord([.fn], R.mSpace))
expect("⊞ alone is fn", R.baseMods(held: [.win], latch: nil, ctx: app, opts: opts) == [.fn])
expect("Alt alone is ⌥", R.baseMods(held: [.alt], latch: nil, ctx: app, opts: opts) == [.option])
expect("Ctrl alone is ⌘", R.baseMods(held: [.ctrl], latch: nil, ctx: app, opts: opts) == [.command])
let plain = KeyOptions(overrides: ["ctrl.cmd": false, "win.fn": false])
expect("swaps off: Ctrl is ⌃, ⊞ is ⌘", R.baseMods(held: [.ctrl, .win], latch: nil, ctx: app, opts: plain) == [.control, .command])
check("swaps off: Ctrl+C is ⌃C", t(R.vk("C"), [.ctrl], app, plain), chord([.control], mac("C")))

// Text navigation
check("Home", t(R.vkHome), chord([.command], R.mLeft))
check("End", t(R.vkEnd), chord([.command], R.mRight))
check("Shift+Home selects", t(R.vkHome, [.shift]), chord([.command, .shift], R.mLeft))
check("Shift+End selects", t(R.vkEnd, [.shift]), chord([.command, .shift], R.mRight))
check("Ctrl+Home", t(R.vkHome, [.ctrl]), chord([.command], R.mUp))
check("Ctrl+Shift+End", t(R.vkEnd, [.ctrl, .shift]), chord([.command, .shift], R.mDown))
check("Ctrl+←", t(R.vkLeft, [.ctrl]), chord([.option], R.mLeft))
check("Ctrl+→", t(R.vkRight, [.ctrl]), chord([.option], R.mRight))
check("Ctrl+Shift+← selects word", t(R.vkLeft, [.ctrl, .shift]), chord([.option, .shift], R.mLeft))
check("Ctrl+Backspace", t(R.vkBack, [.ctrl]), chord([.option], R.mDelete))
check("Ctrl+Delete", t(R.vkDelete, [.ctrl]), chord([.option], R.mFwdDelete))
check("plain ←", t(R.vkLeft), chord([], R.mLeft))
check("Delete = forward delete", t(R.vkDelete), chord([], R.mFwdDelete))
check("Ctrl+Tab = ⌃Tab", t(R.vkTab, [.ctrl]), chord([.control], R.mTab))
check("Ctrl+Shift+Tab", t(R.vkTab, [.ctrl, .shift]), chord([.control, .shift], R.mTab))
check("Ctrl+Alt+← is not a word jump", t(R.vkLeft, [.ctrl, .alt]), chord([.command, .option], R.mLeft))

// Windows and apps
let altLatch = Latch(host: .alt, mac: .command)
check("Alt+Tab = ⌘Tab, Alt keeps ⌘", t(R.vkTab, [.alt]), chord([.command], R.mTab, latch: altLatch))
check("Alt+Shift+Tab", t(R.vkTab, [.alt, .shift]), chord([.command, .shift], R.mTab, latch: altLatch))
check("Alt+Tab+Tab (latched)", t(R.vkTab, [.alt], latch: altLatch), chord([.command], R.mTab, latch: altLatch))
check("Alt+Esc in the switcher = ⌘Esc", t(R.vkEsc, [.alt], latch: altLatch), chord([.command], R.mEsc))
expect("Alt held after Tab stays ⌘", R.baseMods(held: [.alt], latch: altLatch, ctx: app, opts: opts) == [.command])
check("Alt+F4 = ⌘Q", t(R.vkF4, [.alt]), chord([.command], R.mQ))
check("Ctrl+F4 = ⌘W", t(R.vkF4, [.ctrl]), chord([.command], R.mW))
check("Ctrl+W = ⌘W", t(R.vk("W"), [.ctrl]), chord([.command], R.mW))
check("Ctrl+Shift+Esc = Force Quit", t(R.vkEsc, [.ctrl, .shift]), chord([.command, .option], R.mEsc))
check("PrintScreen = ⌘⌃⇧4", t(R.vkPrint), chord([.command, .control, .shift], R.m4))
check("⊞+L = lock", t(R.vk("L"), [.win]), chord([.control, .command], R.mQ))
check("⊞+D = show desktop", t(R.vk("D"), [.win]), chord([], R.mF11))
check("⊞+Tab = Mission Control", t(R.vkTab, [.win]), chord([.control], R.mUp))

// Finder
check("Finder F2 = rename", t(R.vkF2, [], finder), chord([], R.mReturn))
check("Finder Delete = Trash", t(R.vkDelete, [], finder), chord([.command], R.mDelete))
check("Finder Enter = open", t(R.vkEnter, [], finder), chord([.command], R.mDown))
check("Finder Backspace = back", t(R.vkBack, [], finder), chord([.command], R.mLeftBracket))
check("Finder renaming: Enter is Return", t(R.vkEnter, [], finderTyping), chord([], R.mReturn))
check("Finder renaming: Delete is forward delete", t(R.vkDelete, [], finderTyping), chord([], R.mFwdDelete))
check("Finder renaming: Home is line start", t(R.vkHome, [], finderTyping), chord([.command], R.mLeft))
check("F2 outside Finder stays F2", t(R.vkF2), chord([], 0x78))
check("Enter outside Finder", t(R.vkEnter), chord([], R.mReturn))
check("Finder: Home is not ⌘←", t(R.vkHome, [], finder), chord([], 0x73))

// Terminals
check("Terminal Ctrl+C = ⌃C (stop)", t(R.vk("C"), [.ctrl], term), chord([.control], mac("C")))
check("Terminal Ctrl+R = ⌃R", t(R.vk("R"), [.ctrl], term), chord([.control], mac("R")))
check("Terminal Ctrl+Shift+C = copy", t(R.vk("C"), [.ctrl, .shift], term), chord([.command], R.mC))
check("Terminal Ctrl+V = paste", t(R.vk("V"), [.ctrl], term), chord([.command], R.mV))
check("Terminal Ctrl+Shift+V = paste", t(R.vk("V"), [.ctrl, .shift], term), chord([.command], R.mV))
check("Terminal Home = ⌃A", t(R.vkHome, [], term), chord([.control], R.mA))
check("Terminal End = ⌃E", t(R.vkEnd, [], term), chord([.control], R.mE))
check("Terminal Ctrl+Backspace = ⌃W", t(R.vkBack, [.ctrl], term), chord([.control], R.mW))
check("Terminal Ctrl+← = ⌥←", t(R.vkLeft, [.ctrl], term), chord([.option], R.mLeft))
check("Terminal rules off: Ctrl+C = ⌘C", t(R.vk("C"), [.ctrl], term, KeyOptions(overrides: ["term.ctrl": false])), chord([.command], mac("C")))

// Switches and the owner's own swaps
check("redo off: Ctrl+Y = ⌘Y", t(R.vk("Y"), [.ctrl], app, KeyOptions(overrides: ["redo": false])), chord([.command], mac("Y")))
check("line off: Home = Home", t(R.vkHome, [], app, KeyOptions(overrides: ["line": false])), chord([], 0x73))
let mine = Remap(fromMods: ["ctrl"], fromKey: R.vk("Y"), toMods: ["command"], toKey: mac("Y"))
check("own swap beats the table", t(R.vk("Y"), [.ctrl], custom: [mine]), chord([.command], mac("Y")))
check("unknown key is dropped", t(0xFF), .drop)
expect("every rule points at a real switch", R.rules.allSatisfy { R.toggle($0.toggle) != nil })
expect("switch ids are unique", Set(R.toggles.map(\.id)).count == R.toggles.count)

// Settings from v1 drop the old Ctrl+Space custom swap (now a built-in switch)
let v1 = #"{"deviceId":"x","ctrlIsCommand":false,"remaps":[{"id":"6D2F3E9C-1111-2222-3333-444455556666","enabled":true,"fromMods":["ctrl"],"fromKey":32,"toMods":["fn"],"toKey":49}]}"#
let c1 = try! JSONDecoder().decode(Config.self, from: Data(v1.utf8))
expect("v1 settings migrate", c1.remaps.isEmpty && c1.keyRules.isEmpty && c1.deviceId == "x")

// Cursor: every hide has a matching show; restore re-attaches the mouse
var shown = 0, hiddenCalls = 0, associated = 0
let g = CursorGuard(hide: { hiddenCalls += 1 }, show: { shown += 1 }, associate: { associated += 1 })
g.show()
expect("show without hide does nothing", shown == 0)
g.hide(); g.hide(); g.show()
expect("hide/show counted", g.hidden == 1 && shown == 1)
g.restore()
expect("restore balances every hide", g.hidden == 0 && shown == 2 && hiddenCalls == 2 && associated == 1)
g.restore()
expect("restore twice is safe", shown == 2 && associated == 2)

// Local input: our own injected events never count as the Mac's trackpad/keyboard
expect("injected move is not local", !LocalInputWatcher.isLocal(type: .mouseMoved, userData: Injector.marker, autorepeat: false))
expect("trackpad move is local", LocalInputWatcher.isLocal(type: .mouseMoved, userData: 0, autorepeat: false))
expect("built-in key is local", LocalInputWatcher.isLocal(type: .keyDown, userData: 0, autorepeat: false))
expect("system auto-repeat is not local", !LocalInputWatcher.isLocal(type: .keyDown, userData: 0, autorepeat: true))

print(failures == 0 ? "ALL PASS (\(passes) checks)" : "\(failures) FAILED, \(passes) passed")
exit(failures == 0 ? 0 : 1)
