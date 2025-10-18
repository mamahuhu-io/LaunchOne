import AppKit
import Carbon
import Carbon.HIToolbox
import Combine
import ApplicationServices
import QuartzCore
import SwiftData
import SwiftUI

extension Notification.Name {
    static let launchpadWindowShown = Notification.Name("LaunchpadWindowShown")
    static let launchpadWindowHidden = Notification.Name(
        "LaunchpadWindowHidden"
    )
    static let languageDidChange = Notification.Name("languageDidChange")
}

class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@main
struct LaunchpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {}

}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate,
    NSGestureRecognizerDelegate
{
    static var shared: AppDelegate?

    private var window: NSWindow?
    private var settingsWindow: NSWindow?
    private let minimumContentSize = NSSize(width: 800, height: 600)
    private let settingsWindowSize = NSSize(width: 720, height: 600)
    private var lastShowAt: Date?
    private var cancellables = Set<AnyCancellable>()
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyEventHandler: EventHandlerRef?

    let appStore = AppStore()
    var modelContainer: ModelContainer?
    private var isTerminating = false
    private var windowIsVisible = false
    private var isAnimatingWindow = false
    private var pendingShow = false
    private var pendingHide = false
    var isUpdatingDockPolicy = false
    var isShowingModalPanel = false
    private var loginStatusTimer: Timer?

    func applicationWillFinishLaunching(_ notification: Notification) {
        Self.shared = self
        appStore.loadLoginItemPreference()
        // Default to accessory; we'll switch to regular only when showing UI
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        appStore.syncGlobalHotKeyRegistration()

        // Determine if launched as login item (silent path)
        let launchedAsLoginItem: Bool = {
            if let event = NSAppleEventManager.shared().currentAppleEvent,
               event.eventID == kAEOpenApplication,
               let flag = event.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem)?.booleanValue,
               flag {
                return true
            }
            return false
        }()

        if launchedAsLoginItem && appStore.startAtLoginSilent {
            // Minimal initialization only; no windows, no activation
            appStore.performInitialScanIfNeeded()
            appStore.startAutoRescan()
            bindAppearancePreference()
            bindSettingsWindow()
            setupLanguageChangeObserver()
            loginStatusTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                self?.appStore.syncLoginItemStatus()
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.applyAppearancePreference(self.appStore.appearancePreference)
            }
            return
        }

        // Interactive path: build UI
        if appStore.showInDock {
            NSApplication.shared.setActivationPolicy(.regular)
        }
        setupWindow()
        setupSettingsWindow()
        appStore.performInitialScanIfNeeded()
        appStore.startAutoRescan()

        bindAppearancePreference()
        bindSettingsWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyAppearancePreference(self.appStore.appearancePreference)
        }

        if appStore.isFullscreenMode { updateWindowMode(isFullscreen: true) }

        setupLanguageChangeObserver()
        DispatchQueue.main.async {
            self.setupCustomMenu()
        }
        loginStatusTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.appStore.syncLoginItemStatus()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Maintain accessory unless we intend to show UI
        if appStore.showInDock {
            NSApplication.shared.setActivationPolicy(.regular)
        }
    }

    private func setupLanguageChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .languageDidChange,
            object: nil
        )
    }

    @objc private func languageDidChange() {
        print("Language switched, recreating menu")
        DispatchQueue.main.async {
            self.setupCustomMenu()
        }
    }

    private func setupCustomMenu() {
        let mainMenu = NSMenu()

        // Application menu (first)
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        // About
        appMenu.addItem(
            withTitle: appStore.localized(.menuAbout),
            action: #selector(openAbout),
            keyEquivalent: ""
        ).target = self

        // Settings
        appMenu.addItem(
            withTitle: appStore.localized(.menuSettings),
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self

        appMenu.addItem(NSMenuItem.separator())

        // Quit
        appMenu.addItem(
            withTitle: appStore.localized(.menuQuit),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        NSApp.mainMenu = mainMenu
    }

    // Custom events
    @objc func openSettings() {
        appStore.settingsInitialSection = .general
        appStore.isSetting = true
    }

    @objc func openAbout() {
        appStore.settingsInitialSection = .about
        appStore.isSetting = true
    }

    // MARK: - Global Hotkey

    func updateGlobalHotKey(configuration: AppStore.HotKeyConfiguration?) {
        unregisterGlobalHotKey()
        guard let configuration else { return }
        registerGlobalHotKey(configuration)
    }

    private func registerGlobalHotKey(
        _ configuration: AppStore.HotKeyConfiguration
    ) {
        ensureHotKeyEventHandler()
        let hotKeyID = EventHotKeyID(signature: fourCharCode("LNXK"), id: 1)
        let status = RegisterEventHotKey(
            configuration.keyCodeUInt32,
            configuration.carbonModifierFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("LaunchOne: Failed to register hotkey (status %d)", status)
        }
    }

    private func unregisterGlobalHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handler = hotKeyEventHandler, hotKeyRef == nil {
            RemoveEventHandler(handler)
            hotKeyEventHandler = nil
        }
    }

    private func ensureHotKeyEventHandler() {
        guard hotKeyEventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyEventCallback,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &hotKeyEventHandler
        )
        if status != noErr {
            NSLog(
                "LaunchOne: Failed to install hotkey handler (status %d)",
                status
            )
        }
    }

    fileprivate func handleHotKeyEvent() {
        DispatchQueue.main.async { [weak self] in
            self?.toggleWindow()
        }
    }

    private func setupWindow() {
        guard let screen = NSScreen.main else { return }
        let rect = calculateContentRect(for: screen)

        window = BorderlessWindow(
            contentRect: rect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window?.delegate = self
        window?.isMovable = false
        window?.level = .floating
        window?.collectionBehavior = [
            .transient, .canJoinAllApplications, .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.hasShadow = true
        window?.contentAspectRatio = NSSize(width: 4, height: 3)
        window?.contentMinSize = minimumContentSize
        window?.minSize =
            window?.frameRect(
                forContentRect: NSRect(origin: .zero, size: minimumContentSize)
            ).size ?? minimumContentSize

        // SwiftData support (pin store to Application Support to avoid data loss after app replacement)
        do {
            let fm = FileManager.default
            let appSupport = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let storeDir = appSupport.appendingPathComponent(
                "LaunchOne",
                isDirectory: true
            )
            if !fm.fileExists(atPath: storeDir.path) {
                try fm.createDirectory(
                    at: storeDir,
                    withIntermediateDirectories: true
                )
            }
            let storeURL = storeDir.appendingPathComponent("Data.store")

            let configuration = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(
                for: TopItemData.self,
                PageEntryData.self,
                configurations: configuration
            )
            modelContainer = container
            appStore.configure(modelContext: container.mainContext)
            window?.contentView = NSHostingView(
                rootView: LaunchpadView(appStore: appStore).modelContainer(
                    container
                )
            )
        } catch {
            // Fallback to default container to maintain functionality
            if let container = try? ModelContainer(
                for: TopItemData.self,
                PageEntryData.self
            ) {
                modelContainer = container
                appStore.configure(modelContext: container.mainContext)
                window?.contentView = NSHostingView(
                    rootView: LaunchpadView(appStore: appStore).modelContainer(
                        container
                    )
                )
            } else {
                window?.contentView = NSHostingView(
                    rootView: LaunchpadView(appStore: appStore)
                )
            }
        }

        applyCornerRadius()
        window?.alphaValue = 0
        window?.contentView?.alphaValue = 0
        windowIsVisible = false

        // Perform the initial fade-in after initialization completes
        showWindow()

        // Background-click-to-close is implemented inside SwiftUI to avoid conflicts with input controls
    }

    private func bindAppearancePreference() {
        appStore.$appearancePreference
            .receive(on: RunLoop.main)
            .sink { [weak self] preference in
                DispatchQueue.main.async {
                    self?.applyAppearancePreference(preference)
                }
            }
            .store(in: &cancellables)
    }

    private func bindSettingsWindow() {
        appStore.$isSetting
            .receive(on: RunLoop.main)
            .sink { [weak self] isSetting in
                DispatchQueue.main.async {
                    if isSetting {
                        self?.showSettingsWindow()
                    } else {
                        self?.hideSettingsWindow()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func applyAppearancePreference(_ preference: AppearancePreference) {
        let appearance = preference.nsAppearance.flatMap {
            NSAppearance(named: $0)
        }
        window?.appearance = appearance
        settingsWindow?.appearance = appearance
        NSApp.appearance = appearance
    }

    private func setupSettingsWindow() {
        guard let screen = NSScreen.main else { return }
        let frame = calculateSettingsWindowRect(for: screen)

        settingsWindow = BorderlessWindow(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        settingsWindow?.delegate = self
        settingsWindow?.isMovable = true
        settingsWindow?.level = .floating
        settingsWindow?.collectionBehavior = [
            .transient, .canJoinAllApplications, .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        settingsWindow?.isOpaque = false
        settingsWindow?.backgroundColor = .clear
        settingsWindow?.hasShadow = true
        settingsWindow?.contentMinSize = settingsWindowSize
        settingsWindow?.minSize = settingsWindowSize

        // Set settings window content
        settingsWindow?.contentView = NSHostingView(
            rootView: SettingsView(appStore: appStore)
        )

        // Apply corner radius
        applySettingsWindowCornerRadius()
        settingsWindow?.alphaValue = 0
        settingsWindow?.contentView?.alphaValue = 0
    }

    private func calculateSettingsWindowRect(for screen: NSScreen) -> NSRect {
        let frame = screen.visibleFrame
        let width = settingsWindowSize.width
        let height = settingsWindowSize.height
        return NSRect(
            x: frame.midX - width / 2,
            y: frame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func applySettingsWindowCornerRadius() {
        guard let contentView = settingsWindow?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 20
        contentView.layer?.masksToBounds = true
    }

    private func showSettingsWindow() {
        guard let settingsWindow = settingsWindow else { return }

        // Center the window
        if let screen = NSScreen.main {
            let rect = calculateSettingsWindowRect(for: screen)
            settingsWindow.setFrame(rect, display: true)
        }

        applySettingsWindowCornerRadius()
        settingsWindow.makeKeyAndOrderFront(nil)
        settingsWindow.orderFrontRegardless()

        // If an initial section is specified, notify SettingsView to update
        if let initialSection = appStore.settingsInitialSection {
            // Notify SettingsView via NotificationCenter to update selectedSection
            NotificationCenter.default.post(
                name: NSNotification.Name("UpdateSelectedSection"),
                object: nil,
                userInfo: ["section": initialSection]
            )
            appStore.settingsInitialSection = nil
        }

        // Fade-in animation
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            settingsWindow.animator().alphaValue = 1
            settingsWindow.contentView?.animator().alphaValue = 1
        })
    }

    private func hideSettingsWindow() {
        guard let settingsWindow = settingsWindow else { return }

        // Fade-out animation
        NSAnimationContext.runAnimationGroup(
            { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                settingsWindow.animator().alphaValue = 0
                settingsWindow.contentView?.animator().alphaValue = 0
            },
            completionHandler: {
                settingsWindow.orderOut(nil)
                settingsWindow.alphaValue = 1
                settingsWindow.contentView?.alphaValue = 1
            }
        )
    }

    func showWindow() {
        pendingShow = true
        pendingHide = false
        startPendingWindowTransition()
    }

    func hideWindow() {
        pendingHide = true
        pendingShow = false
        startPendingWindowTransition()
    }

    func toggleWindow() {
        if window == nil {
            NSApplication.shared.setActivationPolicy(.regular)
            setupWindow()
            setupSettingsWindow()
        }
        if windowIsVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    // MARK: - Quit with fade
    func quitWithFade() {
        guard !isTerminating else {
            NSApp.terminate(nil)
            return
        }
        isTerminating = true
        if let window = window {
            pendingShow = false
            pendingHide = false
            animateWindow(to: 0, resumePending: false) {
                window.orderOut(nil)
                window.alphaValue = 1
                window.contentView?.alphaValue = 1
                NSApp.terminate(nil)
            }
        } else {
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication)
        -> NSApplication.TerminateReply
    {
        guard !isTerminating else { return .terminateNow }
        quitWithFade()
        return .terminateLater
    }

    deinit {
        unregisterGlobalHotKey()
    }

    func updateWindowMode(isFullscreen: Bool) {
        guard let window = window else { return }
        let screen = getCurrentActiveScreen() ?? NSScreen.main!
        
        // Batch update window properties to reduce redraws
        window.setFrame(
            isFullscreen ? screen.frame : calculateContentRect(for: screen),
            display: false  // Don't display first, wait for all properties to be set before displaying
        )
        window.hasShadow = !isFullscreen
        window.contentAspectRatio =
            isFullscreen
            ? NSSize(width: 0, height: 0) : NSSize(width: 4, height: 3)
        applyCornerRadius()
        
        // Finally display uniformly to reduce redraws
        window.display()
    }

    private func applyCornerRadius() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = appStore.isFullscreenMode ? 0 : 30
        contentView.layer?.masksToBounds = true
    }

    private func calculateContentRect(for screen: NSScreen) -> NSRect {
        let frame = screen.visibleFrame
        let width = max(
            frame.width * 0.4,
            minimumContentSize.width,
            minimumContentSize.height * 4 / 3
        )
        let height = width * 3 / 4
        return NSRect(
            x: frame.midX - width / 2,
            y: frame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func getCurrentActiveScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
    }

    // MARK: - Window animation helpers

    private func startPendingWindowTransition() {
        guard !isAnimatingWindow else { return }
        if pendingShow {
            performShowWindow()
        } else if pendingHide {
            performHideWindow()
        }
    }

    private func performShowWindow() {
        pendingShow = false
        guard let window = window else { return }

        if windowIsVisible && !isAnimatingWindow && window.alphaValue >= 0.99 {
            return
        }

        let screen = getCurrentActiveScreen() ?? NSScreen.main!
        let rect =
            appStore.isFullscreenMode
            ? screen.frame : calculateContentRect(for: screen)
        window.setFrame(rect, display: true)
        applyCornerRadius()

        if window.alphaValue <= 0.01 || !windowIsVisible {
            window.alphaValue = 0
            window.contentView?.alphaValue = 0
        }

        window.makeKeyAndOrderFront(nil)
        window.collectionBehavior = [
            .transient, .canJoinAllApplications, .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        window.orderFrontRegardless()

        // Force window to become key and main window for proper focus
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
        window.makeMain()

        lastShowAt = Date()
        windowIsVisible = true
        NotificationCenter.default.post(
            name: .launchpadWindowShown,
            object: nil
        )

        animateWindow(to: 1) {
            self.windowIsVisible = true
            // Ensure focus after animation completes
            DispatchQueue.main.async {
                self.window?.makeKey()
                self.window?.makeMain()
            }
        }
    }

    private func performHideWindow() {
        pendingHide = false
        guard let window = window else { return }

        let finalize: () -> Void = {
            self.windowIsVisible = false
            window.orderOut(nil)
            window.alphaValue = 1
            window.contentView?.alphaValue = 1
            self.appStore.isSetting = false
            if self.appStore.rememberLastPage {
                self.appStore.persistCurrentPageIfNeeded()
            } else {
                self.appStore.currentPage = 0
            }
            self.appStore.searchText = ""
            self.appStore.openFolder = nil
            self.appStore.saveAllOrder()
            NotificationCenter.default.post(
                name: .launchpadWindowHidden,
                object: nil
            )
        }

        if (!windowIsVisible && window.alphaValue <= 0.01) || isTerminating {
            finalize()
            return
        }

        animateWindow(to: 0) {
            finalize()
        }
    }

    private func animateWindow(
        to targetAlpha: CGFloat,
        resumePending: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        guard let window = window else {
            completion?()
            return
        }

        isAnimatingWindow = true
        NSAnimationContext.runAnimationGroup(
            { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = targetAlpha
                window.contentView?.animator().alphaValue = targetAlpha
            },
            completionHandler: {
                window.alphaValue = targetAlpha
                window.contentView?.alphaValue = targetAlpha
                self.isAnimatingWindow = false
                completion?()
                if resumePending {
                    self.startPendingWindowTransition()
                }
            }
        )
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let minSize = minimumContentSize
        let contentSize = sender.contentRect(
            forFrameRect: NSRect(origin: .zero, size: frameSize)
        ).size
        let clamped = NSSize(
            width: max(contentSize.width, minSize.width),
            height: max(contentSize.height, minSize.height)
        )
        return sender.frameRect(
            forContentRect: NSRect(origin: .zero, size: clamped)
        ).size
    }

    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow,
            window == settingsWindow
        {
            // Do not close the settings window when updating Dock policy or showing a modal panel
            guard !isUpdatingDockPolicy && !isShowingModalPanel else { return }
            // Close settings window when it loses key status
            appStore.isSetting = false
        } else {
            autoHideIfNeeded()
        }
    }
    func windowDidResignMain(_ notification: Notification) {
        if let window = notification.object as? NSWindow,
            window == settingsWindow
        {
            // Do not close the settings window when updating Dock policy or showing a modal panel
            guard !isUpdatingDockPolicy && !isShowingModalPanel else { return }
            // Close settings window when it is no longer the main window
            appStore.isSetting = false
        } else {
            autoHideIfNeeded()
        }
    }
    private func autoHideIfNeeded() {
        guard !appStore.isSetting else { return }
        hideWindow()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        // When reopened from the app list, reassert the Dock policy to prevent unintended visibility
        if appStore.showInDock {
            NSApplication.shared.setActivationPolicy(.regular)
        } else {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        if window?.isVisible == true {
            hideWindow()
        } else {
            showWindow()
        }
        return false
    }

    private func isInteractiveView(_ view: NSView?) -> Bool {
        var v = view
        while let cur = v {
            if cur is NSControl || cur is NSTextView || cur is NSScrollView
                || cur is NSVisualEffectView
            {
                return true
            }
            v = cur.superview
        }
        return false
    }

    @objc private func handleBackgroundClick(_ sender: NSClickGestureRecognizer)
    {
        guard appStore.openFolder == nil && !appStore.isFolderNameEditing else {
            return
        }
        guard let view = sender.view else { return }
        let p = sender.location(in: view)
        if let hit = view.hitTest(p), isInteractiveView(hit) { return }
        hideWindow()
    }

    // MARK: - NSGestureRecognizerDelegate
    func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldAttemptToRecognizeWith event: NSEvent
    ) -> Bool {
        guard let contentView = window?.contentView else { return true }
        let point = contentView.convert(event.locationInWindow, from: nil)
        if let hit = contentView.hitTest(point), isInteractiveView(hit) {
            return false
        }
        return true
    }
}

private func hotKeyEventCallback(
    eventHandlerCallRef: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return noErr }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData)
        .takeUnretainedValue()
    delegate.handleHotKeyEvent()
    return noErr
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: UInt32 = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) | (scalar.value & 0xFF)
    }
    return result
}
