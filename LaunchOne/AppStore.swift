import AppKit
import Carbon
import Carbon.HIToolbox
import Combine
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import UserNotifications

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var nsAppearance: NSAppearance.Name? {
        switch self {
        case .system: return nil
        case .light: return .aqua
        case .dark: return .darkAqua
        }
    }

    var localizationKey: LocalizationKey {
        switch self {
        case .system: return .appearanceModeFollowSystem
        case .light: return .appearanceModeLight
        case .dark: return .appearanceModeDark
        }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: URL
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
    }
}

private struct SemanticVersion: Comparable, Equatable {
    private let components: [Int]

    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let withoutPrefix =
            lower.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        let sanitized =
            withoutPrefix.split(
                separator: "-",
                maxSplits: 1,
                omittingEmptySubsequences: true
            ).first ?? withoutPrefix[...]
        let parts = sanitized.split(separator: ".").map { Int($0) ?? 0 }
        guard !parts.isEmpty else { return nil }
        components = parts
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }
}

final class AppStore: ObservableObject {
    enum UpdateState: Equatable {
        case idle
        case checking
        case upToDate(latest: String)
        case updateAvailable(UpdateRelease)
        case failed(String)
    }

    struct UpdateRelease: Equatable {
        let version: String
        let url: URL
        let notes: String?
    }

    enum BackgroundStyle: String, CaseIterable, Identifiable {
        case blur
        case glass

        var id: String { rawValue }

        var localizationKey: LocalizationKey {
            switch self {
            case .blur: return .backgroundStyleOptionBlur
            case .glass: return .backgroundStyleOptionGlass
            }
        }
    }

    enum IconLabelFontWeightOption: String, CaseIterable, Identifiable {
        case light
        case regular
        case medium
        case semibold
        case bold

        var id: String { rawValue }

        var fontWeight: Font.Weight {
            switch self {
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }

        var displayName: String {
            switch self {
            case .light: return "Light"
            case .regular: return "Regular"
            case .medium: return "Medium"
            case .semibold: return "Semibold"
            case .bold: return "Bold"
            }
        }
    }

    private static let customTitlesKey = "customAppTitles"
    private static let hiddenAppsKey = "hiddenAppBundlePaths"
    private static let gridColumnsKey = "gridColumnsPerPage"
    private static let gridRowsKey = "gridRowsPerPage"
    private static let columnSpacingKey = "gridColumnSpacing"
    private static let rowSpacingKey = "gridRowSpacing"
    private static let iconLabelFontWeightKey = "iconLabelFontWeight"
    private static let showQuickRefreshButtonKey = "showQuickRefreshButton"
    private static let rememberPageKey = "rememberLastPage"
    private static let rememberedPageIndexKey = "rememberedPageIndex"
    private static let globalHotKeyKey = "globalHotKeyConfiguration"
    private static let hoverMagnificationKey = "enableHoverMagnification"
    private static let hoverMagnificationScaleKey = "hoverMagnificationScale"
    private static let activePressEffectKey = "enableActivePressEffect"
    private static let activePressScaleKey = "activePressScale"
    private static let backgroundStyleKey = "launchpadBackgroundStyle"
    private static let showInDockKey = "showInDock"

    private static func loadHiddenApps() -> Set<String> {
        if let array = UserDefaults.standard.array(forKey: hiddenAppsKey)
            as? [String]
        {
            return Set(array)
        }
        return []
    }

    private static func loadBackgroundStyle() -> BackgroundStyle {
        if let raw = UserDefaults.standard.string(forKey: backgroundStyleKey),
            let style = BackgroundStyle(rawValue: raw)
        {
            return style
        }
        return .glass
    }

    private static let minColumnsPerPage = 4
    private static let maxColumnsPerPage = 10
    private static let minRowsPerPage = 3
    private static let maxRowsPerPage = 8
    private static let minColumnSpacing: Double = 8
    private static let maxColumnSpacing: Double = 50
    private static let minRowSpacing: Double = 6
    private static let maxRowSpacing: Double = 40
    static let defaultScrollSensitivity: Double = 0.35
    static var gridColumnRange: ClosedRange<Int> {
        minColumnsPerPage...maxColumnsPerPage
    }
    static var gridRowRange: ClosedRange<Int> {
        minRowsPerPage...maxRowsPerPage
    }
    static var columnSpacingRange: ClosedRange<Double> {
        minColumnSpacing...maxColumnSpacing
    }
    static var rowSpacingRange: ClosedRange<Double> {
        minRowSpacing...maxRowSpacing
    }
    static let hoverMagnificationRange: ClosedRange<Double> = 1.0...1.4
    private static let defaultHoverMagnificationScale: Double = 1.2
    static let activePressScaleRange: ClosedRange<Double> = 0.85...1.0
    private static let defaultActivePressScale: Double = 0.92
    static let folderPopoverWidthRange: ClosedRange<Double> = 0.6...0.95
    static let folderPopoverHeightRange: ClosedRange<Double> = 0.6...0.95
    private static let defaultFolderPopoverWidth: Double = 0.9
    private static let defaultFolderPopoverHeight: Double = 0.85
    private static let lastUpdateCheckKey = "lastUpdateCheckTimestamp"
    private static let automaticUpdateInterval: TimeInterval = 60 * 60 * 24

    private var lastUpdateCheck: Date? {
        get {
            if let timestamp = UserDefaults.standard.object(
                forKey: Self.lastUpdateCheckKey
            ) as? TimeInterval {
                return Date(timeIntervalSince1970: timestamp)
            }
            return nil
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(
                    date.timeIntervalSince1970,
                    forKey: Self.lastUpdateCheckKey
                )
            } else {
                UserDefaults.standard.removeObject(
                    forKey: Self.lastUpdateCheckKey
                )
            }
        }
    }

    private lazy var notificationDelegate = UpdateNotificationDelegate(
        openHandler: { [weak self] url in
            self?.openReleaseURL(url)
        })

    struct HotKeyConfiguration: Equatable {
        let keyCode: UInt16
        let modifiersRawValue: NSEvent.ModifierFlags.RawValue

        init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
            self.keyCode = keyCode
            self.modifiersRawValue =
                modifierFlags.normalizedShortcutFlags.rawValue
        }

        init?(dictionary: [String: Any]) {
            guard let rawKeyCode = dictionary["keyCode"] as? Int,
                let rawModifiers = dictionary["modifiers"] as? Int
            else {
                return nil
            }
            self.keyCode = UInt16(rawKeyCode)
            self.modifiersRawValue = NSEvent.ModifierFlags.RawValue(
                rawModifiers
            )
        }

        var modifierFlags: NSEvent.ModifierFlags {
            NSEvent.ModifierFlags(rawValue: modifiersRawValue)
                .normalizedShortcutFlags
        }

        var dictionaryRepresentation: [String: Any] {
            ["keyCode": Int(keyCode), "modifiers": Int(modifiersRawValue)]
        }

        var carbonModifierFlags: UInt32 { modifierFlags.carbonFlags }
        var keyCodeUInt32: UInt32 { UInt32(keyCode) }

        var displayString: String {
            let modifierSymbols = modifierFlags.displaySymbols.joined()
            let keyName = HotKeyConfiguration.keyDisplayName(for: keyCode)
            return modifierSymbols + keyName
        }

        private static func keyDisplayName(for keyCode: UInt16) -> String {
            if let special = Self.specialKeyNames[keyCode] {
                return special
            }

            guard
                let layout = TISCopyCurrentKeyboardLayoutInputSource()?
                    .takeRetainedValue(),
                let rawPtr = TISGetInputSourceProperty(
                    layout,
                    kTISPropertyUnicodeKeyLayoutData
                )
            else {
                return String(format: "Key %d", keyCode)
            }

            let data = unsafeBitCast(rawPtr, to: CFData.self) as Data
            return data.withUnsafeBytes { ptr -> String in
                guard
                    let layoutPtr = ptr.baseAddress?.assumingMemoryBound(
                        to: UCKeyboardLayout.self
                    )
                else {
                    return String(format: "Key %d", keyCode)
                }
                var keysDown: UInt32 = 0
                var chars: [UniChar] = Array(repeating: 0, count: 4)
                var length: Int = 0
                let error = UCKeyTranslate(
                    layoutPtr,
                    keyCode,
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    UInt32(kUCKeyTranslateNoDeadKeysBit),
                    &keysDown,
                    chars.count,
                    &length,
                    &chars
                )
                if error == noErr, length > 0 {
                    return String(utf16CodeUnits: chars, count: length)
                        .uppercased()
                }
                return fallbackName(for: keyCode)
            }
        }

        private static func fallbackName(for keyCode: UInt16) -> String {
            Self.specialKeyNames[keyCode] ?? String(format: "Key %d", keyCode)
        }

