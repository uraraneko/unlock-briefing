#if canImport(UnlockBriefingCore)
import UnlockBriefingCore
#endif
import AppKit
import Darwin

let app = NSApplication.shared
AppMenu.install(into: app)
let delegate = AppDelegate()
app.delegate = delegate
fputs("UnlockBriefing main entered\n", stderr)
fflush(stderr)
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
