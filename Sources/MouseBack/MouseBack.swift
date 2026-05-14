import ApplicationServices
import AppKit
import CoreFoundation
import Foundation

@main
struct MouseBack {
    static func main() {
        let application = NSApplication.shared
        let delegate = MouseBackApp()

        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()
    }
}

final class MouseBackApp: NSObject, NSApplicationDelegate {
    private var mouseEventTap: CFMachPort?
    private var keyboardEventTap: CFMachPort?
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var accessibilityMenuItem: NSMenuItem?
    private var inputMonitoringMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        startEventTap()
    }

    private func setupMenuBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "鼠标侧键"

        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: "启动中...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        let accessibilityMenuItem = NSMenuItem(title: "辅助功能: 检查中...", action: nil, keyEquivalent: "")
        accessibilityMenuItem.isEnabled = false
        menu.addItem(accessibilityMenuItem)

        let inputMonitoringMenuItem = NSMenuItem(title: "输入监控: 检查中...", action: nil, keyEquivalent: "")
        inputMonitoringMenuItem.isEnabled = false
        menu.addItem(inputMonitoringMenuItem)

        let mappingMenuItem = NSMenuItem(title: "侧键 3/4 或 Control + 方向键", action: nil, keyEquivalent: "")
        mappingMenuItem.isEnabled = false
        menu.addItem(mappingMenuItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "打开隐私设置", action: #selector(openPrivacySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "重新检查权限", action: #selector(retryPermissions), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "帮助", action: #selector(showHelp), keyEquivalent: "?"))
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu

        self.statusItem = statusItem
        self.statusMenuItem = statusMenuItem
        self.accessibilityMenuItem = accessibilityMenuItem
        self.inputMonitoringMenuItem = inputMonitoringMenuItem
    }

    private func startEventTap() {
        let accessibilityTrusted = requestAccessibilityPermissionIfNeeded()
        accessibilityMenuItem?.title = "辅助功能: \(accessibilityTrusted ? "已授权" : "未授权")"

        let inputMonitoringTrusted = requestInputMonitoringPermissionIfNeeded()
        inputMonitoringMenuItem?.title = "输入监控: \(inputMonitoringTrusted ? "已授权" : "未授权")"

        let mouseStarted = startMouseEventTap()
        let keyboardStarted = startKeyboardEventTap()

        switch (mouseStarted, keyboardStarted) {
        case (true, true):
            statusMenuItem?.title = "运行中"
        case (true, false):
            statusMenuItem?.title = "仅鼠标可用；需要输入监控"
        case (false, true):
            statusMenuItem?.title = "仅键盘可用；需要辅助功能"
        case (false, false):
            statusMenuItem?.title = "需要权限"
            showHelp()
        }
    }

    private func startMouseEventTap() -> Bool {
        guard mouseEventTap == nil else {
            return true
        }

        let eventMask = (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)

        guard let eventTap = makeEventTap(eventMask: eventMask) else {
            return false
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        mouseEventTap = eventTap

        return true
    }

    private func startKeyboardEventTap() -> Bool {
        guard keyboardEventTap == nil else {
            return true
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        guard let eventTap = makeEventTap(eventMask: eventMask) else {
            return false
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        keyboardEventTap = eventTap

        return true
    }

    @discardableResult
    private func requestAccessibilityPermissionIfNeeded() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    private func requestInputMonitoringPermissionIfNeeded() -> Bool {
        if #available(macOS 10.15, *) {
            if CGPreflightListenEventAccess() {
                return true
            }

            return CGRequestListenEventAccess()
        }

        return true
    }

    private func makeEventTap(eventMask: Int) -> CFMachPort? {
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: refcon
        )
    }

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let mouseEventTap {
                CGEvent.tapEnable(tap: mouseEventTap, enable: true)
            }
            if let keyboardEventTap {
                CGEvent.tapEnable(tap: keyboardEventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown || type == .keyUp {
            return handleKeyEvent(type: type, event: event)
        }

        guard type == .otherMouseDown || type == .otherMouseUp else {
            return Unmanaged.passUnretained(event)
        }

        return handleMouseEvent(type: type, event: event)
    }

    private func handleMouseEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)

        guard let keyCode = Self.keyCode(forMouseButton: buttonNumber) else {
            return Unmanaged.passUnretained(event)
        }

        if type == .otherMouseDown {
            postCommandBracket(keyCode: keyCode)
        }

        return nil
    }

    private func handleKeyEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        guard flags.contains(.maskControl) else {
            return Unmanaged.passUnretained(event)
        }

        guard keyCode == KeyCode.leftArrow || keyCode == KeyCode.rightArrow else {
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            let bracketKey = keyCode == KeyCode.leftArrow ? KeyCode.leftBracket : KeyCode.rightBracket
            postCommandBracket(keyCode: bracketKey)
        }

        return nil
    }

    static func keyCode(forMouseButton buttonNumber: Int64) -> CGKeyCode? {
        switch buttonNumber {
        case 3:
            return KeyCode.leftBracket
        case 4:
            return KeyCode.rightBracket
        default:
            return nil
        }
    }

    private func postCommandBracket(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)

        guard
            let commandDown = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.command, keyDown: true),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false),
            let commandUp = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.command, keyDown: false)
        else {
            return
        }

        commandDown.flags = .maskCommand
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        commandUp.flags = []

        commandDown.post(tap: .cghidEventTap)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        commandUp.post(tap: .cghidEventTap)
    }

    @objc private func quit() {
        if let mouseEventTap {
            CGEvent.tapEnable(tap: mouseEventTap, enable: false)
        }
        if let keyboardEventTap {
            CGEvent.tapEnable(tap: keyboardEventTap, enable: false)
        }

        NSApplication.shared.terminate(nil)
    }

    @objc private func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func retryPermissions() {
        startEventTap()
    }

    @objc private func showHelp() {
        let appPath = Bundle.main.bundlePath
        let alert = NSAlert()
        alert.messageText = "鼠标侧键权限说明"
        alert.informativeText = """
        鼠标侧键需要两个 macOS 权限：

        1. 辅助功能
        允许应用拦截鼠标侧键事件。

        2. 输入监控
        允许应用捕获鼠标驱动发出的 Control + 左/右方向键。

        请在两个权限列表里添加并启用这个 App：
        \(appPath)

        修改权限后，请在菜单里选择“重新检查权限”，或重启应用。
        """
        alert.addButton(withTitle: "打开隐私设置")
        alert.addButton(withTitle: "确定")

        if alert.runModal() == .alertFirstButtonReturn {
            openPrivacySettings()
        }
    }
}

enum KeyCode {
    static let command: CGKeyCode = 0x37
    static let leftBracket: CGKeyCode = 0x21
    static let rightBracket: CGKeyCode = 0x1E
    static let leftArrow: CGKeyCode = 0x7B
    static let rightArrow: CGKeyCode = 0x7C
}

private let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let app = Unmanaged<MouseBackApp>.fromOpaque(userInfo).takeUnretainedValue()
    return app.handle(proxy: proxy, type: type, event: event)
}