        private static let specialKeyNames: [UInt16: String] = [
            36: "Return",
            48: "Tab",
            49: "Space",
            51: "Delete",
            53: "Esc",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
            123: "←",
            124: "→",
            125: "↓",
            126: "↑",
        ]
    }
    @Published var apps: [AppInfo] = []
    @Published var folders: [FolderInfo] = []
    @Published var items: [LaunchpadItem] = []
    @Published private(set) var hiddenAppPaths: Set<String> =
        AppStore.loadHiddenApps()

    private func persistHiddenApps(_ set: Set<String>) {
        let array = Array(set).sorted()
        UserDefaults.standard.set(array, forKey: Self.hiddenAppsKey)
    }

    private func updateHiddenAppPaths(_ changes: (inout Set<String>) -> Void) {
        var updated = hiddenAppPaths
        let original = updated
        changes(&updated)
        guard updated != original else { return }
        hiddenAppPaths = updated
        persistHiddenApps(updated)
    }

    @Published var launchpadBackgroundStyle: BackgroundStyle =
        AppStore.loadBackgroundStyle()
    {
        didSet {
            guard launchpadBackgroundStyle != oldValue else { return }
            UserDefaults.standard.set(
                launchpadBackgroundStyle.rawValue,
                forKey: Self.backgroundStyleKey
            )
        }
    }
    @Published var isSetting = false
    @Published var settingsInitialSection: SettingsSection? = nil
    @Published var isInitialLoading = true
    
    enum SettingsSection: String, CaseIterable, Identifiable {
        case general
        case appearance
        case performance
        case titles
        case hiddenApps
        case development
        case about

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintbrush"
            case .performance: return "speedometer"
            case .titles: return "text.badge.plus"
            case .hiddenApps: return "eye.slash"
            case .development: return "hammer"
            case .about: return "info.circle"
            }
        }

        var iconGradient: LinearGradient {
            let colors: [Color]
            switch self {
            case .general:
                colors = [
                    Color(red: 0.12, green: 0.52, blue: 0.96),
                    Color(red: 0.22, green: 0.72, blue: 0.94),
                ]
            case .appearance:
                colors = [
                    Color(red: 0.73, green: 0.25, blue: 0.96),
                    Color(red: 0.98, green: 0.43, blue: 0.80),
                ]
            case .performance:
                colors = [
                    Color(red: 0.02, green: 0.70, blue: 0.46),
                    Color(red: 0.31, green: 0.93, blue: 0.69),
                ]
            case .titles:
                colors = [
                    Color(red: 0.95, green: 0.37, blue: 0.32),
                    Color(red: 0.98, green: 0.55, blue: 0.44),
                ]
            case .hiddenApps:
                colors = [
                    Color(red: 0.29, green: 0.39, blue: 0.96),
                    Color(red: 0.11, green: 0.67, blue: 0.91),
                ]
            case .development:
                colors = [
                    Color(red: 0.98, green: 0.58, blue: 0.16),
                    Color(red: 0.96, green: 0.20, blue: 0.24),
                ]
            case .about:
                colors = [
                    Color(red: 0.54, green: 0.55, blue: 0.70),
                    Color(red: 0.42, green: 0.44, blue: 0.60),
                ]
            }
            return LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        var localizationKey: LocalizationKey {
            switch self {
            case .general: return .settingsSectionGeneral
            case .appearance: return .settingsSectionAppearance
            case .performance: return .settingsSectionPerformance
            case .titles: return .settingsSectionTitles
            case .hiddenApps: return .settingsSectionHiddenApps
            case .development: return .settingsSectionDevelopment
            case .about: return .settingsSectionAbout
            }
        }
    }
    @Published var currentPage = 0 {
        didSet {
            if currentPage < 0 {
                currentPage = 0
                return
            }
            if rememberLastPage {
                UserDefaults.standard.set(
                    currentPage,
                    forKey: Self.rememberedPageIndexKey
                )
            }
        }
    }
    @Published var searchText: String = ""
    @Published private(set) var searchQuery: String = ""
    @Published var isStartOnLogin: Bool = false
    @Published var isFullscreenMode: Bool = false {
        didSet {
            UserDefaults.standard.set(
                isFullscreenMode,
                forKey: "isFullscreenMode"
            )
            // Set transition state
            isTransitioning = true
            
            // Combine async operations to reduce delay
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // First update window mode
                if let appDelegate = AppDelegate.shared {
                    appDelegate.updateWindowMode(
                        isFullscreen: self.isFullscreenMode
                    )
                }
                // Then trigger UI refresh
                self.triggerGridRefresh(force: true)
                
                // Delay reset transition state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isTransitioning = false
                }
            }
        }
    }
    private static func clampColumns(_ value: Int) -> Int {
        min(max(value, minColumnsPerPage), maxColumnsPerPage)
    }

    private static func clampRows(_ value: Int) -> Int {
        min(max(value, minRowsPerPage), maxRowsPerPage)
    }

    private static func clampColumnSpacing(_ value: Double) -> Double {
        min(max(value, minColumnSpacing), maxColumnSpacing)
    }

    private static func clampRowSpacing(_ value: Double) -> Double {
        min(max(value, minRowSpacing), maxRowSpacing)
    }

    private static func clampFolderWidth(_ value: Double) -> Double {
        min(
            max(value, folderPopoverWidthRange.lowerBound),
            folderPopoverWidthRange.upperBound
        )
    }

    private static func clampFolderHeight(_ value: Double) -> Double {
        min(
            max(value, folderPopoverHeightRange.lowerBound),
            folderPopoverHeightRange.upperBound
        )
    }

    // Icon title display
    @Published var showLabels: Bool = {
        if UserDefaults.standard.object(forKey: "showLabels") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "showLabels")
    }()
    {
        didSet { UserDefaults.standard.set(showLabels, forKey: "showLabels") }
    }

    @Published var scrollSensitivity: Double {
        didSet {
            UserDefaults.standard.set(
                scrollSensitivity,
                forKey: "scrollSensitivity"
            )
        }
    }

    @Published var gridColumnsPerPage: Int {
        didSet {
            let clamped = Self.clampColumns(gridColumnsPerPage)
            if gridColumnsPerPage != clamped {
                gridColumnsPerPage = clamped
                return
            }
            guard gridColumnsPerPage != oldValue else { return }
            UserDefaults.standard.set(
                gridColumnsPerPage,
                forKey: Self.gridColumnsKey
            )
            handleGridConfigurationChange()
        }
    }

    @Published var gridRowsPerPage: Int {
        didSet {
            let clamped = Self.clampRows(gridRowsPerPage)
            if gridRowsPerPage != clamped {
                gridRowsPerPage = clamped
                return
            }
            guard gridRowsPerPage != oldValue else { return }
            UserDefaults.standard.set(gridRowsPerPage, forKey: Self.gridRowsKey)
            handleGridConfigurationChange()
        }
    }

    @Published var iconColumnSpacing: Double {
        didSet {
            let clamped = Self.clampColumnSpacing(iconColumnSpacing)
            if iconColumnSpacing != clamped {
                iconColumnSpacing = clamped
                return
            }
            guard iconColumnSpacing != oldValue else { return }
            UserDefaults.standard.set(
                iconColumnSpacing,
                forKey: Self.columnSpacingKey
            )
            triggerGridRefresh()
        }
    }

    @Published var iconRowSpacing: Double {
        didSet {
            let clamped = Self.clampRowSpacing(iconRowSpacing)
            if iconRowSpacing != clamped {
                iconRowSpacing = clamped
                return
            }
            guard iconRowSpacing != oldValue else { return }
            UserDefaults.standard.set(
                iconRowSpacing,
                forKey: Self.rowSpacingKey
            )
            triggerGridRefresh()
        }
    }

    @Published var enableDropPrediction: Bool = {
        if UserDefaults.standard.object(forKey: "enableDropPrediction") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "enableDropPrediction")
    }()
    {
        didSet {
            UserDefaults.standard.set(
                enableDropPrediction,
                forKey: "enableDropPrediction"
            )
        }
    }

    @Published var enableAnimations: Bool = {
        if UserDefaults.standard.object(forKey: "enableAnimations") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "enableAnimations")
    }()
    {
        didSet {
            UserDefaults.standard.set(
                enableAnimations,
                forKey: "enableAnimations"
            )
        }
    }

    @Published var enableHoverMagnification: Bool = {
        if UserDefaults.standard.object(forKey: AppStore.hoverMagnificationKey)
            == nil
        {
            return true
        }
        return UserDefaults.standard.bool(
            forKey: AppStore.hoverMagnificationKey
        )
    }()
    {
        didSet {
            UserDefaults.standard.set(
                enableHoverMagnification,
                forKey: Self.hoverMagnificationKey
            )
        }
    }

    @Published var hoverMagnificationScale: Double = {
        let defaults = UserDefaults.standard
        let stored =
            defaults.object(forKey: AppStore.hoverMagnificationScaleKey)
            as? Double
        let initial = stored ?? AppStore.defaultHoverMagnificationScale
        let clamped = min(
            max(initial, AppStore.hoverMagnificationRange.lowerBound),
            AppStore.hoverMagnificationRange.upperBound
        )
        if stored == nil || stored != clamped {
            defaults.set(clamped, forKey: AppStore.hoverMagnificationScaleKey)
        }
        return clamped
    }()
    {
        didSet {
            let clamped = min(
                max(
                    hoverMagnificationScale,
                    Self.hoverMagnificationRange.lowerBound
                ),
                Self.hoverMagnificationRange.upperBound
            )
            if hoverMagnificationScale != clamped {
                hoverMagnificationScale = clamped
                return
            }
            UserDefaults.standard.set(
                hoverMagnificationScale,
                forKey: Self.hoverMagnificationScaleKey
            )
        }
    }

    @Published var enableActivePressEffect: Bool = {
        if UserDefaults.standard.object(forKey: AppStore.activePressEffectKey)
            == nil
        {
            return true
        }
        return UserDefaults.standard.bool(forKey: AppStore.activePressEffectKey)
    }()
    {
        didSet {
            UserDefaults.standard.set(
                enableActivePressEffect,
                forKey: Self.activePressEffectKey
            )
        }
    }

    @Published var activePressScale: Double = {
        let defaults = UserDefaults.standard
        let stored =
            defaults.object(forKey: AppStore.activePressScaleKey) as? Double
        let initial = stored ?? AppStore.defaultActivePressScale
        let clamped = min(
            max(initial, AppStore.activePressScaleRange.lowerBound),
            AppStore.activePressScaleRange.upperBound
        )
        if stored == nil || stored != clamped {
            defaults.set(clamped, forKey: AppStore.activePressScaleKey)
        }
        return clamped
    }()
    {
        didSet {
            let clamped = min(
                max(activePressScale, Self.activePressScaleRange.lowerBound),
                Self.activePressScaleRange.upperBound
            )
            if activePressScale != clamped {
                activePressScale = clamped
                return
            }
            UserDefaults.standard.set(
                activePressScale,
                forKey: Self.activePressScaleKey
            )
        }
    }

    @Published var iconLabelFontSize: Double = {
        let stored = UserDefaults.standard.double(forKey: "iconLabelFontSize")
        return stored == 0 ? 11.0 : stored
    }()
    {
        didSet {
            UserDefaults.standard.set(
                iconLabelFontSize,
                forKey: "iconLabelFontSize"
            )
            triggerGridRefresh()
        }
    }

    @Published var iconLabelFontWeight: IconLabelFontWeightOption = {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: AppStore.iconLabelFontWeightKey),
            let value = IconLabelFontWeightOption(rawValue: raw)
        {
            return value
        }
        return .medium
    }()
    {
        didSet {
            guard iconLabelFontWeight != oldValue else { return }
            UserDefaults.standard.set(
                iconLabelFontWeight.rawValue,
                forKey: AppStore.iconLabelFontWeightKey
            )
            triggerGridRefresh()
        }
    }

    var iconLabelFontWeightValue: Font.Weight {
        iconLabelFontWeight.fontWeight
    }

    @Published var showQuickRefreshButton: Bool = {
        if UserDefaults.standard.object(
            forKey: AppStore.showQuickRefreshButtonKey
        ) == nil {
            return false
        }
        return UserDefaults.standard.bool(
            forKey: AppStore.showQuickRefreshButtonKey
        )
    }()
    {
        didSet {
            guard showQuickRefreshButton != oldValue else { return }
            UserDefaults.standard.set(
                showQuickRefreshButton,
                forKey: AppStore.showQuickRefreshButtonKey
            )
        }
    }

    // Update-check related state
    @Published var updateState: UpdateState = .idle

    @Published var autoCheckForUpdates: Bool = {
        if UserDefaults.standard.object(forKey: "autoCheckForUpdates") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "autoCheckForUpdates")
    }()
    {
        didSet {
            UserDefaults.standard.set(
                autoCheckForUpdates,
                forKey: "autoCheckForUpdates"
            )
            if autoCheckForUpdates {
                scheduleAutomaticUpdateCheck()
            } else {
                autoCheckTimer?.cancel()
                autoCheckTimer = nil
            }
        }
    }

    @Published var animationDuration: Double = {
        let stored = UserDefaults.standard.double(forKey: "animationDuration")
        return stored == 0 ? 0.3 : stored
    }()
    {
        didSet {
            UserDefaults.standard.set(
                animationDuration,
                forKey: "animationDuration"
            )
        }
    }

    @Published var useLocalizedThirdPartyTitles: Bool = {
        if UserDefaults.standard.object(forKey: "useLocalizedThirdPartyTitles")
            == nil
        {
            return true
        }
        return UserDefaults.standard.bool(
            forKey: "useLocalizedThirdPartyTitles"
        )
    }()
    {
        didSet {
            guard oldValue != useLocalizedThirdPartyTitles else { return }
            UserDefaults.standard.set(
                useLocalizedThirdPartyTitles,
                forKey: "useLocalizedThirdPartyTitles"
            )
            DispatchQueue.main.async { [weak self] in
                self?.refresh()
            }
        }
    }

    @Published var showFPSOverlay: Bool = {
        if UserDefaults.standard.object(forKey: "showFPSOverlay") == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: "showFPSOverlay")
    }()
    {
        didSet {
            UserDefaults.standard.set(showFPSOverlay, forKey: "showFPSOverlay")
        }
    }

    @Published var pageIndicatorOffset: Double = {
        if UserDefaults.standard.object(forKey: "pageIndicatorOffset") == nil {
            return 27.0
        }
        return UserDefaults.standard.double(forKey: "pageIndicatorOffset")
    }()
    {
        didSet {
            UserDefaults.standard.set(
                pageIndicatorOffset,
                forKey: "pageIndicatorOffset"
            )
        }
    }

    @Published var rememberLastPage: Bool = AppStore.defaultRememberSetting() {
        didSet {
            UserDefaults.standard.set(
                rememberLastPage,
                forKey: Self.rememberPageKey
            )
            if rememberLastPage {
                UserDefaults.standard.set(
                    currentPage,
                    forKey: Self.rememberedPageIndexKey
                )
            } else {
                UserDefaults.standard.removeObject(
                    forKey: Self.rememberedPageIndexKey
                )
            }
        }
    }

    @Published var folderPopoverWidthFactor: Double = {
        let stored = UserDefaults.standard.double(
            forKey: "folderPopoverWidthFactor"
        )
        if stored == 0 { return defaultFolderPopoverWidth }
        return clampFolderWidth(stored)
    }()
    {
        didSet {
            let clamped = AppStore.clampFolderWidth(folderPopoverWidthFactor)
            if folderPopoverWidthFactor != clamped {
                folderPopoverWidthFactor = clamped
                return
            }
            UserDefaults.standard.set(
                folderPopoverWidthFactor,
                forKey: "folderPopoverWidthFactor"
            )
        }
    }

    @Published var folderPopoverHeightFactor: Double = {
        let stored = UserDefaults.standard.double(
            forKey: "folderPopoverHeightFactor"
        )
        if stored == 0 { return defaultFolderPopoverHeight }
        return clampFolderHeight(stored)
    }()
    {
        didSet {
            let clamped = AppStore.clampFolderHeight(folderPopoverHeightFactor)
            if folderPopoverHeightFactor != clamped {
                folderPopoverHeightFactor = clamped
                return
            }
            UserDefaults.standard.set(
                folderPopoverHeightFactor,
                forKey: "folderPopoverHeightFactor"
            )
        }
    }

    @Published var appearancePreference: AppearancePreference = {
        if let raw = UserDefaults.standard.string(
            forKey: "appearancePreference"
        ),
            let pref = AppearancePreference(rawValue: raw)
        {
            return pref
        }
        return .system
    }()
    {
        didSet {
            guard oldValue != appearancePreference else { return }
            UserDefaults.standard.set(
                appearancePreference.rawValue,
                forKey: "appearancePreference"
            )
        }
    }

    private static func defaultRememberSetting() -> Bool {
        if UserDefaults.standard.object(forKey: rememberPageKey) == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: rememberPageKey)
    }

    @Published var globalHotKey: HotKeyConfiguration? =
        AppStore.loadHotKeyConfiguration()
    {
        didSet {
            persistHotKeyConfiguration()
            AppDelegate.shared?.updateGlobalHotKey(configuration: globalHotKey)
        }
    }

    @Published private(set) var currentAppIcon: NSImage {
        didSet { applyCurrentAppIcon() }
    }

    @Published private(set) var hasCustomAppIcon: Bool

    @Published var preferredLanguage: AppLanguage = {
        if let raw = UserDefaults.standard.string(forKey: "preferredLanguage"),
            let lang = AppLanguage(rawValue: raw)
        {
            return lang
        }
        return .system
    }()
    {
        didSet {
            UserDefaults.standard.set(
                preferredLanguage.rawValue,
                forKey: "preferredLanguage"
            )
            
            // Post language change notification
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    @Published private(set) var customTitles: [String: String] =
        AppStore.loadCustomTitles()
    {
        didSet { persistCustomTitles() }
    }

    @Published var showInDock: Bool = true {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: Self.showInDockKey)
            // Apply Dock visibility immediately
            updateDockVisibility()
        }
    }

    // Update Dock visibility state
    private func updateDockVisibility() {
        DispatchQueue.main.async {
            // Set flag to prevent the settings window from closing while updating Dock policy
            AppDelegate.shared?.isUpdatingDockPolicy = true
            
            if self.showInDock {
                // Show in Dock
                NSApplication.shared.setActivationPolicy(.regular)
            } else {
                // Hide from Dock
                NSApplication.shared.setActivationPolicy(.accessory)
            }
            
            // Reset the flag after a short delay to ensure focus events are processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                AppDelegate.shared?.isUpdatingDockPolicy = false
            }
        }
    }

    // Restart application (improved)
    func restartApplication() {
        // First terminate the current app
        NSApplication.shared.terminate(nil)

        // Launch a new instance after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = [Bundle.main.bundlePath]

            do {
                try task.run()
            } catch {
                print("Failed to restart application: \(error)")
            }
        }
    }

    // Cache manager
    private let cacheManager = AppCacheManager.shared

    // Folder-related state
    @Published var openFolder: FolderInfo? = nil
    @Published var isDragCreatingFolder = false
    @Published var folderCreationTarget: AppInfo? = nil
    @Published var openFolderActivatedByKeyboard: Bool = false
    @Published var isFolderNameEditing: Bool = false
    @Published var handoffDraggingApp: AppInfo? = nil
    @Published var handoffDragScreenLocation: CGPoint? = nil

    // Triggers
    @Published var folderUpdateTrigger: UUID = UUID()
    @Published var gridRefreshTrigger: UUID = UUID()
    
    // Transition state management
    @Published private var isTransitioning: Bool = false

    var modelContext: ModelContext?

    // MARK: - Auto rescan (FSEvents)
    private var fsEventStream: FSEventStreamRef?
    private var pendingChangedAppPaths: Set<String> = []
    private var pendingForceFullScan: Bool = false
    private let fullRescanThreshold: Int = 50

    // State flags
    private var hasPerformedInitialScan: Bool = false
    private var cancellables: Set<AnyCancellable> = []
    private var hasAppliedOrderFromStore: Bool = false

    // Background refresh queues and throttling
    private let refreshQueue = DispatchQueue(
        label: "app.store.refresh",
        qos: .userInitiated
    )
    private var gridRefreshWorkItem: DispatchWorkItem?
    private var iconScaleWorkItem: DispatchWorkItem?
    private var rescanWorkItem: DispatchWorkItem?
    private var customTitleRefreshWorkItem: DispatchWorkItem?
    private let fsEventsQueue = DispatchQueue(label: "app.store.fsevents")
    private let customIconFileURL: URL
    private let defaultAppIcon: NSImage
    private var autoCheckTimer: DispatchSourceTimer?

    // Computed properties
    private var itemsPerPage: Int { gridColumnsPerPage * gridRowsPerPage }

    private let applicationSearchPaths: [String] = [
        "/Applications",
        "\(NSHomeDirectory())/Applications",
        "/System/Applications",
        "/System/Cryptexes/App/System/Applications",
    ]

    init() {
        if UserDefaults.standard.object(forKey: "isFullscreenMode") == nil {
            self.isFullscreenMode = true  // New users default to Classic (Fullscreen)
            UserDefaults.standard.set(true, forKey: "isFullscreenMode")
        } else {
            self.isFullscreenMode = UserDefaults.standard.bool(
                forKey: "isFullscreenMode"
            )
        }
        let defaults = UserDefaults.standard

        let shouldRememberPage =
            defaults.object(forKey: Self.rememberPageKey) == nil
            ? false : defaults.bool(forKey: Self.rememberPageKey)
        let savedPageIndex =
            defaults.object(forKey: Self.rememberedPageIndexKey) as? Int

        let storedSensitivity = defaults.double(forKey: "scrollSensitivity")
        self.scrollSensitivity =
            storedSensitivity == 0
            ? Self.defaultScrollSensitivity : storedSensitivity

        let storedColumns =
            defaults.object(forKey: Self.gridColumnsKey) as? Int ?? 7
        let clampedColumns = Self.clampColumns(storedColumns)
        self.gridColumnsPerPage = clampedColumns
        defaults.set(clampedColumns, forKey: Self.gridColumnsKey)

        let storedRows = defaults.object(forKey: Self.gridRowsKey) as? Int ?? 5
        let clampedRows = Self.clampRows(storedRows)
        self.gridRowsPerPage = clampedRows
        defaults.set(clampedRows, forKey: Self.gridRowsKey)

        // Load Dock visibility setting
        let storedShowInDock =
            defaults.object(forKey: Self.showInDockKey) as? Bool ?? true
        self.showInDock = storedShowInDock

        let storedColumnSpacing =
            defaults.object(forKey: Self.columnSpacingKey) as? Double ?? 20.0
        let clampedColumnSpacing = Self.clampColumnSpacing(storedColumnSpacing)
        self.iconColumnSpacing = clampedColumnSpacing
        defaults.set(clampedColumnSpacing, forKey: Self.columnSpacingKey)

        let storedRowSpacing =
            defaults.object(forKey: Self.rowSpacingKey) as? Double ?? 14.0
        let clampedRowSpacing = Self.clampRowSpacing(storedRowSpacing)
        self.iconRowSpacing = clampedRowSpacing
        defaults.set(clampedRowSpacing, forKey: Self.rowSpacingKey)
        // Read default icon scale
        if let v = UserDefaults.standard.object(forKey: "iconScale") as? Double
        {
            self.iconScale = v
        }
        if UserDefaults.standard.object(forKey: "enableDropPrediction") == nil {
            UserDefaults.standard.set(true, forKey: "enableDropPrediction")
        }
        if UserDefaults.standard.object(forKey: "useLocalizedThirdPartyTitles")
            == nil
        {
            UserDefaults.standard.set(
                true,
                forKey: "useLocalizedThirdPartyTitles"
            )
        }
        if UserDefaults.standard.object(forKey: "enableAnimations") == nil {
            UserDefaults.standard.set(true, forKey: "enableAnimations")
        }
        if UserDefaults.standard.object(forKey: "iconLabelFontSize") == nil {
            UserDefaults.standard.set(11.0, forKey: "iconLabelFontSize")
        }
        if UserDefaults.standard.object(forKey: AppStore.iconLabelFontWeightKey)
            == nil
        {
            UserDefaults.standard.set(
                IconLabelFontWeightOption.medium.rawValue,
                forKey: AppStore.iconLabelFontWeightKey
            )
        }
        if UserDefaults.standard.object(forKey: "animationDuration") == nil {
            UserDefaults.standard.set(0.3, forKey: "animationDuration")
        }
        if UserDefaults.standard.object(forKey: "showFPSOverlay") == nil {
            UserDefaults.standard.set(false, forKey: "showFPSOverlay")
        }
        if defaults.object(forKey: "pageIndicatorOffset") == nil {
            defaults.set(27.0, forKey: "pageIndicatorOffset")
        }

        let storedDuration = UserDefaults.standard.double(
            forKey: "animationDuration"
        )
        self.animationDuration = storedDuration == 0 ? 0.3 : storedDuration
        self.enableAnimations =
            UserDefaults.standard.object(forKey: "enableAnimations") as? Bool
            ?? true
        self.customIconFileURL = AppStore.customIconFileURL

        let fallbackIcon =
            (NSApplication.shared.applicationIconImage?.copy() as? NSImage)
            ?? NSImage(size: NSSize(width: 512, height: 512))
        self.defaultAppIcon = fallbackIcon
        if let storedIcon = AppStore.loadStoredAppIcon(from: customIconFileURL)
        {
            self.hasCustomAppIcon = true
            self.currentAppIcon = storedIcon
        } else {
            self.hasCustomAppIcon = false
            self.currentAppIcon = fallbackIcon
        }
        applyCurrentAppIcon()

        $searchText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] value in
                self?.searchQuery = value
            }
            .store(in: &cancellables)

        searchQuery = searchText

        scheduleAutomaticUpdateCheck()

        // Apply initial Dock visibility setting
        updateDockVisibility()

        self.rememberLastPage = shouldRememberPage
        if shouldRememberPage, let savedPageIndex {
            self.currentPage = max(0, savedPageIndex)
        }
    }

    private static func loadCustomTitles() -> [String: String] {
        guard
            let raw = UserDefaults.standard.dictionary(
                forKey: AppStore.customTitlesKey
            )
        else {
            return [:]
        }

        var result: [String: String] = [:]
        for (key, value) in raw {
            guard let stringValue = value as? String else { continue }
            let trimmed = stringValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !trimmed.isEmpty {
                result[key] = trimmed
            }
        }
        return result
    }

    private static func loadHotKeyConfiguration() -> HotKeyConfiguration? {
        guard
            let dict = UserDefaults.standard.dictionary(forKey: globalHotKeyKey)
        else { return nil }
        return HotKeyConfiguration(dictionary: dict)
    }

    private func persistCustomTitles() {
        let sanitized = customTitles.reduce(into: [String: String]()) {
            partialResult,
            entry in
            let trimmed = entry.value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !trimmed.isEmpty {
                partialResult[entry.key] = trimmed
            }
        }

        if sanitized.isEmpty {
            UserDefaults.standard.removeObject(forKey: AppStore.customTitlesKey)
        } else {
            UserDefaults.standard.set(
                sanitized,
                forKey: AppStore.customTitlesKey
            )
        }
    }

    private func persistHotKeyConfiguration() {
        let defaults = UserDefaults.standard
        if let config = globalHotKey {
            defaults.set(
                config.dictionaryRepresentation,
                forKey: Self.globalHotKeyKey
            )
        } else {
            defaults.removeObject(forKey: Self.globalHotKeyKey)
        }
    }

    // Icon scale (relative to the grid): default 0.95, recommended 0.8–1.1
    @Published var iconScale: Double = 0.95 {
        didSet {
            UserDefaults.standard.set(iconScale, forKey: "iconScale")
            iconScaleWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.triggerGridRefresh()
            }
            iconScaleWorkItem = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.08,
                execute: work
            )
        }
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Immediately try to load persisted data (if any) — don't set the flag early; set it after loading completes
        if !hasAppliedOrderFromStore {
            loadAllOrder()
        }

        $apps
            .map { !$0.isEmpty }
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self else { return }
                if !self.hasAppliedOrderFromStore {
                    self.loadAllOrder()
                }
            }
            .store(in: &cancellables)

        // Observe item changes and auto-save ordering
        $items
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.items.isEmpty else { return }
                // Delay saving to avoid frequent writes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.saveAllOrder()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Order Persistence
    func applyOrderAndFolders() {
        self.loadAllOrder()
    }

    // MARK: - Initial scan (once)
    func performInitialScanIfNeeded() {
        // Return if the initial scan has already run to avoid slowing startup
        if hasPerformedInitialScan { return }
        // Load persisted data first to avoid being overridden by scanning (do not set the flag early)
        if !hasAppliedOrderFromStore {
            loadAllOrder()
        }

        // Then perform scanning while preserving the existing order
        hasPerformedInitialScan = true
        scanApplicationsWithOrderPreservation()

        // Generate cache after scanning completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.generateCacheAfterScan()
        }
    }

    func scanApplications(loadPersistedOrder: Bool = true) {
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [AppInfo] = []
            var seenPaths = Set<String>()

            for path in self.applicationSearchPaths {
                let url = URL(fileURLWithPath: path)

                if let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    for case let item as URL in enumerator {
                        let resolved = item.resolvingSymlinksInPath()
                        guard resolved.pathExtension == "app",
                            self.isValidApp(at: resolved),
                            !self.isInsideAnotherApp(resolved)
                        else { continue }
                        if !seenPaths.contains(resolved.path) {
                            seenPaths.insert(resolved.path)
                            found.append(self.appInfo(from: resolved))
                        }
                    }
                }
            }

            let sorted = found.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name)
                    == .orderedAscending
            }
            DispatchQueue.main.async {
                self.apps = sorted
                self.pruneHiddenAppsFromAppList()
                if loadPersistedOrder {
                    self.rebuildItems()
                    self.loadAllOrder()
                } else {
                    self.items = self.filteredItemsRemovingHidden(
                        from: sorted.map { .app($0) }
                    )
                    self.saveAllOrder()
                }

                // Generate cache after scanning completes
                self.generateCacheAfterScan()
            }
        }
    }

    /// Intelligent scan: preserve current order; append new apps to the end; remove missing apps; auto compact within page
    func scanApplicationsWithOrderPreservation() {
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [AppInfo] = []
            var seenPaths = Set<String>()

            // Use a concurrent queue to accelerate scanning
            let scanQueue = DispatchQueue(
                label: "app.scan",
                attributes: .concurrent
            )
            let group = DispatchGroup()
            let lock = NSLock()

            // Scan all applications
            for path in self.applicationSearchPaths {
                group.enter()
                scanQueue.async {
                    let url = URL(fileURLWithPath: path)

                    if let enumerator = FileManager.default.enumerator(
                        at: url,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) {
                        var localFound: [AppInfo] = []
                        var localSeenPaths = Set<String>()

                        for case let item as URL in enumerator {
                            let resolved = item.resolvingSymlinksInPath()
                            guard resolved.pathExtension == "app",
                                self.isValidApp(at: resolved),
                                !self.isInsideAnotherApp(resolved)
                            else { continue }
                            if !localSeenPaths.contains(resolved.path) {
                                localSeenPaths.insert(resolved.path)
                                localFound.append(self.appInfo(from: resolved))
                            }
                        }

                        // Merge results thread-safely
                        lock.lock()
                        found.append(contentsOf: localFound)
                        seenPaths.formUnion(localSeenPaths)
                        lock.unlock()
                    }
                    group.leave()
                }
            }

            group.wait()

            // De-duplicate and sort — safer approach
            var uniqueApps: [AppInfo] = []
            var uniqueSeenPaths = Set<String>()

            for app in found {
                if !uniqueSeenPaths.contains(app.url.path) {
                    uniqueSeenPaths.insert(app.url.path)
                    uniqueApps.append(app)
                }
            }

            // Keep the order of existing apps; sort only newly added apps by name
            var newApps: [AppInfo] = []
            var existingAppPaths = Set<String>()
            let refreshedMap = Dictionary(
                uniqueKeysWithValues: uniqueApps.map { ($0.url.path, $0) }
            )

            for app in self.apps {
                guard let refreshed = refreshedMap[app.url.path] else {
                    continue
                }
                newApps.append(refreshed)
                existingAppPaths.insert(app.url.path)
            }

            let newAppPaths = uniqueApps.filter {
                !existingAppPaths.contains($0.url.path)
            }
            let sortedNewApps = newAppPaths.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name)
                    == .orderedAscending
            }
            newApps.append(contentsOf: sortedNewApps)

            DispatchQueue.main.async {
                self.processScannedApplications(newApps)

                // Generate cache after scanning completes
                self.generateCacheAfterScan()
            }
        }
    }

    /// Manually trigger a full rescan (used by manual refresh in settings)
    func forceFullRescan() {
        // Clear caches
        cacheManager.clearAllCaches()

        hasPerformedInitialScan = false
        scanApplicationsWithOrderPreservation()
    }

    /// Process scanned apps and intelligently match the existing ordering
    private func processScannedApplications(_ newApps: [AppInfo]) {
        // Save the current order and structure of items
        let currentItems = self.items

        // Build a new app list while preserving existing order
        var updatedApps: [AppInfo] = []
        var newAppsToAdd: [AppInfo] = []
        let freshMap: [String: AppInfo] = Dictionary(
            uniqueKeysWithValues: newApps.map { ($0.url.path, $0) }
        )

        // Step 1: Preserve existing order while refreshing app info from the latest scan
        for app in self.apps {
            if let refreshed = freshMap[app.url.path] {
                updatedApps.append(refreshed)
            } else {
                // App has been deleted; remove it from all relevant positions
                self.removeDeletedApp(app)
            }
        }

        // Synchronize app objects inside folders to ensure names/icons update
        for folderIndex in folders.indices {
            let refreshedApps = folders[folderIndex].apps.compactMap {
                freshMap[$0.url.path]
            }
            if refreshedApps.isEmpty {
                folders[folderIndex].apps.removeAll()
            } else if refreshedApps.count != folders[folderIndex].apps.count {
                folders[folderIndex].apps = refreshedApps
            } else {
                folders[folderIndex].apps = refreshedApps
            }
        }
        folders.removeAll { $0.apps.isEmpty }

        // Step 2: Identify newly added apps (keep the order from the scan)
        let existingPaths = Set(updatedApps.map { $0.url.path })
        for newApp in newApps where !existingPaths.contains(newApp.url.path) {
            newAppsToAdd.append(newApp)
        }

        // Step 3: Append newly added apps to the end; keep existing order intact
        updatedApps.append(contentsOf: newAppsToAdd)

        // Update the app list
        self.apps = updatedApps
        pruneHiddenAppsFromAppList()

        // Step 4: Smartly rebuild the item list to preserve user ordering
        self.smartRebuildItemsWithOrderPreservation(
            currentItems: currentItems,
            newApps: newAppsToAdd
        )

        // Step 5: Auto-compact within each page
        self.compactItemsWithinPages()

        // Step 6: Save the new order
        self.saveAllOrder()

        // Trigger UI refresh
        self.triggerFolderUpdate()
        self.triggerGridRefresh()
    }

    /// Remove apps that have been deleted
    private func removeDeletedApp(_ deletedApp: AppInfo) {
        // Remove from folders
        for folderIndex in self.folders.indices {
            self.folders[folderIndex].apps.removeAll { $0 == deletedApp }
        }

        // Clean up empty folders
        self.folders.removeAll { $0.apps.isEmpty }

        // Remove from top-level items and replace with an empty slot
        for itemIndex in self.items.indices {
            if case .app(let app) = self.items[itemIndex], app == deletedApp {
                self.items[itemIndex] = .empty(UUID().uuidString)
            }
        }
    }

    /// Rebuild method that strictly preserves the existing order
    private func rebuildItemsWithStrictOrderPreservation(
        currentItems: [LaunchpadItem]
    ) {

        var newItems: [LaunchpadItem] = []
        let appsInFolders = Set(self.folders.flatMap { $0.apps })

        // Strictly preserve the order and positions of existing items
        for (_, item) in currentItems.enumerated() {
            switch item {
            case .folder(let folder):
                // Check whether the folder still exists
                if self.folders.contains(where: { $0.id == folder.id }) {
                    // Update the folder reference and keep its original position
                    if let updatedFolder = self.folders.first(where: {
                        $0.id == folder.id
                    }) {
                        newItems.append(.folder(updatedFolder))
                    } else {
                        // Folder was deleted; keep an empty slot
                        newItems.append(.empty(UUID().uuidString))
                    }
                } else {
                    // Folder was deleted; keep an empty slot
                    newItems.append(.empty(UUID().uuidString))
                }

            case .app(let app):
                // Check whether the app still exists
                if self.apps.contains(where: { $0.url.path == app.url.path }) {
                    if !appsInFolders.contains(app) {
                        // App still exists and is not in a folder; keep original position
                        newItems.append(.app(app))
                    } else {
                        // App is now inside a folder; keep an empty slot
                        newItems.append(.empty(UUID().uuidString))
                    }
                } else {
                    // App has been deleted; keep an empty slot
                    newItems.append(.empty(UUID().uuidString))
                }

            case .empty(let token):
                // Keep the empty slot to maintain page layout
                newItems.append(.empty(token))
            }
        }

        // Append newly added free apps (not in any folder) to the end of the last page
        let existingAppPaths = Set(
            newItems.compactMap { item in
                if case .app(let app) = item {
                    return app.url.path
                } else {
                    return nil
                }
            }
        )

        let newFreeApps = self.apps.filter { app in
            !appsInFolders.contains(app)
                && !existingAppPaths.contains(app.url.path)
        }

        if !newFreeApps.isEmpty {
            var pendingApps = newFreeApps
            let itemsPerPage = self.itemsPerPage

            if newItems.count > 0 {
                let lastPageStart =
                    ((newItems.count - 1) / itemsPerPage) * itemsPerPage
                let lastPageIndices = Array(lastPageStart..<newItems.count)
                let emptyIndices = lastPageIndices.filter { index in
                    if case .empty = newItems[index] { return true }
                    return false
                }
                let fillCount = min(pendingApps.count, emptyIndices.count)
                for i in 0..<fillCount {
                    newItems[emptyIndices[i]] = .app(pendingApps.removeFirst())
                }
            }

            if !pendingApps.isEmpty {
                let remainder = newItems.count % itemsPerPage
                if remainder != 0 {
                    let fillCount = min(
                        itemsPerPage - remainder,
                        pendingApps.count
                    )
                    for _ in 0..<fillCount {
                        newItems.append(.app(pendingApps.removeFirst()))
                    }
                }

                while !pendingApps.isEmpty {
                    for _ in 0..<itemsPerPage {
                        if pendingApps.isEmpty {
                            newItems.append(.empty(UUID().uuidString))
                        } else {
                            newItems.append(.app(pendingApps.removeFirst()))
                        }
                    }
                }
            }
        }

        self.items = filteredItemsRemovingHidden(from: newItems)
    }

    /// Smartly rebuild the item list while preserving user ordering
    private func smartRebuildItemsWithOrderPreservation(
        currentItems: [LaunchpadItem],
        newApps: [AppInfo]
    ) {

        // Keep current persisted data but don't load immediately (avoids overwriting current order)
        let hasPersistedData = self.hasPersistedOrderData()

        if hasPersistedData {

            // Intelligently merge current order with persisted data
            self.mergeCurrentOrderWithPersistedData(
                currentItems: currentItems,
                newApps: newApps,
                loadPersistedFolders: true
            )
        } else {

            // When no persisted data exists, merge directly based on current order
            self.mergeCurrentOrderWithPersistedData(
                currentItems: currentItems,
                newApps: newApps,
                loadPersistedFolders: false
            )
        }

    }

    /// Check whether persisted data exists
    private func hasPersistedOrderData() -> Bool {
        guard let modelContext = self.modelContext else { return false }

        do {
            let pageEntries = try modelContext.fetch(
                FetchDescriptor<PageEntryData>()
            )
            let topItems = try modelContext.fetch(
                FetchDescriptor<TopItemData>()
            )
            return !pageEntries.isEmpty || !topItems.isEmpty
        } catch {
            return false
        }
    }

    /// Intelligently merge current order with persisted data
    private func mergeCurrentOrderWithPersistedData(
        currentItems: [LaunchpadItem],
        newApps: [AppInfo],
        loadPersistedFolders: Bool = true
    ) {

        // Save current item order
        let currentOrder = currentItems

        // Load persisted data but only update folder information
        if loadPersistedFolders {
            self.loadFoldersFromPersistedData()
        }

        // Rebuild the item list while strictly preserving existing order
        var newItems: [LaunchpadItem] = []
        let appsInFolders = Set(self.folders.flatMap { $0.apps })
        let refreshedAppsByPath = Dictionary(
            uniqueKeysWithValues: self.apps.map { ($0.url.path, $0) }
        )

        // Step 1: Process existing items while preserving order
        for (_, item) in currentOrder.enumerated() {
            switch item {
            case .folder(let folder):
                // Check if the folder still exists
                if self.folders.contains(where: { $0.id == folder.id }) {
                    // Update folder reference and keep its original position
                    if let updatedFolder = self.folders.first(where: {
                        $0.id == folder.id
                    }) {
                        newItems.append(.folder(updatedFolder))
                    } else {
                        // Folder deleted; keep an empty slot
                        newItems.append(.empty(UUID().uuidString))
                    }
                } else {
                    // Folder deleted; keep an empty slot
                    newItems.append(.empty(UUID().uuidString))
                }

            case .app(let app):
                // Check if the app still exists
                if self.apps.contains(where: { $0.url.path == app.url.path }) {
                    if !appsInFolders.contains(app) {
                        // App exists and is not in a folder; update to latest info
                        let updatedApp =
                            refreshedAppsByPath[app.url.path] ?? app
                        newItems.append(.app(updatedApp))
                    } else {
                        // App is now inside a folder; keep an empty slot
                        newItems.append(.empty(UUID().uuidString))
                    }
                } else {
                    // App deleted; keep an empty slot
                    newItems.append(.empty(UUID().uuidString))
                }

            case .empty(let token):
                // Keep the empty slot to maintain page layout
                newItems.append(.empty(token))
            }
        }

        // Step 2: Append newly added free apps (not in any folder) to the end of the last page
        let existingAppPaths = Set(
            newItems.compactMap { item in
                if case .app(let app) = item {
                    return app.url.path
                } else {
                    return nil
                }
            }
        )

        let newFreeApps = self.apps.filter { app in
            !appsInFolders.contains(app)
                && !existingAppPaths.contains(app.url.path)
        }

        if !newFreeApps.isEmpty {
            var pendingApps = newFreeApps
            let itemsPerPage = self.itemsPerPage

            if newItems.count > 0 {
                let lastPageStart =
                    ((newItems.count - 1) / itemsPerPage) * itemsPerPage
                let lastPageIndices = Array(lastPageStart..<newItems.count)
                let emptyIndices = lastPageIndices.filter { index in
                    if case .empty = newItems[index] { return true }
                    return false
                }
                let fillCount = min(pendingApps.count, emptyIndices.count)
                for i in 0..<fillCount {
                    newItems[emptyIndices[i]] = .app(pendingApps.removeFirst())
                }
            }

            if !pendingApps.isEmpty {
                let remainder = newItems.count % itemsPerPage
                if remainder != 0 {
                    let fillCount = min(
                        itemsPerPage - remainder,
                        pendingApps.count
                    )
                    for _ in 0..<fillCount {
                        newItems.append(.app(pendingApps.removeFirst()))
                    }
                }

                while !pendingApps.isEmpty {
                    for _ in 0..<itemsPerPage {
                        if pendingApps.isEmpty {
                            newItems.append(.empty(UUID().uuidString))
                        } else {
                            newItems.append(.app(pendingApps.removeFirst()))
                        }
                    }
                }
            }
        }

        self.items = filteredItemsRemovingHidden(from: newItems)

    }

    /// Load only folder info without rebuilding item order
    private func loadFoldersFromPersistedData() {
        guard let modelContext = self.modelContext else { return }

        do {
            // Try reading folder info from the new "page-slot" model
            let saved = try modelContext.fetch(
                FetchDescriptor<PageEntryData>(
                    sortBy: [
                        SortDescriptor(\.pageIndex, order: .forward),
                        SortDescriptor(\.position, order: .forward),
                    ]
                )
            )

            if !saved.isEmpty {
                // Build folder list
                var folderMap: [String: FolderInfo] = [:]
                var foldersInOrder: [FolderInfo] = []

                for row in saved where row.kind == "folder" {
                    guard let fid = row.folderId else { continue }
                    if folderMap[fid] != nil { continue }

                    let folderApps: [AppInfo] = row.appPaths.compactMap {
                        path in
                        if let existing = apps.first(where: {
                            $0.url.path == path
                        }) {
                            return existing
                        }
                        let url = URL(fileURLWithPath: path)
                        guard FileManager.default.fileExists(atPath: url.path)
                        else { return nil }
                        return self.appInfo(from: url)
                    }

                    let folder = FolderInfo(
                        id: fid,
                        name: row.folderName ?? "Untitled",
                        apps: folderApps,
                        createdAt: row.createdAt
                    )
                    folderMap[fid] = folder
                    foldersInOrder.append(folder)
                }

                self.folders = self.sanitizedFolders(foldersInOrder)
            }
        } catch {
        }
    }

    deinit {
        autoCheckTimer?.cancel()
        stopAutoRescan()
    }

    // MARK: - FSEvents wiring
    func startAutoRescan() {
        guard fsEventStream == nil else { return }

        let pathsToWatch: [String] = applicationSearchPaths
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(
                Unmanaged.passUnretained(self).toOpaque()
            ),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = {
            (_, clientInfo, numEvents, eventPaths, eventFlags, _) in
            guard let info = clientInfo else { return }
            let appStore = Unmanaged<AppStore>.fromOpaque(info)
                .takeUnretainedValue()

            guard numEvents > 0 else {
                appStore.handleFSEvents(
                    paths: [],
                    flagsPointer: eventFlags,
                    count: 0
                )
                return
            }

            // With kFSEventStreamCreateFlagUseCFTypes, eventPaths is a CFArray of CFString
            let cfArray = Unmanaged<CFArray>.fromOpaque(eventPaths)
                .takeUnretainedValue()
            let nsArray = cfArray as NSArray
            guard let pathsArray = nsArray as? [String] else { return }

            appStore.handleFSEvents(
                paths: pathsArray,
                flagsPointer: eventFlags,
                count: numEvents
            )
        }

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
                | kFSEventStreamCreateFlagUseCFTypes
        )
        let latency: CFTimeInterval = 0.0

        guard
            let stream = FSEventStreamCreate(
                kCFAllocatorDefault,
                callback,
                &context,
                pathsToWatch as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                latency,
                flags
            )
        else {
            return
        }

        fsEventStream = stream
        FSEventStreamSetDispatchQueue(stream, fsEventsQueue)
        FSEventStreamStart(stream)
    }

    func stopAutoRescan() {
        guard let stream = fsEventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        fsEventStream = nil
    }

    private func handleFSEvents(
        paths: [String],
        flagsPointer: UnsafePointer<FSEventStreamEventFlags>?,
        count: Int
    ) {
        let maxCount = min(paths.count, count)
        var localForceFull = false

        for i in 0..<maxCount {
            let rawPath = paths[i]
            let flags = flagsPointer?[i] ?? 0

            let created =
                (flags
                    & FSEventStreamEventFlags(
                        kFSEventStreamEventFlagItemCreated
                    )) != 0
            let removed =
                (flags
                    & FSEventStreamEventFlags(
                        kFSEventStreamEventFlagItemRemoved
                    )) != 0
            let renamed =
                (flags
                    & FSEventStreamEventFlags(
                        kFSEventStreamEventFlagItemRenamed
                    )) != 0
            let modified =
                (flags
                    & FSEventStreamEventFlags(
                        kFSEventStreamEventFlagItemModified
                    )) != 0
            let isDir =
                (flags
                    & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir))
                != 0

            if isDir && (created || removed || renamed),
                applicationSearchPaths.contains(where: { rawPath.hasPrefix($0) }
                )
            {
                localForceFull = true
                break
            }

            guard let appBundlePath = self.canonicalAppBundlePath(for: rawPath)
            else { continue }
            if created || removed || renamed || modified {
                pendingChangedAppPaths.insert(appBundlePath)
            }
        }

        if localForceFull { pendingForceFullScan = true }
        scheduleRescan()
    }

    private func scheduleRescan() {
        // Light debounce to reduce main-thread pressure from frequent FSEvents
        rescanWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performImmediateRefresh()
        }
        rescanWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func performImmediateRefresh() {
        if pendingForceFullScan
            || pendingChangedAppPaths.count > fullRescanThreshold
        {
            pendingForceFullScan = false
            pendingChangedAppPaths.removeAll()
            scanApplications()
            return
        }

        let changed = pendingChangedAppPaths
        pendingChangedAppPaths.removeAll()

        if !changed.isEmpty {
            applyIncrementalChanges(for: changed)
        }
    }

    private func applyIncrementalChanges(for changedPaths: Set<String>) {
        guard !changedPaths.isEmpty else { return }

        // Move disk and icon parsing to background; apply results on main to reduce jank
        let snapshotApps = self.apps
        refreshQueue.async { [weak self] in
            guard let self else { return }

            enum PendingChange {
                case insert(AppInfo)
                case update(AppInfo)
                case remove(String)  // path
            }
            var changes: [PendingChange] = []
            var pathToIndex: [String: Int] = [:]
            for (idx, app) in snapshotApps.enumerated() {
                pathToIndex[app.url.path] = idx
            }

            for path in changedPaths {
                let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
                let exists = FileManager.default.fileExists(atPath: url.path)
                let valid =
                    exists && self.isValidApp(at: url)
                    && !self.isInsideAnotherApp(url)
                if valid {
                    let info = self.appInfo(from: url)
                    if pathToIndex[url.path] != nil {
                        changes.append(.update(info))
                    } else {
                        changes.append(.insert(info))
                    }
                } else {
                    changes.append(.remove(url.path))
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                // Apply removals
                if changes.contains(where: {
                    if case .remove = $0 { return true } else { return false }
                }) {
                    var indicesToRemove: [Int] = []
                    var map: [String: Int] = [:]
                    for (idx, app) in self.apps.enumerated() {
                        map[app.url.path] = idx
                    }
                    for change in changes {
                        if case .remove(let path) = change, let idx = map[path]
                        {
                            indicesToRemove.append(idx)
                        }
                    }
                    for idx in indicesToRemove.sorted(by: >) {
                        let removed = self.apps.remove(at: idx)
                        for fIdx in self.folders.indices {
                            self.folders[fIdx].apps.removeAll { $0 == removed }
                        }
                        if !self.items.isEmpty {
                            for i in 0..<self.items.count {
                                if case .app(let a) = self.items[i],
                                    a == removed
                                {
                                    self.items[i] = .empty(UUID().uuidString)
                                }
                            }
                        }
                    }
                    self.compactItemsWithinPages()
                    self.rebuildItems()
                }

                // Apply updates
                let updates: [AppInfo] = changes.compactMap {
                    if case .update(let info) = $0 {
                        return info
                    } else {
                        return nil
                    }
                }
                if !updates.isEmpty {
                    var map: [String: Int] = [:]
                    for (idx, app) in self.apps.enumerated() {
                        map[app.url.path] = idx
                    }
                    for info in updates {
                        if let idx = map[info.url.path],
                            self.apps.indices.contains(idx)
                        {
                            self.apps[idx] = info
                        }
                        for fIdx in self.folders.indices {
                            for aIdx in self.folders[fIdx].apps.indices
                            where self.folders[fIdx].apps[aIdx].url.path
                                == info.url.path
                            {
                                self.folders[fIdx].apps[aIdx] = info
                            }
                        }
                        for iIdx in self.items.indices {
                            if case .app(let a) = self.items[iIdx],
                                a.url.path == info.url.path
                            {
                                self.items[iIdx] = .app(info)
                            }
                        }
                    }
                    self.rebuildItems()
                }

                // Apply inserts
                let inserts: [AppInfo] = changes.compactMap {
                    if case .insert(let info) = $0 {
                        return info
                    } else {
                        return nil
                    }
                }
                if !inserts.isEmpty {
                    self.apps.append(contentsOf: inserts)
                    self.apps.sort {
                        $0.name.localizedCaseInsensitiveCompare($1.name)
                            == .orderedAscending
                    }
                    self.rebuildItems()
                }

                // Refresh and persist
                self.triggerFolderUpdate()
                self.triggerGridRefresh()
                self.saveAllOrder()
                self.updateCacheAfterChanges()
            }
        }
    }

    private func canonicalAppBundlePath(for rawPath: String) -> String? {
        guard let range = rawPath.range(of: ".app") else { return nil }
        let end = rawPath.index(range.lowerBound, offsetBy: 4)
        let bundlePath = String(rawPath[..<end])
        return bundlePath
    }

    private func isInsideAnotherApp(_ url: URL) -> Bool {
        let appCount = url.pathComponents.filter { $0.hasSuffix(".app") }.count
        return appCount > 1
    }

    private func isValidApp(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
            && NSWorkspace.shared.isFilePackage(atPath: url.path)
    }

    private func appInfo(from url: URL, preferredName: String? = nil) -> AppInfo
    {
        AppInfo.from(
            url: url,
            preferredName: preferredName,
            customTitle: customTitles[url.path]
        )
    }

    // MARK: - Folder management
    func createFolder(with apps: [AppInfo], name: String = "Untitled")
        -> FolderInfo
    {
        return createFolder(with: apps, name: name, insertAt: nil)
    }

    func createFolder(
        with apps: [AppInfo],
        name: String = "Untitled",
        insertAt insertIndex: Int?
    ) -> FolderInfo {
        let folder = FolderInfo(name: name, apps: apps)
        folders.append(folder)

        // Remove apps that were added to the folder from the top-level app list
        for app in apps {
            if let index = self.apps.firstIndex(of: app) {
                self.apps.remove(at: index)
            }
        }

        // In the current items: replace those apps' top-level entries with empty slots and place the folder at the target position, keeping total length unchanged
        var newItems = self.items
        // Find positions of these apps
        var indices: [Int] = []
        for (idx, item) in newItems.enumerated() {
            if case .app(let a) = item, apps.contains(a) { indices.append(idx) }
            if indices.count == apps.count { break }
        }
        // Set involved app slots to empty first
        for idx in indices { newItems[idx] = .empty(UUID().uuidString) }
        // Choose folder placement: prefer insertIndex, otherwise the minimum index; clamp within range and use replacement instead of insertion
        let baseIndex =
            indices.min()
            ?? min(
                newItems.count - 1,
                max(0, insertIndex ?? (newItems.count - 1))
            )
        let desiredIndex = insertIndex ?? baseIndex
        let safeIndex = min(max(0, desiredIndex), max(0, newItems.count - 1))
        if newItems.isEmpty {
            newItems = [.folder(folder)]
        } else {
            newItems[safeIndex] = .folder(folder)
        }
        self.items = filteredItemsRemovingHidden(from: newItems)
        // Auto-compact within page: move empty slots to the page end
        compactItemsWithinPages()

        // Trigger folder update to refresh icons in all relevant views
        DispatchQueue.main.async { [weak self] in
            self?.triggerFolderUpdate()
        }

        // Trigger grid refresh to update UI immediately
        triggerGridRefresh()

        // Refresh caches so search can find apps in the newly created folder
        refreshCacheAfterFolderOperation()

        saveAllOrder()
        return folder
    }

    func addAppToFolder(_ app: AppInfo, folder: FolderInfo) {
        guard let folderIndex = folders.firstIndex(of: folder) else { return }

        // Create a new FolderInfo instance so SwiftUI detects the change
        var updatedFolder = folders[folderIndex]
        updatedFolder.apps.append(app)
        folders[folderIndex] = updatedFolder

        // Remove from the app list
        if let appIndex = apps.firstIndex(of: app) {
            apps.remove(at: appIndex)
        }

        // Set the top-level slot of this app to empty (keep page independence)
        if let pos = items.firstIndex(of: .app(app)) {
            items[pos] = .empty(UUID().uuidString)
            // Auto-compact within page
            compactItemsWithinPages()
        } else {
            // If not found, fall back to rebuilding
            rebuildItems()
        }

        // Ensure the corresponding folder entry in items is updated for immediate search visibility
        for idx in items.indices {
            if case .folder(let f) = items[idx], f.id == updatedFolder.id {
                items[idx] = .folder(updatedFolder)
            }
        }

        // Immediately trigger folder update so all related views refresh names and icons
        triggerFolderUpdate()

        // Trigger grid refresh to update UI immediately
        triggerGridRefresh()

        // Refresh caches so search finds the newly added app
        refreshCacheAfterFolderOperation()

        saveAllOrder()
    }

    func removeAppFromFolder(_ app: AppInfo, folder: FolderInfo) {
        guard let folderIndex = folders.firstIndex(of: folder) else { return }

        // Create a new FolderInfo instance so SwiftUI detects the change
        var updatedFolder = folders[folderIndex]
        updatedFolder.apps.removeAll { $0 == app }

        // If the folder becomes empty, delete it
        if updatedFolder.apps.isEmpty {
            folders.remove(at: folderIndex)
        } else {
            // Update folder
            folders[folderIndex] = updatedFolder
        }

        // Synchronize the folder entry in items to avoid referencing stale content
        for idx in items.indices {
            if case .folder(let f) = items[idx], f.id == folder.id {
                if updatedFolder.apps.isEmpty {
                    // Folder is empty and was deleted; mark this position as empty and wait for later compaction
                    items[idx] = .empty(UUID().uuidString)
                } else {
                    items[idx] = .folder(updatedFolder)
                }
            }
        }

        // Re-add the app to the app list
        apps.append(app)
        apps.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name)
                == .orderedAscending
        }

        // Try placing the app into the first empty slot in items to avoid temporary blanks
        if let emptyIndex = items.firstIndex(where: {
            if case .empty = $0 { return true } else { return false }
        }) {
            items[emptyIndex] = .app(app)
        }

        // Immediately trigger folder update so all related views refresh names and icons
        triggerFolderUpdate()

        // Trigger grid refresh to update UI immediately
        triggerGridRefresh()

        // Do not call rebuildItems() because it moves the app to the end
        // Compact within the page directly to keep the app on the first page
        compactItemsWithinPages()

        // Refresh caches so search can find the app removed from the folder (after rebuild)
        refreshCacheAfterFolderOperation()

        saveAllOrder()
    }

    func renameFolder(_ folder: FolderInfo, newName: String) {
        guard let index = folders.firstIndex(of: folder) else { return }

        // Create a new FolderInfo instance so SwiftUI detects the change
        var updatedFolder = folders[index]
        updatedFolder.name = newName
        folders[index] = updatedFolder

        // Synchronize the folder entry in items to avoid the main grid showing the old name
        for idx in items.indices {
            if case .folder(let f) = items[idx], f.id == updatedFolder.id {
                items[idx] = .folder(updatedFolder)
            }
        }

        // Immediately trigger folder update so all related views refresh
        triggerFolderUpdate()

        // Trigger grid refresh to update UI immediately
        triggerGridRefresh()

        // Refresh caches to ensure search works correctly
        refreshCacheAfterFolderOperation()

        rebuildItems()
        saveAllOrder()
    }

    // One-click layout reset: fully rescan apps and remove all folders, ordering, and empty fillers
    func resetLayout() {
        // Close any open folder
        openFolder = nil

        // Clear all folders and ordering data
        folders.removeAll()

        // Clear all persisted ordering data
        clearAllPersistedData()

        // Clear caches
        cacheManager.clearAllCaches()

        // Reset scan flags to force a rescan
        hasPerformedInitialScan = false

        // Clear current item list
        items.removeAll()

        // Rescan apps without loading persisted data
        scanApplications(loadPersistedOrder: false)

        // Reset to the first page
        currentPage = 0

        // Trigger folder update so all related views refresh
        triggerFolderUpdate()

        // Trigger grid refresh to update UI immediately
        triggerGridRefresh()

        // Refresh caches after the scan finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshCacheAfterFolderOperation()
        }
    }

    /// Auto-compact within a page: move .empty slots to the end while preserving non-empty order
    func compactItemsWithinPages() {
        guard !items.isEmpty else { return }
        let itemsPerPage = self.itemsPerPage  // Use computed property
        var result: [LaunchpadItem] = []
        result.reserveCapacity(items.count)
        var index = 0
        while index < items.count {
            let end = min(index + itemsPerPage, items.count)
            let pageSlice = Array(items[index..<end])
            let nonEmpty = pageSlice.filter {
                if case .empty = $0 { return false } else { return true }
            }
            let emptyCount = pageSlice.count - nonEmpty.count

            // Append non-empty items first, preserving order
            result.append(contentsOf: nonEmpty)

            // Then append empty items to the page end
            if emptyCount > 0 {
                var empties: [LaunchpadItem] = []
                empties.reserveCapacity(emptyCount)
                for _ in 0..<emptyCount {
                    empties.append(.empty(UUID().uuidString))
                }
                result.append(contentsOf: empties)
            }

            index = end
        }
        items = filteredItemsRemovingHidden(from: result)
    }

    // MARK: - Cross-page drag: cascade insert (if page full, push last into next page)
    func moveItemAcrossPagesWithCascade(
        item: LaunchpadItem,
        to targetIndex: Int
    ) {
        guard items.indices.contains(targetIndex) || targetIndex == items.count
        else {
            return
        }
        guard let source = items.firstIndex(of: item) else { return }
        var result = items
        // Clear the source position to empty, keeping length
        result[source] = .empty(UUID().uuidString)
        // Perform cascade insert
        result = cascadeInsert(into: result, item: item, at: targetIndex)
        items = filteredItemsRemovingHidden(from: result)

        // After each drag, compact to ensure empty items move to the end of their page
        let targetPage = targetIndex / itemsPerPage
        let currentPages = (items.count + itemsPerPage - 1) / itemsPerPage

        if targetPage == currentPages - 1 {
            // Dragged to a new page: delay compaction to stabilize app position
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.compactItemsWithinPages()
                self.triggerGridRefresh()
            }
        } else {
            // Dragged within an existing page: compact immediately
            compactItemsWithinPages()
        }

        // Trigger grid refresh to update UI immediately
        triggerGridRefresh()

        saveAllOrder()
    }

    private func cascadeInsert(
        into array: [LaunchpadItem],
        item: LaunchpadItem,
        at targetIndex: Int
    ) -> [LaunchpadItem] {
        var result = array
        let p = self.itemsPerPage  // Use computed property

        // Ensure the length is padded to full pages for easier processing
        if result.count % p != 0 {
            let remain = p - (result.count % p)
            for _ in 0..<remain { result.append(.empty(UUID().uuidString)) }
        }

        var currentPage = max(0, targetIndex / p)
        var localIndex = max(0, min(targetIndex - currentPage * p, p - 1))
        var carry: LaunchpadItem? = item

        while let moving = carry {
            let pageStart = currentPage * p
            let pageEnd = pageStart + p
            if result.count < pageEnd {
                let need = pageEnd - result.count
                for _ in 0..<need { result.append(.empty(UUID().uuidString)) }
            }
            var slice = Array(result[pageStart..<pageEnd])

            // Ensure the insertion position is within valid bounds
            let safeLocalIndex = max(0, min(localIndex, slice.count))
            slice.insert(moving, at: safeLocalIndex)

            var spilled: LaunchpadItem? = nil
            if slice.count > p {
                spilled = slice.removeLast()
            }
            result.replaceSubrange(pageStart..<pageEnd, with: slice)
            if let s = spilled, case .empty = s {
                // If spill is empty: stop
                carry = nil
            } else if let s = spilled {
                // If spill is non-empty: push to the next page head
                carry = s
                currentPage += 1
                localIndex = 0
                // If exceeding the last page length, pad the next page
                let nextEnd = (currentPage + 1) * p
                if result.count < nextEnd {
                    let need = nextEnd - result.count
                    for _ in 0..<need {
                        result.append(.empty(UUID().uuidString))
                    }
                }
            } else {
                carry = nil
            }
        }
        return result
    }

    func rebuildItems() {
    // Add debouncing and optimization checks
        let currentItemsCount = items.count
        let appsInFolders: Set<AppInfo> = Set(folders.flatMap { $0.apps })
        let folderById: [String: FolderInfo] = Dictionary(
            uniqueKeysWithValues: folders.map { ($0.id, $0) }
        )

        var newItems: [LaunchpadItem] = []
        newItems.reserveCapacity(currentItemsCount + 10)  // Pre-allocate capacity
        var seenAppPaths = Set<String>()
        var seenFolderIds = Set<String>()
        seenAppPaths.reserveCapacity(apps.count)
        seenFolderIds.reserveCapacity(folders.count)

        for item in items {
            switch item {
            case .folder(let folder):
                if let updated = folderById[folder.id] {
                    newItems.append(.folder(updated))
                    seenFolderIds.insert(updated.id)
                }
            // Skip if the folder was deleted (do not retain)
            case .app(let app):
                // If the app entered a folder, remove it from the top level; otherwise keep its position
                if !appsInFolders.contains(app) {
                    newItems.append(.app(app))
                    seenAppPaths.insert(app.url.path)
                }
            case .empty(let token):
                // Keep empty as placeholder to maintain page independence
                newItems.append(.empty(token))
            }
        }

        // Append missed free apps (not at top level and not in any folder)
        let missingFreeApps = apps.filter {
            !appsInFolders.contains($0) && !seenAppPaths.contains($0.url.path)
        }
        newItems.append(contentsOf: missingFreeApps.map { .app($0) })

        // Note: Do not automatically append missing folders to the end to avoid pushing folders to the last page after loading persisted order and triggering rebuilds

        // Update items only when there are actual changes
        if newItems.count != items.count
            || !newItems.elementsEqual(items, by: { $0.id == $1.id })
        {
            items = filteredItemsRemovingHidden(from: newItems)
        }
    }

    // MARK: - Persistence: per-page independent order (new) + backward compatibility
    func loadAllOrder() {
        guard let modelContext else {
            print(
                "LaunchOne: ModelContext is nil, cannot load persisted order"
            )
            return
        }

        print("LaunchOne: Attempting to load persisted order data...")

        // Prefer reading from the new "page-slot" model
        if loadOrderFromPageEntries(using: modelContext) {
            print("LaunchOne: Successfully loaded order from PageEntryData")
            return
        }

        print(
            "LaunchOne: PageEntryData not found, trying legacy TopItemData..."
        )
        // Fallback: legacy global order model
        loadOrderFromLegacyTopItems(using: modelContext)
        print("LaunchOne: Finished loading order from legacy data")
    }

    private func loadOrderFromPageEntries(using modelContext: ModelContext)
        -> Bool
    {
        do {
            let descriptor = FetchDescriptor<PageEntryData>(
                sortBy: [
                    SortDescriptor(\.pageIndex, order: .forward),
                    SortDescriptor(\.position, order: .forward),
                ]
            )
            let saved = try modelContext.fetch(descriptor)
            guard !saved.isEmpty else { return false }

            // Build folders: by first appearance order
            var folderMap: [String: FolderInfo] = [:]
            var foldersInOrder: [FolderInfo] = []

            // Collect all folders' appPaths first to avoid duplicate construction
            for row in saved where row.kind == "folder" {
                guard let fid = row.folderId else { continue }
                if folderMap[fid] != nil { continue }

                let folderApps: [AppInfo] = row.appPaths.compactMap { path in
                    if let existing = apps.first(where: { $0.url.path == path })
                    {
                        return existing
                    }
                    let url = URL(fileURLWithPath: path)
                    guard FileManager.default.fileExists(atPath: url.path)
                    else { return nil }
                    return self.appInfo(from: url)
                }
                let folder = FolderInfo(
                    id: fid,
                    name: row.folderName ?? "Untitled",
                    apps: folderApps,
                    createdAt: row.createdAt
                )
                folderMap[fid] = folder
                foldersInOrder.append(folder)
            }

            let folderAppPathSet: Set<String> = Set(
                foldersInOrder.flatMap { $0.apps.map { $0.url.path } }
            )

            // Compose top-level items (by page and position; keep empty to maintain per-page independent slots)
            var combined: [LaunchpadItem] = []
            combined.reserveCapacity(saved.count)
            for row in saved {
                switch row.kind {
                case "folder":
                    if let fid = row.folderId, let folder = folderMap[fid] {
                        combined.append(.folder(folder))
                    }
                case "app":
                    if let path = row.appPath, !folderAppPathSet.contains(path)
                    {
                        if let existing = apps.first(where: {
                            $0.url.path == path
                        }) {
                            combined.append(.app(existing))
                        } else {
                            let url = URL(fileURLWithPath: path)
                            if FileManager.default.fileExists(atPath: url.path)
                            {
                                combined.append(.app(self.appInfo(from: url)))
                            }
                        }
                    }
                case "empty":
                    combined.append(.empty(row.slotId))
                default:
                    break
                }
            }

            DispatchQueue.main.async {
                self.folders = self.sanitizedFolders(foldersInOrder)
                if !combined.isEmpty {
                    self.items = self.filteredItemsRemovingHidden(
                        from: combined
                    )
                    // If the app list is empty, restore it from persisted data
                    if self.apps.isEmpty {
                        let freeApps: [AppInfo] = combined.compactMap {
                            if case .app(let a) = $0 {
                                return a
                            } else {
                                return nil
                            }
                        }
                        self.apps = freeApps
                        self.pruneHiddenAppsFromAppList()
                    }
                }
                self.hasAppliedOrderFromStore = true
            }
            return true
        } catch {
            return false
        }
    }

    private func loadOrderFromLegacyTopItems(using modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<TopItemData>(sortBy: [
                SortDescriptor(\.orderIndex, order: .forward)
            ])
            let saved = try modelContext.fetch(descriptor)
            guard !saved.isEmpty else { return }

            var folderMap: [String: FolderInfo] = [:]
            var foldersInOrder: [FolderInfo] = []
            let folderAppPathSet: Set<String> = Set(
                saved.filter { $0.kind == "folder" }.flatMap { $0.appPaths }
            )
            for row in saved where row.kind == "folder" {
                let folderApps: [AppInfo] = row.appPaths.compactMap { path in
                    if let existing = apps.first(where: { $0.url.path == path })
                    {
                        return existing
                    }
                    let url = URL(fileURLWithPath: path)
                    guard FileManager.default.fileExists(atPath: url.path)
                    else { return nil }
                    return self.appInfo(from: url)
                }
                let folder = FolderInfo(
                    id: row.id,
                    name: row.folderName ?? "Untitled",
                    apps: folderApps,
                    createdAt: row.createdAt
                )
                folderMap[row.id] = folder
                foldersInOrder.append(folder)
            }

            var combined: [LaunchpadItem] = saved.sorted {
                $0.orderIndex < $1.orderIndex
            }.compactMap { row in
                if row.kind == "folder" {
                    return folderMap[row.id].map { .folder($0) }
                }
                if row.kind == "empty" { return .empty(row.id) }
                if row.kind == "app", let path = row.appPath {
                    if folderAppPathSet.contains(path) { return nil }
                    if let existing = apps.first(where: { $0.url.path == path })
                    {
                        return .app(existing)
                    }
                    let url = URL(fileURLWithPath: path)
                    guard FileManager.default.fileExists(atPath: url.path)
                    else { return nil }
                    return .app(self.appInfo(from: url))
                }
                return nil
            }

            let appsInFolders = Set(foldersInOrder.flatMap { $0.apps })
            let appsInCombined: Set<AppInfo> = Set(
                combined.compactMap {
                    if case .app(let a) = $0 { return a } else { return nil }
                }
            )
            let missingFreeApps =
                apps
                .filter {
                    !appsInFolders.contains($0) && !appsInCombined.contains($0)
                }
                .map { LaunchpadItem.app($0) }
            combined.append(contentsOf: missingFreeApps)

            DispatchQueue.main.async {
                self.folders = self.sanitizedFolders(foldersInOrder)
                if !combined.isEmpty {
                    self.items = self.filteredItemsRemovingHidden(
                        from: combined
                    )
                    // If the app list is empty, restore it from persisted data
                    if self.apps.isEmpty {
                        let freeAppsAfterLoad: [AppInfo] = combined.compactMap {
                            if case .app(let a) = $0 {
                                return a
                            } else {
                                return nil
                            }
                        }
                        self.apps = freeAppsAfterLoad
                        self.pruneHiddenAppsFromAppList()
                    }
                }
                self.hasAppliedOrderFromStore = true
            }
        } catch {
            // ignore
        }
    }

    func saveAllOrder() {
        guard let modelContext else {
            print("LaunchOne: ModelContext is nil, cannot save order")
            return
        }
        guard !items.isEmpty else {
            print("LaunchOne: Items list is empty, skipping save")
            return
        }

        print("LaunchOne: Saving order data for \(items.count) items...")

        // Write the new model: by page-slot
        do {
            let existing = try modelContext.fetch(
                FetchDescriptor<PageEntryData>()
            )
            print(
                "LaunchOne: Found \(existing.count) existing entries, clearing..."
            )
            for row in existing { modelContext.delete(row) }

            // Build a lookup table for folders
            let folderById: [String: FolderInfo] = Dictionary(
                uniqueKeysWithValues: folders.map { ($0.id, $0) }
            )
            let itemsPerPage = self.itemsPerPage  // Use computed property

            for (idx, item) in items.enumerated() {
                let pageIndex = idx / itemsPerPage
                let position = idx % itemsPerPage
                let slotId = "page-\(pageIndex)-pos-\(position)"
                switch item {
                case .folder(let folder):
                    let authoritativeFolder = folderById[folder.id] ?? folder
                    let row = PageEntryData(
                        slotId: slotId,
                        pageIndex: pageIndex,
                        position: position,
                        kind: "folder",
                        folderId: authoritativeFolder.id,
                        folderName: authoritativeFolder.name,
                        appPaths: authoritativeFolder.apps.map { $0.url.path }
                    )
                    modelContext.insert(row)
                case .app(let app):
                    let row = PageEntryData(
                        slotId: slotId,
                        pageIndex: pageIndex,
                        position: position,
                        kind: "app",
                        appPath: app.url.path
                    )
                    modelContext.insert(row)
                case .empty:
                    let row = PageEntryData(
                        slotId: slotId,
                        pageIndex: pageIndex,
                        position: position,
                        kind: "empty"
                    )
                    modelContext.insert(row)
                }
            }
            try modelContext.save()
            print("LaunchOne: Successfully saved order data")

            // Cleanup legacy tables to save space (ignore errors)
            do {
                let legacy = try modelContext.fetch(
                    FetchDescriptor<TopItemData>()
                )
                for row in legacy { modelContext.delete(row) }
                try? modelContext.save()
            } catch {}
        } catch {
            print("LaunchOne: Error saving order data: \(error)")
        }
    }

    // Trigger folder update to refresh icons in all relevant views
    private func triggerFolderUpdate() {
        folderUpdateTrigger = UUID()
    }

    // Trigger grid refresh to update UI after drag operations
    func triggerGridRefresh(force: Bool = false) {
        // Smart refresh: skip if transitioning and not forced refresh
        if !force && isTransitioning {
            return
        }
        clampCurrentPageWithinBounds()
        gridRefreshTrigger = UUID()
    }

    // Clear all persisted ordering and folder data
    private func clearAllPersistedData() {
        guard let modelContext else { return }

        do {
            // Clear new page-slot data
            let pageEntries = try modelContext.fetch(
                FetchDescriptor<PageEntryData>()
            )
            for entry in pageEntries {
                modelContext.delete(entry)
            }

            // Clear legacy global order data
            let legacyEntries = try modelContext.fetch(
                FetchDescriptor<TopItemData>()
            )
            for entry in legacyEntries {
                modelContext.delete(entry)
            }

            // Save changes
            try modelContext.save()
        } catch {
            // Ignore errors to ensure the reset process continues
        }
    }

    private func clampCurrentPageWithinBounds() {
        let perPage = max(itemsPerPage, 1)
        let maxPageIndex =
            items.isEmpty ? 0 : max(0, (items.count - 1) / perPage)
        if currentPage > maxPageIndex {
            currentPage = maxPageIndex
        }
    }

    // MARK: - Auto-create new page during drag
    private var pendingNewPage: (pageIndex: Int, itemCount: Int)? = nil

    func createNewPageForDrag() -> Bool {
        let itemsPerPage = self.itemsPerPage
        let currentPages = (items.count + itemsPerPage - 1) / itemsPerPage
        let newPageIndex = currentPages

        // Add empty placeholders for the new page
        for _ in 0..<itemsPerPage {
            items.append(.empty(UUID().uuidString))
        }

        // Record pending new page info
        pendingNewPage = (pageIndex: newPageIndex, itemCount: itemsPerPage)

        // Trigger grid refresh
        triggerGridRefresh()

        return true
    }

    func cleanupUnusedNewPage() {
        guard let pending = pendingNewPage else { return }

        // Check whether the new page was used (contains non-empty items)
        let pageStart = pending.pageIndex * pending.itemCount
        let pageEnd = min(pageStart + pending.itemCount, items.count)

        if pageStart < items.count {
            let pageSlice = Array(items[pageStart..<pageEnd])
            let hasNonEmptyItems = pageSlice.contains { item in
                if case .empty = item { return false } else { return true }
            }

            if !hasNonEmptyItems {
                // New page not used; delete it
                items.removeSubrange(pageStart..<pageEnd)

                // Trigger grid refresh
                triggerGridRefresh()
            }
        }

        // Clear pending info
        pendingNewPage = nil
    }

    // MARK: - Auto-delete blank pages
    /// Automatically delete blank pages: remove pages filled entirely with empty slots
    func removeEmptyPages() {
        guard !items.isEmpty else { return }
        let itemsPerPage = self.itemsPerPage

        var newItems: [LaunchpadItem] = []
        var index = 0

        while index < items.count {
            let end = min(index + itemsPerPage, items.count)
            let pageSlice = Array(items[index..<end])

            // Check whether the current page is entirely empty
            let isEmptyPage = pageSlice.allSatisfy { item in
                if case .empty = item { return true } else { return false }
            }

            // If not a blank page, keep its content
            if !isEmptyPage {
                newItems.append(contentsOf: pageSlice)
            }
            // If it is blank, skip (do not add it)

            index = end
        }

        // Update items only when blank pages were actually deleted
        if newItems.count != items.count {
            items = filteredItemsRemovingHidden(from: newItems)

            // After deleting blank pages, ensure the current page index is within range
            let maxPageIndex = max(0, (items.count - 1) / itemsPerPage)
            if currentPage > maxPageIndex {
                currentPage = maxPageIndex
            }

            // Trigger grid refresh
            triggerGridRefresh()
        }
    }

    private func handleGridConfigurationChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.compactItemsWithinPages()
            self.removeEmptyPages()
            self.cleanupUnusedNewPage()
            let maxPageIndex = max(
                0,
                (self.items.count - 1) / max(self.itemsPerPage, 1)
            )
            if self.currentPage > maxPageIndex {
                self.currentPage = maxPageIndex
            }
            self.triggerGridRefresh()
            self.cacheManager.refreshCache(
                from: self.apps,
                items: self.items,
                itemsPerPage: self.itemsPerPage,
                columns: self.gridColumnsPerPage,
                rows: self.gridRowsPerPage
            )
            if self.rememberLastPage {
                UserDefaults.standard.set(
                    self.currentPage,
                    forKey: Self.rememberedPageIndexKey
                )
            }
            self.saveAllOrder()
        }
    }

    // MARK: - Export app ordering
    /// Export app ordering in JSON format
    func exportAppOrderAsJSON() -> String? {
        let exportData = buildExportData()

        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: exportData,
                options: [.prettyPrinted, .sortedKeys]
            )
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Build export data
    private func buildExportData() -> [String: Any] {
        var pages: [[String: Any]] = []
        let itemsPerPage = self.itemsPerPage

        for (index, item) in items.enumerated() {
            let pageIndex = index / itemsPerPage
            let position = index % itemsPerPage

            var itemData: [String: Any] = [
                "pageIndex": pageIndex,
                "position": position,
                "kind": itemKind(for: item),
                "name": item.name,
                "path": itemPath(for: item),
                "folderApps": [],
            ]

            // If it's a folder, include the apps inside
            if case .folder(let folder) = item {
                itemData["folderApps"] = folder.apps.map { $0.name }
                itemData["folderAppPaths"] = folder.apps.map { $0.url.path }
            }

            pages.append(itemData)
        }

        return [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "totalPages": (items.count + itemsPerPage - 1) / itemsPerPage,
            "totalItems": items.count,
            "fullscreenMode": isFullscreenMode,
            "pages": pages,
        ]
    }

    /// Get item type description
    private func itemKind(for item: LaunchpadItem) -> String {
        switch item {
        case .app:
            return "App"
        case .folder:
            return "Folder"
        case .empty:
            return "Empty Slot"
        }
    }

    /// Get item path description
    private func itemPath(for item: LaunchpadItem) -> String {
        switch item {
        case .app(let app):
            return app.url.path
        case .folder(let folder):
            return "Folder: \(folder.name)"
        case .empty:
            return "Empty Slot"
        }
    }

    /// Save the export file with the system save dialog
    func saveExportFileWithDialog(
        content: String,
        filename: String,
        fileExtension: String,
        fileType: String
    ) -> Bool {
        let savePanel = NSSavePanel()
        savePanel.title = "Save Export File"
        savePanel.nameFieldStringValue = filename
        savePanel.allowedContentTypes = [
            UTType(filenameExtension: fileExtension) ?? .plainText
        ]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false

        // Set default save location to Desktop
        if let desktopURL = FileManager.default.urls(
            for: .desktopDirectory,
            in: .userDomainMask
        ).first {
            savePanel.directoryURL = desktopURL
        }

        let response = savePanel.runModal()
        if response == .OK, let url = savePanel.url {
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                return true
            } catch {
                return false
            }
        }
        return false
    }

    // MARK: - Cache management

    /// Generate caches after scanning completes
    private func generateCacheAfterScan() {

        // Check whether the cache is valid
        if !cacheManager.isCacheValid {
            // Generate new caches
            cacheManager.generateCache(
                from: apps,
                items: items,
                itemsPerPage: itemsPerPage,
                columns: gridColumnsPerPage,
                rows: gridRowsPerPage
            )
        } else {
            // Cache is valid, but icons can be preloaded
            let appPaths = apps.map { $0.url.path }
            cacheManager.preloadIcons(for: appPaths)
        }

        cacheManager.smartPreloadIcons(
            for: items,
            currentPage: currentPage,
            itemsPerPage: itemsPerPage
        )

        if isInitialLoading {
            isInitialLoading = false
        }
    }

    /// Manual refresh (simulate full first-launch flow)
    func refresh() {
        print("LaunchOne: Manual refresh triggered")

        // Clear caches to regenerate icons and search index
        cacheManager.clearAllCaches()

        // Reset UI and state to approximate a "first launch"
        openFolder = nil
        currentPage = 0
        if !searchText.isEmpty { searchText = "" }

        // Do not reset hasAppliedOrderFromStore to keep layout data
        hasPerformedInitialScan = true

        // Perform the same scan path as first launch (preserve order, new apps at end)
        scanApplicationsWithOrderPreservation()

        // Generate caches after scan completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.generateCacheAfterScan()
        }

        // Force UI refresh
        triggerFolderUpdate()
        triggerGridRefresh()
    }

    /// Clear caches
    func clearCache() {
        cacheManager.clearAllCaches()
    }

    /// Get cache statistics
    var cacheStatistics: CacheStatistics {
        return cacheManager.cacheStatistics
    }

    /// Update caches after incremental updates
    private func updateCacheAfterChanges() {
        // Check whether caches need updating
        if !cacheManager.isCacheValid {
            // Cache invalid — regenerate
            cacheManager.generateCache(
                from: apps,
                items: items,
                itemsPerPage: itemsPerPage,
                columns: gridColumnsPerPage,
                rows: gridRowsPerPage
            )
        } else {
            // Cache valid — update changed parts only
            let changedAppPaths = apps.map { $0.url.path }
            cacheManager.preloadIcons(for: changedAppPaths)
        }
    }

    private var resolvedLanguage: AppLanguage {
        preferredLanguage == .system
            ? AppLanguage.resolveSystemDefault() : preferredLanguage
    }

    func localized(_ key: LocalizationKey) -> String {
        LocalizationManager.shared.localized(key, language: resolvedLanguage)
    }

    func localizedLanguageName(for language: AppLanguage) -> String {
        LocalizationManager.shared.languageDisplayName(
            for: language,
            displayLanguage: resolvedLanguage
        )
    }

    // MARK: - Hidden Apps

    @discardableResult
    func hideApp(_ app: AppInfo) -> Bool {
        hideApp(atPath: app.url.path)
    }

    @discardableResult
    func hideApp(at url: URL) -> Bool {
        let resolved = url.resolvingSymlinksInPath()
        guard
            resolved.pathExtension.caseInsensitiveCompare("app") == .orderedSame
        else { return false }
        guard FileManager.default.fileExists(atPath: resolved.path) else {
            return false
        }
        return hideApp(atPath: resolved.path)
    }

    @discardableResult
    func hideApp(atPath path: String) -> Bool {
        var didInsert = false
        updateHiddenAppPaths { set in
            if !set.contains(path) {
                set.insert(path)
                didInsert = true
            }
        }
        guard didInsert else { return false }

        removeHiddenAppMetadata(forPath: path)
        items = filteredItemsRemovingHidden(from: items)
        folders = sanitizedFolders(folders)
        applyHiddenFilteringToOpenFolder()
        compactItemsWithinPages()
        removeEmptyPages()
        triggerFolderUpdate()
        triggerGridRefresh()
        updateCacheAfterChanges()
        saveAllOrder()
        return true
    }

    func unhideApp(path: String) {
        var didRemove = false
        updateHiddenAppPaths { set in
            if set.remove(path) != nil {
                didRemove = true
            }
        }
        guard didRemove else { return }

        guard FileManager.default.fileExists(atPath: path) else {
            triggerFolderUpdate()
            triggerGridRefresh()
            return
        }

        let url = URL(fileURLWithPath: path)
        let info = appInfo(from: url)
        if !apps.contains(info) {
            apps.append(info)
            apps.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name)
                    == .orderedAscending
            }
        }

        rebuildItems()
        folders = sanitizedFolders(folders)
        applyHiddenFilteringToOpenFolder()
        compactItemsWithinPages()
        triggerFolderUpdate()
        triggerGridRefresh()
        updateCacheAfterChanges()
        saveAllOrder()
    }

    private func removeHiddenAppMetadata(forPath path: String) {
        if let index = apps.firstIndex(where: { $0.url.path == path }) {
            apps.remove(at: index)
        }
    }

    private func pruneHiddenAppsFromAppList() {
        guard !hiddenAppPaths.isEmpty else { return }
        apps.removeAll { hiddenAppPaths.contains($0.url.path) }
    }

    private func applyHiddenFilteringToOpenFolder() {
        guard let folder = openFolder else { return }
        let filtered = filteredFolderRemovingHidden(from: folder)
        if filtered.apps.count != folder.apps.count {
            openFolder = filtered
        }
    }

    private func sanitizedFolders(_ input: [FolderInfo]) -> [FolderInfo] {
        guard !hiddenAppPaths.isEmpty else { return input }
        let hidden = hiddenAppPaths
        var result: [FolderInfo] = []
        result.reserveCapacity(input.count)
        var didChange = false
        for folder in input {
            let filtered = filteredFolderRemovingHidden(
                from: folder,
                hidden: hidden
            )
            if filtered.apps.count != folder.apps.count {
                didChange = true
            }
            result.append(filtered)
        }
        return didChange ? result : input
    }

    private func filteredItemsRemovingHidden(from input: [LaunchpadItem])
        -> [LaunchpadItem]
    {
        guard !hiddenAppPaths.isEmpty else { return input }
        let hidden = hiddenAppPaths
        var result: [LaunchpadItem] = []
        result.reserveCapacity(input.count)
        var didChange = false
        for item in input {
            switch item {
            case .app(let app):
                if hidden.contains(app.url.path) {
                    didChange = true
                    continue
                }
                result.append(.app(app))
            case .folder(let folder):
                let filteredFolder = filteredFolderRemovingHidden(
                    from: folder,
                    hidden: hidden
                )
                if filteredFolder.apps.count != folder.apps.count {
                    didChange = true
                }
                result.append(.folder(filteredFolder))
            case .empty:
                result.append(item)
            }
        }
        return didChange ? result : input
    }

    private func filteredFolderRemovingHidden(from folder: FolderInfo)
        -> FolderInfo
    {
        filteredFolderRemovingHidden(from: folder, hidden: hiddenAppPaths)
    }

    private func filteredFolderRemovingHidden(
        from folder: FolderInfo,
        hidden: Set<String>
    ) -> FolderInfo {
        guard !hidden.isEmpty else { return folder }
        let filteredApps = folder.apps.filter { !hidden.contains($0.url.path) }
        if filteredApps.count == folder.apps.count {
            return folder
        }
        var copy = folder
        copy.apps = filteredApps
        return copy
    }

    // MARK: - Custom Titles

    func customTitle(for app: AppInfo) -> String {
        customTitles[app.url.path] ?? ""
    }

    func setCustomTitle(_ rawValue: String, for app: AppInfo) {
        let key = app.url.path
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            if customTitles[key] != nil {
                var updated = customTitles
                updated.removeValue(forKey: key)
                customTitles = updated
                applyCustomTitleOverride(for: app.url, title: nil)
            }
            return
        }

        if customTitles[key] == trimmed { return }

        var updated = customTitles
        updated[key] = trimmed
        customTitles = updated
        applyCustomTitleOverride(for: app.url, title: trimmed)
    }

    func clearCustomTitle(for app: AppInfo) {
        setCustomTitle("", for: app)
    }

    func appInfoForCustomTitle(path: String) -> AppInfo {
        if let existing = apps.first(where: { $0.url.path == path }) {
            return existing
        }

        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            return AppInfo.from(url: url, customTitle: customTitles[path])
        }

        let fallbackName =
            customTitles[path] ?? url.deletingPathExtension().lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return AppInfo(name: fallbackName, icon: icon, url: url)
    }

    func defaultDisplayName(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return url.deletingPathExtension().lastPathComponent
        }
        return AppInfo.from(url: url, customTitle: nil).name
    }

    @discardableResult
    func ensureCustomTitleEntry(for url: URL) -> AppInfo? {
        let resolved = url.resolvingSymlinksInPath()
        guard resolved.pathExtension.lowercased() == "app" else { return nil }
        guard FileManager.default.fileExists(atPath: resolved.path) else {
            return nil
        }

        let info = appInfo(from: resolved)
        if customTitles[resolved.path] == nil {
            setCustomTitle(info.name, for: info)
        } else {
            applyCustomTitleOverride(
                for: resolved,
                title: customTitles[resolved.path]
            )
        }
        return info
    }

    private func applyCustomTitleOverride(for url: URL, title: String?) {
        let info = AppInfo.from(url: url, customTitle: title)
        var changed = false

        if let index = apps.firstIndex(where: { $0.url == url }) {
            apps[index] = info
            changed = true
        }

        for folderIndex in folders.indices {
            var folder = folders[folderIndex]
            var folderChanged = false
            for appIndex in folder.apps.indices
            where folder.apps[appIndex].url == url {
                folder.apps[appIndex] = info
                folderChanged = true
            }
            if folderChanged {
                folders[folderIndex] = folder
                changed = true
            }
        }

        for itemIndex in items.indices {
            switch items[itemIndex] {
            case .app(let app) where app.url == url:
                items[itemIndex] = .app(info)
                changed = true
            case .folder(var folder):
                var folderChanged = false
                for appIndex in folder.apps.indices
                where folder.apps[appIndex].url == url {
                    folder.apps[appIndex] = info
                    folderChanged = true
                }
                if folderChanged {
                    items[itemIndex] = .folder(folder)
                    changed = true
                }
            case .empty:
                break
            default:
                break
            }
        }

        if changed {
            triggerFolderUpdate()
            triggerGridRefresh()
            scheduleCustomTitleCacheRefresh()
        }
    }

    private func scheduleCustomTitleCacheRefresh() {
        customTitleRefreshWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.cacheManager.refreshCache(
                from: self.apps,
                items: self.items,
                itemsPerPage: self.itemsPerPage,
                columns: self.gridColumnsPerPage,
                rows: self.gridRowsPerPage
            )
        }
        customTitleRefreshWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    func setCustomAppIcon(from url: URL) -> Bool {
        guard let image = NSImage(contentsOf: url),
            let normalized = AppStore.normalizedIconImage(from: image),
            let data = AppStore.pngData(from: normalized)
        else {
            return false
        }
        do {
            try data.write(to: customIconFileURL, options: .atomic)
            hasCustomAppIcon = true
            currentAppIcon = normalized
            return true
        } catch {
            return false
        }
    }

    func resetCustomAppIcon() {
        try? FileManager.default.removeItem(at: customIconFileURL)
        hasCustomAppIcon = false
        currentAppIcon = defaultAppIcon
        applyCurrentAppIcon()
    }

    private func applyCurrentAppIcon() {
        let icon = currentAppIcon
        let bundlePath = Bundle.main.bundlePath
        let hasCustomIconFile = FileManager.default.fileExists(
            atPath: customIconFileURL.path
        )
        DispatchQueue.main.async {
            let application = NSApplication.shared
            application.applicationIconImage = icon
            application.dockTile.display()

            let workspace = NSWorkspace.shared
            let success: Bool
            if hasCustomIconFile {
                success = workspace.setIcon(
                    icon,
                    forFile: bundlePath,
                    options: []
                )
            } else {
                success = workspace.setIcon(
                    nil,
                    forFile: bundlePath,
                    options: []
                )
            }

            if success {
                workspace.noteFileSystemChanged(bundlePath)
            } else {
                NSLog(
                    "LaunchOne: Failed to update application bundle icon at %@",
                    bundlePath
                )
            }
        }
    }

    private static func loadStoredAppIcon(from url: URL) -> NSImage? {
        guard FileManager.default.fileExists(atPath: url.path),
            let data = try? Data(contentsOf: url),
            let image = NSImage(data: data)
        else { return nil }
        return image
    }

    private static func normalizedIconImage(
        from image: NSImage,
        size: CGFloat = 512
    ) -> NSImage? {
        let targetSize = NSSize(width: size, height: size)
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(
            targetSize.width / image.size.width,
            targetSize.height / image.size.height
        )
        let scaledSize = NSSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let drawRect = NSRect(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )

        let output = NSImage(size: targetSize)
        output.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: targetSize)).fill()
        let sourceRect = NSRect(origin: .zero, size: image.size)
        let hints: [NSImageRep.HintKey: Any] = [
            .interpolation: NSImageInterpolation.high.rawValue
        ]
        image.draw(
            in: drawRect,
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: false,
            hints: hints
        )
        output.unlockFocus()
        return output
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        rep.size = image.size
        return rep.representation(using: .png, properties: [:])
    }

    private static func ensureAppSupportDirectory() -> URL {
        let fm = FileManager.default
        if let base = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            let dir = base.appendingPathComponent(
                "LaunchOne",
                isDirectory: true
            )
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true
                )
            }
            return dir
        }
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    private static var customIconFileURL: URL {
        ensureAppSupportDirectory().appendingPathComponent(
            "CustomAppIcon.png",
            isDirectory: false
        )
    }

    /// Refresh caches after folder operations to keep search working
    private func refreshCacheAfterFolderOperation() {
        // Refresh caches directly to include all apps (including those inside folders)
        cacheManager.refreshCache(
            from: apps,
            items: items,
            itemsPerPage: itemsPerPage,
            columns: gridColumnsPerPage,
            rows: gridRowsPerPage
        )

        // Clear search text to reset search state
        // This avoids showing stale results during search
        if !searchText.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                [weak self] in
                self?.searchText = ""
            }
        }
    }

    func setGlobalHotKey(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags)
    {
        let normalized = modifierFlags.normalizedShortcutFlags
        let configuration = HotKeyConfiguration(
            keyCode: keyCode,
            modifierFlags: normalized
        )
        if globalHotKey != configuration {
            globalHotKey = configuration
        }
    }

    func clearGlobalHotKey() {
        if globalHotKey != nil {
            globalHotKey = nil
        }
    }

    func persistCurrentPageIfNeeded() {
        guard rememberLastPage else { return }
        UserDefaults.standard.set(
            currentPage,
            forKey: Self.rememberedPageIndexKey
        )
    }

    func hotKeyDisplayText(nonePlaceholder: String) -> String {
        guard let config = globalHotKey else { return nonePlaceholder }
        let base = config.displayString
        if config.modifierFlags.isEmpty {
            return base + " • " + localized(.shortcutNoModifierWarning)
        }
        return base
    }

    func syncGlobalHotKeyRegistration() {
        AppDelegate.shared?.updateGlobalHotKey(configuration: globalHotKey)
    }

    // MARK: - Import app ordering
    /// Import app ordering from JSON data
    func importAppOrderFromJSON(_ jsonData: Data) -> Bool {
        do {
            let importData = try JSONSerialization.jsonObject(
                with: jsonData,
                options: []
            )
            return processImportedData(importData)
        } catch {
            return false
        }
    }

    /// Import layout from native macOS Launchpad
    func importFromNativeLaunchpad() async -> (success: Bool, message: String) {
        guard let modelContext = self.modelContext else {
            return (false, "Data store not initialized")
        }

        do {
            let importer = NativeLaunchpadImporter(modelContext: modelContext)
            let result = try importer.importFromNativeLaunchpad()

            // After import, refresh app data
            DispatchQueue.main.async { [weak self] in
                self?.performInitialScanIfNeeded()
                // New version uses SwiftData unified loading entry
                self?.loadAllOrder()
                self?.triggerGridRefresh()
            }

            return (true, result.summary)
        } catch {
            return (false, "Import failed: \(error.localizedDescription)")
        }
    }

    /// Import from legacy archive (.lmy/.zip) or direct db
    func importFromLegacyLaunchpadArchive(url: URL) async -> (
        success: Bool, message: String
    ) {
        guard let modelContext = self.modelContext else {
            return (false, "Data store not initialized")
        }

        do {
            let importer = NativeLaunchpadImporter(modelContext: modelContext)
            let result = try importer.importFromLegacyArchive(at: url)

            // After import, refresh app data
            DispatchQueue.main.async { [weak self] in
                self?.performInitialScanIfNeeded()
                self?.loadAllOrder()
                self?.triggerGridRefresh()
            }

            return (true, result.summary)
        } catch {
            return (false, "Import failed: \(error.localizedDescription)")
        }
    }

    /// Process imported data and rebuild app layout
    private func processImportedData(_ importData: Any) -> Bool {
        guard let data = importData as? [String: Any],
            let pagesData = data["pages"] as? [[String: Any]]
        else {
            return false
        }

        // Build a mapping from app path to app object
        let appPathMap = Dictionary(
            uniqueKeysWithValues: apps.map { ($0.url.path, $0) }
        )

        // Rebuild the items array
        var newItems: [LaunchpadItem] = []
        var importedFolders: [FolderInfo] = []

        // Process data for each page
        for pageData in pagesData {
            guard let kind = pageData["kind"] as? String,
                let name = pageData["name"] as? String
            else { continue }

            switch kind {
            case "App":
                if let path = pageData["path"] as? String,
                    let app = appPathMap[path]
                {
                    newItems.append(.app(app))
                } else {
                    // App missing — add an empty slot
                    newItems.append(.empty(UUID().uuidString))
                }

            case "Folder":
                if let folderApps = pageData["folderApps"] as? [String],
                    let folderAppPaths = pageData["folderAppPaths"] as? [String]
                {
                    // Rebuild folder — prefer matching by app path for accuracy
                    let folderAppsList = folderAppPaths.compactMap { appPath in
                        // Match by app path; this is the most accurate
                        if let app = apps.first(where: {
                            $0.url.path == appPath
                        }) {
                            return app
                        }
                        // If path match fails, try matching by name (fallback)
                        if let appName = folderApps.first(where: { _ in true }),  // Get corresponding app name
                            let app = apps.first(where: { $0.name == appName })
                        {
                            return app
                        }
                        return nil
                    }

                    if !folderAppsList.isEmpty {
                        // Try to find a matching existing folder to keep IDs consistent
                        let existingFolder = self.folders.first {
                            existingFolder in
                            existingFolder.name == name
                                && existingFolder.apps.count
                                    == folderAppsList.count
                                && existingFolder.apps.allSatisfy { app in
                                    folderAppsList.contains { $0.id == app.id }
                                }
                        }

                        if let existing = existingFolder {
                            // Use existing folder to keep ID consistent
                            importedFolders.append(existing)
                            newItems.append(.folder(existing))
                        } else {
                            // Create a new folder
                            let folder = FolderInfo(
                                name: name,
                                apps: folderAppsList
                            )
                            importedFolders.append(folder)
                            newItems.append(.folder(folder))
                        }
                    } else {
                        // Folder empty — add an empty slot
                        newItems.append(.empty(UUID().uuidString))
                    }
                } else if let folderApps = pageData["folderApps"] as? [String] {
                    // Backward compatibility: names only, no path info
                    let folderAppsList = folderApps.compactMap { appName in
                        apps.first { $0.name == appName }
                    }

                    if !folderAppsList.isEmpty {
                        // Try to match an existing folder to keep IDs consistent
                        let existingFolder = self.folders.first {
                            existingFolder in
                            existingFolder.name == name
                                && existingFolder.apps.count
                                    == folderAppsList.count
                                && existingFolder.apps.allSatisfy { app in
                                    folderAppsList.contains { $0.id == app.id }
                                }
                        }

                        if let existing = existingFolder {
                            // Use existing folder to keep ID consistent
                            importedFolders.append(existing)
                            newItems.append(.folder(existing))
                        } else {
                            // Create a new folder
                            let folder = FolderInfo(
                                name: name,
                                apps: folderAppsList
                            )
                            importedFolders.append(folder)
                            newItems.append(.folder(folder))
                        }
                    } else {
                        // Folder empty — add an empty slot
                        newItems.append(.empty(UUID().uuidString))
                    }
                } else {
                    // Folder data invalid — add an empty slot
                    newItems.append(.empty(UUID().uuidString))
                }

            case "Empty Slot":
                newItems.append(.empty(UUID().uuidString))

            default:
                // Unknown type — add an empty slot
                newItems.append(.empty(UUID().uuidString))
            }
        }

        // Handle extra apps (place them on the last page)
        let usedApps = Set(
            newItems.compactMap { item in
                if case .app(let app) = item { return app }
                return nil
            }
        )

        let usedAppsInFolders = Set(importedFolders.flatMap { $0.apps })
        let allUsedApps = usedApps.union(usedAppsInFolders)

        let unusedApps = apps.filter { !allUsedApps.contains($0) }

        if !unusedApps.isEmpty {
            // Calculate how many empty slots to add
            let itemsPerPage = self.itemsPerPage
            let currentPages =
                (newItems.count + itemsPerPage - 1) / itemsPerPage
            let lastPageStart = currentPages * itemsPerPage
            let lastPageEnd = lastPageStart + itemsPerPage

            // Ensure the last page has enough space
            while newItems.count < lastPageEnd {
                newItems.append(.empty(UUID().uuidString))
            }

            // Add unused apps to the last page
            for (index, app) in unusedApps.enumerated() {
                let insertIndex = lastPageStart + index
                if insertIndex < newItems.count {
                    newItems[insertIndex] = .app(app)
                } else {
                    newItems.append(.app(app))
                }
            }

            // Ensure the last page is complete
            let finalPageCount = newItems.count
            let finalPages = (finalPageCount + itemsPerPage - 1) / itemsPerPage
            let finalLastPageStart = (finalPages - 1) * itemsPerPage
            let finalLastPageEnd = finalLastPageStart + itemsPerPage

            // If the last page is incomplete, add empty slots
            while newItems.count < finalLastPageEnd {
                newItems.append(.empty(UUID().uuidString))
            }
        }

        // Validate the imported data structure

        // Update app state
        DispatchQueue.main.async {

            // Set new data
            self.folders = self.sanitizedFolders(importedFolders)
            self.items = self.filteredItemsRemovingHidden(from: newItems)

            // Force a UI refresh
            self.triggerFolderUpdate()
            self.triggerGridRefresh()

            // Save the new layout
            self.saveAllOrder()

            // Do not compact pages for now; preserve the imported order
            // If needed, compaction can be triggered after user actions
        }

        return true
    }

    /// Validate integrity of imported data
    func validateImportData(_ jsonData: Data) -> (
        isValid: Bool, message: String
    ) {
        do {
            let importData = try JSONSerialization.jsonObject(
                with: jsonData,
                options: []
            )
            guard let data = importData as? [String: Any] else {
                return (false, "Invalid data format")
            }

            guard let pagesData = data["pages"] as? [[String: Any]] else {
                return (false, "Missing page data")
            }

            let totalPages = data["totalPages"] as? Int ?? 0
            let totalItems = data["totalItems"] as? Int ?? 0

            if pagesData.isEmpty {
                return (false, "No app data found")
            }

            return (true, "Validation passed: \(totalPages) pages, \(totalItems) items")
        } catch {
            return (false, "JSON parse failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Update check feature

    private func scheduleAutomaticUpdateCheck() {
        autoCheckTimer?.cancel()
        autoCheckTimer = nil

        guard autoCheckForUpdates else { return }

        performAutomaticUpdateCheckIfNeeded()

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(
            deadline: .now() + Self.automaticUpdateInterval,
            repeating: Self.automaticUpdateInterval
        )
        timer.setEventHandler { [weak self] in
            self?.performAutomaticUpdateCheckIfNeeded()
        }
        timer.activate()
        autoCheckTimer = timer
    }

    private func performAutomaticUpdateCheckIfNeeded() {
        guard autoCheckForUpdates else { return }
        let now = Date()
        if let last = lastUpdateCheck,
            now.timeIntervalSince(last) < Self.automaticUpdateInterval
        {
            return
        }
        checkForUpdates()
    }

    func checkForUpdates() {
        guard updateState != .checking else { return }

        lastUpdateCheck = Date()
        updateState = .checking

        Task {
            do {
                let currentVersion = getCurrentVersion()
                let latestRelease = try await fetchLatestRelease()

                await MainActor.run {
                    if let current = SemanticVersion(currentVersion),
                        let latest = SemanticVersion(latestRelease.tagName)
                    {
                        if latest > current {
                            let release = UpdateRelease(
                                version: latestRelease.tagName,
                                url: latestRelease.htmlUrl,
                                notes: latestRelease.body
                            )
                            updateState = .updateAvailable(release)
                            presentUpdateAlert(for: release)
                        } else {
                            updateState = .upToDate(
                                latest: latestRelease.tagName
                            )
                        }
                    } else {
                        updateState = .failed(localized(.versionParseError))
                        presentUpdateFailureAlert(localized(.versionParseError))
                    }
                }
            } catch {
                await MainActor.run {
                    let message = error.localizedDescription
                    updateState = .failed(message)
                    presentUpdateFailureAlert(message)
                }
            }
        }
    }

    private func getCurrentVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "0.0.0"
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(
            string:
                "https://api.github.com/repos/mamahuhu-io/LaunchOne/releases/latest"
        )!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    //    @MainActor
    //    private func presentUpdateAlert(for release: UpdateRelease) {
    //        let notification = NSUserNotification()
    //        notification.title = localized(.updateAvailable)
    //        notification.informativeText = "\(localized(.newVersion)) \(release.version)"
    //        notification.hasActionButton = true
    //        notification.actionButtonTitle = localized(.downloadUpdate)
    //        notification.otherButtonTitle = localized(.cancel)
    //        notification.userInfo = ["releaseURL": release.url.absoluteString]
    //
    //        NSUserNotificationCenter.default.delegate = notificationDelegate
    //        NSUserNotificationCenter.default.deliver(notification)
    //    }
    //
    //    @MainActor
    //    private func presentUpdateFailureAlert(_ message: String) {
    //        let notification = NSUserNotification()
    //        notification.title = localized(.updateCheckFailed)
    //        notification.informativeText = message
    //
    //        NSUserNotificationCenter.default.delegate = notificationDelegate
    //        NSUserNotificationCenter.default.deliver(notification)
    //    }

    @MainActor
    private func presentUpdateAlert(for release: UpdateRelease) {
        let center = UNUserNotificationCenter.current()

        // Request permission (only once at app launch)
        center.requestAuthorization(options: [.alert, .sound, .badge]) {
            granted,
            error in
            guard granted, error == nil else { return }

            let content = UNMutableNotificationContent()
            content.title = self.localized(.updateAvailable)
            content.body = "\(self.localized(.newVersion)) \(release.version)"
            content.sound = .default
            content.userInfo = ["releaseURL": release.url.absoluteString]

            // Create action buttons
            let downloadAction = UNNotificationAction(
                identifier: "DOWNLOAD_ACTION",
                title: self.localized(.downloadUpdate),
                options: [.foreground]
            )
            let cancelAction = UNNotificationAction(
                identifier: "CANCEL_ACTION",
                title: self.localized(.cancel),
                options: []
            )

            let category = UNNotificationCategory(
                identifier: "UPDATE_CATEGORY",
                actions: [downloadAction, cancelAction],
                intentIdentifiers: [],
                options: []
            )
            center.setNotificationCategories([category])
            content.categoryIdentifier = "UPDATE_CATEGORY"

            // Deliver notification immediately
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    @MainActor
    private func presentUpdateFailureAlert(_ message: String) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) {
            granted,
            error in
            guard granted, error == nil else { return }

            let content = UNMutableNotificationContent()
            content.title = self.localized(.updateCheckFailed)
            content.body = message
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    func openReleaseURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

private final class UpdateNotificationDelegate: NSObject,
    UNUserNotificationCenterDelegate
{
    private let openHandler: (URL) -> Void

    init(openHandler: @escaping (URL) -> Void) {
        self.openHandler = openHandler
    }

    // Always show notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]  // Show banner and play sound
    }

    // User taps the notification or action button
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let urlString = userInfo["releaseURL"] as? String,
            let url = URL(string: urlString)
        {
            switch response.actionIdentifier {
            case "DOWNLOAD_ACTION":
                // User tapped the download button
                openHandler(url)
            default:
                break
            }
        }
    }
}

#if DEBUG
    extension AppStore {
        func simulateUpdateAvailable() {
            let dummy = UpdateRelease(
                version: "999.0.0",
                url: URL(
                    string:
                        "https://github.com/mamahuhu-io/LaunchOne/releases/latest"
                )!,
                notes: ""
            )
            updateState = .updateAvailable(dummy)
            presentUpdateAlert(for: dummy)
        }

        func simulateUpdateFailure() {
            let message = "Simulated update failed."
            updateState = .failed(message)
            presentUpdateFailureAlert(message)
        }
    }
#endif

extension NSEvent.ModifierFlags {
    static let shortcutComponents: NSEvent.ModifierFlags = [
        .command, .option, .control, .shift,
    ]

    var normalizedShortcutFlags: NSEvent.ModifierFlags {
        intersection(.deviceIndependentFlagsMask).intersection(
            Self.shortcutComponents
        )
    }

    var carbonFlags: UInt32 {
        var value: UInt32 = 0
        if contains(.command) { value |= UInt32(cmdKey) }
        if contains(.option) { value |= UInt32(optionKey) }
        if contains(.control) { value |= UInt32(controlKey) }
        if contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }

    var displaySymbols: [String] {
        var symbols: [String] = []
        if contains(.control) { symbols.append("⌃") }
        if contains(.option) { symbols.append("⌥") }
        if contains(.shift) { symbols.append("⇧") }
        if contains(.command) { symbols.append("⌘") }
        return symbols
    }
}
