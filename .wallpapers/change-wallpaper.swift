#!/usr/bin/env swift
import AppKit
_ = NSApplication.shared

let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
let home   = FileManager.default.homeDirectoryForCurrentUser.path
let img    = isDark
    ? "\(home)/.wallpapers/japanese-aesthetic-dark.png"
    : "\(home)/.wallpapers/japanese-aesthetic-light.png"
let bg = isDark
    ? NSColor(red: 0.196, green: 0.188, blue: 0.184, alpha: 1)
    : NSColor(red: 0.984, green: 0.945, blue: 0.780, alpha: 1)

let opts: [NSWorkspace.DesktopImageOptionKey: Any] = [
    .imageScaling: NSImageScaling.scaleNone.rawValue,
    .allowClipping: false,
    .fillColor: bg,
]
for screen in NSScreen.screens {
    try? NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: img), for: screen, options: opts)
}
