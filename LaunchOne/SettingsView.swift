import AppKit
import Darwin
import MachO
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var appStore: AppStore
    @State private var showResetConfirm = false
    @State private var selectedSection: AppStore.SettingsSection = .general
    @State private var titleSearch: String = ""
    @State private var hiddenSearch: String = ""
    @State private var editingDrafts: [String: String] = [:]
    @State private var editingEntries: Set<String> = []
    @State private var iconImportError: String? = nil
    @State private var isCapturingShortcut = false
    @State private var shortcutCaptureMonitor: Any?
    @State private var pendingShortcut: AppStore.HotKeyConfiguration?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationSplitView {
                List(selection: $selectedSection) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appStore.localized(.appTitle))
                            .font(.headline.weight(.semibold))
                        Text(
                            "\(appStore.localized(.versionPrefix))\(getVersion())"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .listRowInsets(
                        EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 10)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    ForEach(AppStore.SettingsSection.allCases.filter { section in
                        #if DEBUG
                        return true
                        #else
                        return section != .development
                        #endif
                    }) { section in
                        HStack(spacing: 8) {
                            RoundedRectangle(
                                cornerRadius: 6,
                                style: .continuous
                            )
                            .fill(section.iconGradient)
                            .overlay(
                                Image(systemName: section.iconName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                            )
                            .frame(width: 24, height: 24)
                            .liquidGlass()

                            Text(appStore.localized(section.localizationKey))
                                .font(.callout.weight(.medium))
                        }
                        .padding(.vertical, 2)
                        .tag(section)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(.ultraThinMaterial)
                .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 250)
            } detail: {
                detailView(for: selectedSection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)

            // Close button
            Button {
                appStore.isSetting = false
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .liquidGlass()
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .frame(minWidth: 720, minHeight: 600)
        .alert(
            appStore.localized(.customIconTitle),
            isPresented: Binding(
                get: { iconImportError != nil },
                set: { if !$0 { iconImportError = nil } }
            )
        ) {
            Button(appStore.localized(.okButton), role: .cancel) {
                iconImportError = nil
            }
        } message: {
            Text(iconImportError ?? "")
        }
        .onChange(of: iconImportError) { _, newValue in
            // Prevent settings window from auto-hiding when a modal alert is shown
            AppDelegate.shared?.isShowingModalPanel = (newValue != nil)
        }
        .onAppear {
            // If an initial section is specified, show it
            if let initialSection = appStore.settingsInitialSection {
                selectedSection = initialSection
                appStore.settingsInitialSection = nil  // Reset state
            }
            
            // Observe notification to update selectedSection
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("UpdateSelectedSection"),
                object: nil,
                queue: .main
            ) { notification in
                if let section = notification.userInfo?["section"] as? AppStore.SettingsSection {
                    selectedSection = section
                }
            }
        }
        .onDisappear {
            stopShortcutCapture(cancel: false)
            // Remove notification observer
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdateSelectedSection"), object: nil)
            AppDelegate.shared?.isShowingModalPanel = false
        }
        .onKeyPress(.escape) {
            appStore.isSetting = false
            return .handled
        }
    }

    private func getVersion(includeBuildVersion: Bool = false) -> String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        if includeBuildVersion {
            let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
            return "\(shortVersion) (\(buildVersion))"
        } else {
            return shortVersion
        }
    }

    @ViewBuilder
    private func detailView(for section: AppStore.SettingsSection) -> some View
    {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 160)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(1), Color.white.opacity(0),
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 16) {
                    Text(appStore.localized(section.localizationKey))
                        .font(.title3.bold())

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            content(for: section)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollBounceBehavior(.basedOnSize)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .topLeading
                )
            }
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func content(for section: AppStore.SettingsSection) -> some View {
        switch section {
        case .general:
            generalSection
        case .appearance:
            appearanceSection
        case .performance:
            performanceSection
        case .titles:
            titlesSection
        case .hiddenApps:
            hiddenAppsSection
        case .development:
            #if DEBUG
            developmentSection
            #else
            EmptyView()
            #endif
        case .about:
            aboutSection
        }
    }


    private var developmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appStore.localized(.developmentPlaceholderTitle))
                .font(.headline)
            Text(appStore.localized(.developmentPlaceholderSubtitle))
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                Text(currentMemoryUsageString())
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            Toggle(
                appStore.localized(.showFPSOverlay),
                isOn: $appStore.showFPSOverlay
            )
            .toggleStyle(.switch)
            Text(appStore.localized(.showFPSOverlayDisclaimer))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appStore.localized(.performancePlaceholderTitle))
                .font(.headline)
            Text(appStore.localized(.performancePlaceholderSubtitle))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var titlesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    presentCustomTitlePicker()
                } label: {
                    Label(
                        appStore.localized(.customTitleAddButton),
                        systemImage: "plus"
                    )
                }
                Spacer()
            }

            let allEntries = customTitleEntries
            let filtered = filteredCustomTitleEntries

            if allEntries.isEmpty {
                customTitleEmptyState
            } else {
                Text(appStore.localized(.customTitleHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField(
                    "",
                    text: $titleSearch,
                    prompt: Text(appStore.localized(.renameSearchPlaceholder))
                )
                .textFieldStyle(.roundedBorder)

                if filtered.isEmpty {
                    Text(appStore.localized(.customTitleNoResults))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 120,
                            alignment: .center
                        )
                } else {
                    VStack(spacing: 12) {
                        ForEach(filtered) { entry in
                            customTitleRow(for: entry)
                        }
                    }
                }
            }
        }
    }

    private var hiddenAppsSection: some View {
        let entries = hiddenAppEntries
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    presentHiddenAppPicker()
                } label: {
                    Label(
                        appStore.localized(.hiddenAppsAddButton),
                        systemImage: "eye.slash"
                    )
                }
                Spacer()
            }

            if entries.isEmpty {
                hiddenAppsEmptyState
            } else {
                Text(appStore.localized(.hiddenAppsHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField(
                    "",
                    text: $hiddenSearch,
                    prompt: Text(
                        appStore.localized(.hiddenAppsSearchPlaceholder)
                    )
                )
                .textFieldStyle(.roundedBorder)

                let filtered = filteredHiddenAppEntries
                if filtered.isEmpty {
                    Text(appStore.localized(.customTitleNoResults))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 120,
                            alignment: .center
                        )
                } else {
                    VStack(spacing: 12) {
                        ForEach(filtered) { entry in
                            hiddenAppRow(for: entry)
                        }
                    }
                }
            }
        }
    }

    private var hiddenAppEntries: [HiddenAppEntry] {
        appStore.hiddenAppPaths
            .map { path in
                let info = appStore.appInfoForCustomTitle(path: path)
                let defaultName = appStore.defaultDisplayName(for: path)
                return HiddenAppEntry(
                    id: path,
                    appInfo: info,
                    defaultName: defaultName
                )
            }
            .sorted { lhs, rhs in
                lhs.appInfo.name.localizedCaseInsensitiveCompare(
                    rhs.appInfo.name
                ) == .orderedAscending
            }
    }

    private var filteredHiddenAppEntries: [HiddenAppEntry] {
        let base = hiddenAppEntries
        let trimmed = hiddenSearch.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return base }
        let query = trimmed.lowercased()
        return base.filter { entry in
            if entry.appInfo.name.lowercased().contains(query) { return true }
            if entry.defaultName.lowercased().contains(query) { return true }
            if entry.id.lowercased().contains(query) { return true }
            return false
        }
    }

    private var hiddenAppsEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appStore.localized(.hiddenAppsEmptyTitle))
                .font(.headline)
            Text(appStore.localized(.hiddenAppsEmptySubtitle))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                presentHiddenAppPicker()
            } label: {
                Label(
                    appStore.localized(.hiddenAppsAddButton),
                    systemImage: "eye.slash"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func hiddenAppRow(for entry: HiddenAppEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: entry.appInfo.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.appInfo.name)
                    .font(.callout.weight(.semibold))
                Text(entry.defaultName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.id)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                appStore.unhideApp(path: entry.id)
            } label: {
                Text(appStore.localized(.hiddenAppsRemoveButton))
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct HiddenAppEntry: Identifiable {
        let id: String
        let appInfo: AppInfo
        let defaultName: String
    }

    private var customTitleEntries: [CustomTitleEntry] {
        appStore.customTitles
            .map { (path, _) in
                let info = appStore.appInfoForCustomTitle(path: path)
                let defaultName = appStore.defaultDisplayName(for: path)
                return CustomTitleEntry(
                    id: path,
                    appInfo: info,
                    defaultName: defaultName
                )
            }
            .sorted { lhs, rhs in
                lhs.appInfo.name.localizedCaseInsensitiveCompare(
                    rhs.appInfo.name
                ) == .orderedAscending
            }
    }

    private var filteredCustomTitleEntries: [CustomTitleEntry] {
        let base = customTitleEntries
        let trimmed = titleSearch.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return base }
        let query = trimmed.lowercased()
        return base.filter { entry in
            let custom = entry.appInfo.name.lowercased()
            if custom.contains(query) { return true }
            if entry.defaultName.lowercased().contains(query) { return true }
            if entry.id.lowercased().contains(query) { return true }
            return false
        }
    }

    private var customTitleEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appStore.localized(.customTitleEmptyTitle))
                .font(.headline)
            Text(appStore.localized(.customTitleEmptySubtitle))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                presentCustomTitlePicker()
            } label: {
                Label(
                    appStore.localized(.customTitleAddButton),
                    systemImage: "plus"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func customTitleRow(for entry: CustomTitleEntry) -> some View {
        let isEditing = editingEntries.contains(entry.id)
        let currentDraft =
            editingDrafts[entry.id] ?? appStore.customTitles[entry.id]
            ?? entry.appInfo.name
        let trimmedDraft = currentDraft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let originalValue = appStore.customTitles[entry.id] ?? entry.defaultName
        let draftBinding = Binding(
            get: {
                editingDrafts[entry.id] ?? appStore.customTitles[entry.id]
                    ?? entry.appInfo.name
            },
            set: { editingDrafts[entry.id] = $0 }
        )

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(nsImage: entry.appInfo.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.appInfo.name)
                        .font(.callout.weight(.semibold))
                    Text(
                        String(
                            format: appStore.localized(
                                .customTitleDefaultFormat
                            ),
                            entry.defaultName
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    if isEditing {
                        Button(appStore.localized(.customTitleSave)) {
                            saveCustomTitle(entry)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            trimmedDraft.isEmpty
                                || trimmedDraft == originalValue
                        )

                        Button(appStore.localized(.customTitleCancel)) {
                            cancelEditing(entry)
                        }
                        .buttonStyle(.bordered)

                        if !(appStore.customTitles[entry.id]?.isEmpty ?? true) {
                            Button(role: .destructive) {
                                removeCustomTitle(entry)
                            } label: {
                                Text(appStore.localized(.customTitleDelete))
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button(appStore.localized(.customTitleEdit)) {
                            beginEditing(entry)
                        }
                        .buttonStyle(.bordered)

                        if !(appStore.customTitles[entry.id]?.isEmpty ?? true) {
                            Button(role: .destructive) {
                                removeCustomTitle(entry)
                            } label: {
                                Text(appStore.localized(.customTitleDelete))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if isEditing {
                TextField(
                    "",
                    text: draftBinding,
                    prompt: Text(appStore.localized(.customTitlePlaceholder))
                )
                .textFieldStyle(.roundedBorder)
            }
        }
        .padding(14)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func presentHiddenAppPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.prompt = appStore.localized(.hiddenAppsAddButton)
        panel.title = appStore.localized(.hiddenAppsAddButton)

        // Set a flag to prevent the settings window from closing while a modal panel is shown
        AppDelegate.shared?.isShowingModalPanel = true
        defer { AppDelegate.shared?.isShowingModalPanel = false }
        
        if panel.runModal() == .OK, let url = panel.url {
            if !appStore.hideApp(at: url) {
                NSSound.beep()
            }
        }
    }

    private func presentCustomTitlePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.title = appStore.localized(.customTitleAddButton)
        panel.message = appStore.localized(.customTitlePickerMessage)
        panel.prompt = appStore.localized(.chooseButton)

        // Set a flag to prevent the settings window from closing while a modal panel is shown
        AppDelegate.shared?.isShowingModalPanel = true
        defer { AppDelegate.shared?.isShowingModalPanel = false }

        if panel.runModal() == .OK, let url = panel.url,
            let info = appStore.ensureCustomTitleEntry(for: url)
        {
            let path = info.url.path
            editingEntries.insert(path)
            editingDrafts[path] = appStore.customTitles[path] ?? info.name
        }
    }

    private func presentAppIconPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.icns, .png, .jpeg, .tiff]
        panel.prompt = appStore.localized(.customIconChoose)
        panel.title = appStore.localized(.customIconTitle)

        // Set a flag to prevent the settings window from closing while a modal panel is shown
        AppDelegate.shared?.isShowingModalPanel = true
        defer { AppDelegate.shared?.isShowingModalPanel = false }

        if panel.runModal() == .OK, let url = panel.url {
            if !appStore.setCustomAppIcon(from: url) {
                iconImportError = appStore.localized(.customIconError)
            }
        }
    }

    private struct CustomTitleEntry: Identifiable {
        let id: String
        let appInfo: AppInfo
        let defaultName: String
    }

    private func beginEditing(_ entry: CustomTitleEntry) {
        editingEntries.insert(entry.id)
        editingDrafts[entry.id] =
            appStore.customTitles[entry.id] ?? entry.appInfo.name
    }

    private func cancelEditing(_ entry: CustomTitleEntry) {
        editingEntries.remove(entry.id)
        editingDrafts.removeValue(forKey: entry.id)
    }

    private func saveCustomTitle(_ entry: CustomTitleEntry) {
        let draft =
            (editingDrafts[entry.id] ?? appStore.customTitles[entry.id]
            ?? entry.appInfo.name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else { return }
        let original = appStore.customTitles[entry.id] ?? entry.defaultName
        if draft == original {
            editingEntries.remove(entry.id)
            editingDrafts.removeValue(forKey: entry.id)
            return
        }
        appStore.setCustomTitle(draft, for: entry.appInfo)
        editingEntries.remove(entry.id)
        editingDrafts.removeValue(forKey: entry.id)
    }

    private func removeCustomTitle(_ entry: CustomTitleEntry) {
        appStore.clearCustomTitle(for: entry.appInfo)
        editingEntries.remove(entry.id)
        editingDrafts.removeValue(forKey: entry.id)
    }

    private static let modifierOnlyKeyCodes: Set<UInt16> = [
        55, 54, 58, 61, 56, 60, 59, 62, 57,
    ]

    private func startShortcutCapture() {
        stopShortcutCapture(cancel: false)
        pendingShortcut = nil
        isCapturingShortcut = true
        shortcutCaptureMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .keyDown
        ]) { event in
            handleShortcutCapture(event: event)
        }
    }

    private func stopShortcutCapture(cancel: Bool) {
        if let monitor = shortcutCaptureMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutCaptureMonitor = nil
        }
        if cancel {
            pendingShortcut = nil
            if isCapturingShortcut { NSSound.beep() }
        }
        isCapturingShortcut = false
    }

    private func handleShortcutCapture(event: NSEvent) -> NSEvent? {
        let normalizedFlags = event.modifierFlags.normalizedShortcutFlags

        if event.keyCode == 53 && normalizedFlags.isEmpty {
            stopShortcutCapture(cancel: true)
            return nil
        }

        guard !normalizedFlags.isEmpty,
            !Self.modifierOnlyKeyCodes.contains(event.keyCode)
        else {
            NSSound.beep()
            return nil
        }

        pendingShortcut = AppStore.HotKeyConfiguration(
            keyCode: event.keyCode,
            modifierFlags: normalizedFlags
        )
        return nil
    }

    private func savePendingShortcut() {
        guard let shortcut = pendingShortcut else { return }
        appStore.setGlobalHotKey(
            keyCode: shortcut.keyCode,
            modifierFlags: shortcut.modifierFlags
        )
        pendingShortcut = nil
        stopShortcutCapture(cancel: false)
    }

    private var shortcutStatusText: String {
        if isCapturingShortcut {
            if let shortcut = pendingShortcut {
                let base = shortcut.displayString
                if shortcut.modifierFlags.isEmpty {
                    return base + " • "
                        + appStore.localized(.shortcutNoModifierWarning)
                }
                return base
            }
            return appStore.localized(.shortcutCapturePrompt)
        }
        if let saved = appStore.globalHotKey {
            let base = saved.displayString
            if saved.modifierFlags.isEmpty {
                return base + " • "
                    + appStore.localized(.shortcutNoModifierWarning)
            }
            return base
        }
        return appStore.localized(.shortcutNotSet)
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appStore.localized(.appTitle))
                        .font(.title2.weight(.semibold))
                    Text("\(appStore.localized(.versionPrefix))\(getVersion(includeBuildVersion: true))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(appStore.localized(.modifiedFrom))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(appStore.localized(.backgroundHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Update check
            updateCheckSection

            Link(
                destination: URL(
                    string: "https://github.com/mamahuhu-io/LaunchOne"
                )!
            ) {
                Label(
                    appStore.localized(.viewOnGitHub),
                    systemImage: "arrow.up.right.square"
                )
            }
            .buttonStyle(.link)
        }
    }

    private func currentMemoryUsageString() -> String {
        var info = task_vm_info_data_t()
        var count =
            mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
        let kern = withUnsafeMutablePointer(to: &info) {
            pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count))
            {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    $0,
                    &count
                )
            }
        }

        guard kern == KERN_SUCCESS else { return "Memory: --" }

        let usedBytes = info.phys_footprint
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        let formatted = formatter.string(fromByteCount: Int64(usedBytes))
        return "Memory: \(formatted)"
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(appStore.localized(.languagePickerTitle))
                    .font(.headline)
                Picker(
                    appStore.localized(.languagePickerTitle),
                    selection: $appStore.preferredLanguage
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(appStore.localizedLanguageName(for: language)).tag(
                            language
                        )
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .onChange(of: appStore.preferredLanguage) { _, newLanguage in
                    print("Settings page language switched to: \(newLanguage)")
                    // AppStore's didSet will automatically post notifications; no extra handling needed here
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(appStore.localized(.appearanceModeTitle))
                    .font(.headline)
                Picker(
                    appStore.localized(.appearanceModeTitle),
                    selection: $appStore.appearancePreference
                ) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Text(appStore.localized(preference.localizationKey))
                            .tag(preference)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(appStore.localized(.dockDisplayTitle))
                    .font(.headline)

                HStack {
                    Text(appStore.localized(.dockDisplayToggle))
                    Spacer()
                    Toggle("", isOn: $appStore.showInDock)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Text(appStore.localized(.dockDisplayDescription))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(appStore.localized(.startAtLoginTitle))
                    .font(.headline)

                HStack {
                    Text(appStore.localized(.startAtLoginToggle))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appStore.startAtLoginSilent },
                        set: { newValue in
                            appStore.setStartAtLoginSilent(newValue) { hint in
                                iconImportError = hint
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(appStore.isTogglingLoginItem)
                }

                Text(appStore.localized(.startAtLoginDescription))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(appStore.localized(.customIconTitle))
                    .font(.headline)
                HStack(spacing: 16) {
                    Image(nsImage: appStore.currentAppIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            ).stroke(Color.white.opacity(0.1))
                        )
                        .shadow(radius: 6, y: 3)

                    VStack(alignment: .leading, spacing: 8) {
                        Button(appStore.localized(.customIconChoose)) {
                            presentAppIconPicker()
                        }
                        .buttonStyle(.bordered)

                        Button(appStore.localized(.customIconReset)) {
                            appStore.resetCustomAppIcon()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(!appStore.hasCustomAppIcon)
                    }
                }

                Text(appStore.localized(.customIconHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(appStore.localized(.importSystem))
                    .font(.headline)
                HStack(spacing: 12) {
                    Button {
                        importFromLaunchpad()
                    } label: {
                        Label(
                            appStore.localized(.importSystem),
                            systemImage: "square.and.arrow.down.on.square"
                        )
                    }
                    .help(appStore.localized(.importTip))

                    Button {
                        importLegacyArchive()
                    } label: {
                        Label(
                            appStore.localized(.importLegacy),
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                }
                Text(appStore.localized(.importTip))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        exportDataFolder()
                    } label: {
                        Label(
                            appStore.localized(.exportData),
                            systemImage: "square.and.arrow.up"
                        )
                    }

                    Button {
                        importDataFolder()
                    } label: {
                        Label(
                            appStore.localized(.importData),
                            systemImage: "square.and.arrow.down"
                        )
                    }
                }
            }

            Toggle(
                appStore.localized(.showQuickRefreshButton),
                isOn: $appStore.showQuickRefreshButton
            )
            .toggleStyle(.switch)
            HStack {
                Button {
                    appStore.refresh()
                } label: {
                    Label(
                        appStore.localized(.refresh),
                        systemImage: "arrow.clockwise"
                    )
                }
                Spacer()
                Button {
                    AppDelegate.shared?.isShowingModalPanel = true
                    showResetConfirm = true
                } label: {
                    Label(
                        appStore.localized(.resetLayout),
                        systemImage: "arrow.counterclockwise"
                    )
                    .foregroundStyle(Color.red)
                }
                .alert(
                    appStore.localized(.resetAlertTitle),
                    isPresented: $showResetConfirm
                ) {
                    Button(
                        appStore.localized(.resetConfirm),
                        role: .destructive
                    ) {
                        AppDelegate.shared?.isShowingModalPanel = false
                        appStore.resetLayout()
                    }
                    Button(appStore.localized(.cancel), role: .cancel) {
                        AppDelegate.shared?.isShowingModalPanel = false
                    }
                } message: {
                    Text(appStore.localized(.resetAlertMessage))
                }
                Button {
                    AppDelegate.shared?.quitWithFade()
                } label: {
                    Label(
                        appStore.localized(.quit),
                        systemImage: "xmark.circle"
                    )
                    .foregroundStyle(Color.red)
                }
            }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(appStore.localized(.classicMode))
                    Spacer()
                    Toggle("", isOn: $appStore.isFullscreenMode)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.showLabels))
                    Spacer()
                    Toggle("", isOn: $appStore.showLabels)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.useLocalizedThirdPartyTitles))
                    Spacer()
                    Toggle("", isOn: $appStore.useLocalizedThirdPartyTitles)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.predictDrop))
                    Spacer()
                    Toggle("", isOn: $appStore.enableDropPrediction)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.enableAnimations))
                    Spacer()
                    Toggle("", isOn: $appStore.enableAnimations)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.hoverMagnification))
                    Spacer()
                    Toggle("", isOn: $appStore.enableHoverMagnification)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Text(appStore.localized(.activePressEffect))
                    Spacer()
                    Toggle("", isOn: $appStore.enableActivePressEffect)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.backgroundStyleTitle))
                        .font(.headline)
                    Picker("", selection: $appStore.launchpadBackgroundStyle) {
                        ForEach(AppStore.BackgroundStyle.allCases) { style in
                            Text(appStore.localized(style.localizationKey)).tag(
                                style
                            )
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.animationDurationLabel))
                        .font(.headline)
                    Slider(
                        value: $appStore.animationDuration,
                        in: 0.1...1.0,
                        step: 0.05
                    )
                    .disabled(!appStore.enableAnimations)
                    HStack {
                        Text("0.1s").font(.footnote)
                        Spacer()
                        Text(
                            String(format: "%.2fs", appStore.animationDuration)
                        )
                        .font(.footnote)
                        Spacer()
                        Text("1.0s").font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.iconLabelFontWeight))
                        .font(.headline)
                    Picker("", selection: $appStore.iconLabelFontWeight) {
                        ForEach(AppStore.IconLabelFontWeightOption.allCases) {
                            option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.iconSize))
                        .font(.headline)
                    Slider(value: $appStore.iconScale, in: 0.8...1.1)
                    HStack {
                        Text(appStore.localized(.smaller)).font(.footnote)
                        Spacer()
                        Text(appStore.localized(.larger)).font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appStore.localized(.folderWindowWidth))
                            .font(.headline)
                        Spacer()
                        Text(
                            String(
                                format: "%.0f%%",
                                appStore.folderPopoverWidthFactor * 100
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $appStore.folderPopoverWidthFactor,
                        in: AppStore.folderPopoverWidthRange
                    )
                    .disabled(appStore.isFullscreenMode)
                    HStack {
                        Text(
                            String(
                                format: "%.0f%%",
                                AppStore.folderPopoverWidthRange.lowerBound
                                    * 100
                            )
                        )
                        .font(.footnote)
                        Spacer()
                        Text(
                            String(
                                format: "%.0f%%",
                                AppStore.folderPopoverWidthRange.upperBound
                                    * 100
                            )
                        )
                        .font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appStore.localized(.folderWindowHeight))
                            .font(.headline)
                        Spacer()
                        Text(
                            String(
                                format: "%.0f%%",
                                appStore.folderPopoverHeightFactor * 100
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $appStore.folderPopoverHeightFactor,
                        in: AppStore.folderPopoverHeightRange
                    )
                    .disabled(appStore.isFullscreenMode)
                    HStack {
                        Text(
                            String(
                                format: "%.0f%%",
                                AppStore.folderPopoverHeightRange.lowerBound
                                    * 100
                            )
                        )
                        .font(.footnote)
                        Spacer()
                        Text(
                            String(
                                format: "%.0f%%",
                                AppStore.folderPopoverHeightRange.upperBound
                                    * 100
                            )
                        )
                        .font(.footnote)
                    }
                }

                Text(appStore.localized(.folderWindowSizeHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.hoverMagnificationScale))
                        .font(.headline)
                    Slider(
                        value: $appStore.hoverMagnificationScale,
                        in: AppStore.hoverMagnificationRange
                    )
                    .disabled(!appStore.enableHoverMagnification)
                    HStack {
                        Text(
                            String(
                                format: "%.2fx",
                                AppStore.hoverMagnificationRange.lowerBound
                            )
                        )
                        .font(.footnote)
                        Spacer()
                        Text(
                            String(
                                format: "%.2fx",
                                appStore.hoverMagnificationScale
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        Spacer()
                        Text(
                            String(
                                format: "%.2fx",
                                AppStore.hoverMagnificationRange.upperBound
                            )
                        )
                        .font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.activePressScale))
                        .font(.headline)
                    Slider(
                        value: $appStore.activePressScale,
                        in: AppStore.activePressScaleRange
                    )
                    .disabled(!appStore.enableActivePressEffect)
                    HStack {
                        Text(
                            String(
                                format: "%.2fx",
                                AppStore.activePressScaleRange.lowerBound
                            )
                        )
                        .font(.footnote)
                        Spacer()
                        Text(String(format: "%.2fx", appStore.activePressScale))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(
                            String(
                                format: "%.2fx",
                                AppStore.activePressScaleRange.upperBound
                            )
                        )
                        .font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appStore.localized(.iconsPerRow))
                            .font(.headline)
                        Spacer()
                        Stepper(
                            value: $appStore.gridColumnsPerPage,
                            in: AppStore.gridColumnRange
                        ) {
                            Text("\(appStore.gridColumnsPerPage)")
                                .font(.callout.monospacedDigit())
                        }
                        .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appStore.localized(.rowsPerPage))
                            .font(.headline)
                        Spacer()
                        Stepper(
                            value: $appStore.gridRowsPerPage,
                            in: AppStore.gridRowRange
                        ) {
                            Text("\(appStore.gridRowsPerPage)")
                                .font(.callout.monospacedDigit())
                        }
                        .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appStore.localized(.iconHorizontalSpacing))
                            .font(.headline)
                        Spacer()
                        Text("\(Int(appStore.iconColumnSpacing)) pt")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $appStore.iconColumnSpacing,
                        in: AppStore.columnSpacingRange,
                        step: 1
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(appStore.localized(.iconVerticalSpacing))
                            .font(.headline)
                        Spacer()
                        Text("\(Int(appStore.iconRowSpacing)) pt")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $appStore.iconRowSpacing,
                        in: AppStore.rowSpacingRange,
                        step: 1
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(appStore.localized(.gridSizeChangeWarning))
                    Text(appStore.localized(.pageIndicatorHint))
                        .foregroundStyle(.tertiary)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.globalShortcutTitle))
                        .font(.headline)
                    HStack(spacing: 12) {
                        Button {
                            if isCapturingShortcut {
                                stopShortcutCapture(cancel: true)
                            } else {
                                startShortcutCapture()
                            }
                        } label: {
                            Text(
                                isCapturingShortcut
                                    ? appStore.localized(.cancel)
                                    : appStore.localized(.shortcutSetButton)
                            )
                        }

                        Button(appStore.localized(.shortcutSaveButton)) {
                            savePendingShortcut()
                        }
                        .disabled(
                            !(isCapturingShortcut && pendingShortcut != nil)
                        )

                        Button(appStore.localized(.shortcutClearButton)) {
                            stopShortcutCapture(cancel: false)
                            pendingShortcut = nil
                            appStore.clearGlobalHotKey()
                        }
                        .disabled(
                            !isCapturingShortcut && appStore.globalHotKey == nil
                        )
                    }

                    Text(shortcutStatusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Toggle(
                    appStore.localized(.rememberPageTitle),
                    isOn: $appStore.rememberLastPage
                )
                .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.labelFontSize))
                        .font(.headline)
                    Slider(
                        value: $appStore.iconLabelFontSize,
                        in: 9...16,
                        step: 0.5
                    )
                    HStack {
                        Text("9pt").font(.footnote)
                        Spacer()
                        Text("16pt").font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.scrollSensitivity))
                        .font(.headline)
                    Slider(value: $appStore.scrollSensitivity, in: 0.01...0.99)
                    HStack {
                        Text(appStore.localized(.low)).font(.footnote)
                        Spacer()
                        Text(appStore.localized(.high)).font(.footnote)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appStore.localized(.pageIndicatorOffsetLabel))
                        .font(.headline)
                    Slider(value: $appStore.pageIndicatorOffset, in: 0...80)
                    HStack {
                        Text("0").font(.footnote)
                        Spacer()
                        Text(
                            String(format: "%.0f", appStore.pageIndicatorOffset)
                        ).font(.footnote)
                        Spacer()
                        Text("80").font(.footnote)
                    }
                }
            }
        }
    }

    // MARK: - Export / Import Application Support Data
    private func supportDirectoryURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent(
            "LaunchOne",
            isDirectory: true
        )
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func exportDataFolder() {
        do {
            let sourceDir = try supportDirectoryURL()
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = appStore.localized(.chooseButton)
            panel.message = appStore.localized(.exportPanelMessage)
            
            // Set a flag to prevent the settings window from closing while a modal panel is shown
            AppDelegate.shared?.isShowingModalPanel = true
            defer { AppDelegate.shared?.isShowingModalPanel = false }
            
            if panel.runModal() == .OK, let destParent = panel.url {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let folderName =
                    "LaunchOne_Export_" + formatter.string(from: Date())
                let destDir = destParent.appendingPathComponent(
                    folderName,
                    isDirectory: true
                )
                try copyDirectory(from: sourceDir, to: destDir)
            }
        } catch {
            // Ignore errors here or add a user notification
        }
    }

    private func importDataFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = appStore.localized(.importPrompt)
        panel.message = appStore.localized(.importPanelMessage)
        
        // Set a flag to prevent the settings window from closing while a modal panel is shown
        AppDelegate.shared?.isShowingModalPanel = true
        defer { AppDelegate.shared?.isShowingModalPanel = false }
        
        if panel.runModal() == .OK, let srcDir = panel.url {
            do {
                // Validate that this is a valid sorting data directory
                guard isValidExportFolder(srcDir) else { return }
                let destDir = try supportDirectoryURL()
                // Skip if the user selected the destination directory
                if srcDir.standardizedFileURL == destDir.standardizedFileURL {
                    return
                }
                try replaceDirectory(with: srcDir, at: destDir)
                // After import, load and refresh
                appStore.applyOrderAndFolders()
                appStore.refresh()
            } catch {
                // Ignore errors here or add a user notification
            }
        }
    }

    private func copyDirectory(from src: URL, to dst: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dst.path) {
            try fm.removeItem(at: dst)
        }
        try fm.copyItem(at: src, to: dst)
    }

    private func replaceDirectory(with src: URL, at dst: URL) throws {
        let fm = FileManager.default
        // Ensure the parent directory exists
        let parent = dst.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(
                at: parent,
                withIntermediateDirectories: true
            )
        }
        if fm.fileExists(atPath: dst.path) {
            try fm.removeItem(at: dst)
        }
        try fm.copyItem(at: src, to: dst)
    }

    private func isValidExportFolder(_ folder: URL) -> Bool {
        let fm = FileManager.default
        let storeURL = folder.appendingPathComponent("Data.store")
        guard fm.fileExists(atPath: storeURL.path) else { return false }
        // Try opening the store and check whether there is ordering data
        do {
            let config = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(
                for: TopItemData.self,
                PageEntryData.self,
                configurations: config
            )
            let ctx = container.mainContext
            let pageEntries = try ctx.fetch(FetchDescriptor<PageEntryData>())
            if !pageEntries.isEmpty { return true }
            let legacyEntries = try ctx.fetch(FetchDescriptor<TopItemData>())
            return !legacyEntries.isEmpty
        } catch {
            return false
        }
    }

    private func importFromLaunchpad() {
        Task {
            let result = await appStore.importFromNativeLaunchpad()

                DispatchQueue.main.async {
                    let alert = NSAlert()
                    if result.success {
                        alert.messageText = appStore.localized(
                            .importSuccessfulTitle
                        )
                        alert.informativeText = result.message
                        alert.alertStyle = .informational
                    } else {
                        alert.messageText = appStore.localized(.importFailedTitle)
                        alert.informativeText = result.message
                        alert.alertStyle = .warning
                    }
                    alert.addButton(withTitle: appStore.localized(.okButton))
                    
                    // Set a flag to prevent the settings window from closing while a modal panel is shown
                    AppDelegate.shared?.isShowingModalPanel = true
                    defer { AppDelegate.shared?.isShowingModalPanel = false }
                    
                    alert.runModal()
                }
        }
    }

    private func importLegacyArchive() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "lmy")!,
            UTType.zip,
            UTType(filenameExtension: "db")!,
        ]
        panel.prompt = appStore.localized(.importPrompt)
        panel.message = appStore.localized(.legacyArchivePanelMessage)

        // Set a flag to prevent the settings window from closing while a modal panel is shown
        AppDelegate.shared?.isShowingModalPanel = true
        defer { AppDelegate.shared?.isShowingModalPanel = false }

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                let result = await appStore.importFromLegacyLaunchpadArchive(
                    url: url
                )
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    if result.success {
                        alert.messageText = appStore.localized(
                            .importSuccessfulTitle
                        )
                        alert.informativeText = result.message
                        alert.alertStyle = .informational
                    } else {
                        alert.messageText = appStore.localized(
                            .importFailedTitle
                        )
                        alert.informativeText = result.message
                        alert.alertStyle = .warning
                    }
                    alert.addButton(withTitle: appStore.localized(.okButton))
                    
                    // Set a flag to prevent the settings window from closing while a modal panel is shown
                    AppDelegate.shared?.isShowingModalPanel = true
                    defer { AppDelegate.shared?.isShowingModalPanel = false }
                    
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Update Check Section
    private var updateCheckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appStore.localized(.checkForUpdates))
                        .font(.headline)

                    switch appStore.updateState {
                    case .idle:
                        Button(action: {
                            appStore.checkForUpdates()
                        }) {
                            Label(
                                appStore.localized(.checkForUpdatesButton),
                                systemImage: "arrow.clockwise"
                            )
                        }
                        .buttonStyle(.bordered)

                    case .checking:
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(appStore.localized(.checkingForUpdates))
                                .foregroundStyle(.secondary)
                        }

                    case .upToDate(_):
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(appStore.localized(.upToDate))
                                .foregroundStyle(.secondary)
                        }

                    case .updateAvailable(let release):
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "party.popper.fill")
                                    .foregroundStyle(.orange)
                                Text(appStore.localized(.updateAvailable))
                                    .font(.subheadline.weight(.medium))
                            }

                            Text(
                                appStore.localized(.newVersion)
                                    + " \(release.version)"
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                            if let notes = release.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            Button(action: {
                                appStore.openReleaseURL(release.url)
                            }) {
                                Label(
                                    appStore.localized(.downloadUpdate),
                                    systemImage: "arrow.down.circle"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                        }

                    case .failed(let error):
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(
                                    systemName: "exclamationmark.triangle.fill"
                                )
                                .foregroundStyle(.red)
                                Text(appStore.localized(.updateCheckFailed))
                                    .font(.subheadline.weight(.medium))
                            }

                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button(action: {
                                appStore.checkForUpdates()
                            }) {
                                Label(
                                    appStore.localized(.tryAgain),
                                    systemImage: "arrow.clockwise"
                                )
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                Spacer()
            }

            #if DEBUG
                HStack(spacing: 12) {
                    Button("Simulate Update Available") {
                        appStore.simulateUpdateAvailable()
                    }
                    Button("Simulate Update Failure") {
                        appStore.simulateUpdateFailure()
                    }
                }
                .font(.footnote)
            #endif

            // Automatically check for updates toggle
            Toggle(
                appStore.localized(.autoCheckForUpdates),
                isOn: $appStore.autoCheckForUpdates
            )
            .font(.footnote)
        }
    }
}
