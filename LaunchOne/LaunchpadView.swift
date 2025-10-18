import AppKit
import Combine
import CoreVideo
import QuartzCore
import SwiftUI

// MARK: - LaunchpadItem extension
extension LaunchpadItem {
    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }
}

// MARK: - Simplified page flip manager
private class PageFlipManager: ObservableObject {
    @Published var isCooldown: Bool = false
    private var lastFlipTime: Date?
    var autoFlipInterval: TimeInterval = 0.8

    func canFlip() -> Bool {
        guard !isCooldown else { return false }
        guard let lastTime = lastFlipTime else { return true }
        return Date().timeIntervalSince(lastTime) >= autoFlipInterval
    }

    func recordFlip() {
        lastFlipTime = Date()
        isCooldown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + autoFlipInterval) {
            self.isCooldown = false
        }
    }
}

private final class FPSMonitor {
    private var displayLink: CADisplayLink?
    private var lastFPSUpdate: CFTimeInterval = 0
    private var frameCount: Int = 0
    private let callback: (Double, Double) -> Void

    init(callback: @escaping (Double, Double) -> Void) {
        self.callback = callback
    }

    func start() {
        stop()
        lastFPSUpdate = CACurrentMediaTime()
        frameCount = 0

        if let screen = NSScreen.main {
            let link = screen.displayLink(
                target: self,
                selector: #selector(step(link:))
            )
            self.displayLink = link
            link.add(to: .current, forMode: .default)
        }
    }

    @objc private func step(link: CADisplayLink) {
        let currentTimestamp = CACurrentMediaTime()
        frameCount += 1

        if currentTimestamp - lastFPSUpdate >= 1.0 {
            let delta = currentTimestamp - lastFPSUpdate
            let fps = Double(frameCount) / delta
            let frameTime = 1.0 / fps

            callback(fps, frameTime)

            frameCount = 0
            lastFPSUpdate = currentTimestamp
        }
    }

    func stop() {
        if let link = displayLink {
            link.invalidate()  // ✅ Use invalidate() for CADisplayLink
            displayLink = nil
        }
    }

    deinit {
        stop()
    }
}

extension View {
    @ViewBuilder
    fileprivate func launchpadBackgroundStyle(
        _ style: AppStore.BackgroundStyle,
        cornerRadius: CGFloat
    ) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )
        switch style {
        case .glass:
            self.liquidGlass(in: shape)
        case .blur:
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

struct LaunchpadView: View {
    @ObservedObject var appStore: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var keyMonitor: Any?
    @State private var windowObserver: NSObjectProtocol?
    @State private var windowHiddenObserver: NSObjectProtocol?
    @State private var draggingItem: LaunchpadItem?
    @State private var dragPreviewPosition: CGPoint = .zero
    @State private var dragPreviewScale: CGFloat = 1.2
    @State private var pendingDropIndex: Int? = nil
    @StateObject private var pageFlipManager = PageFlipManager()
    @State private var folderHoverCandidateIndex: Int? = nil
    @State private var folderHoverBeganAt: Date? = nil
    @State private var selectedIndex: Int? = nil
    @State private var isKeyboardNavigationActive: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    @Namespace private var reorderNamespace
    @State private var handoffEventMonitor: Any? = nil
    @State private var globalMouseUpMonitor: Any? = nil
    @State private var gridOriginInWindow: CGPoint = .zero
    @State private var currentContainerSize: CGSize = .zero
    @State private var currentColumnWidth: CGFloat = 0
    @State private var currentAppHeight: CGFloat = 0
    @State private var currentIconSize: CGFloat = 0
    @State private var headerTotalHeight: CGFloat = 0

    // Performance: use static cache to avoid state mutation issues
    private static var geometryCache: [String: CGPoint] = [:]
    private static var lastGeometryUpdate: Date = Date.distantPast
    private let geometryCacheTimeout: TimeInterval = 0.1  // 100ms cache timeout

    @State private var isHandoffDragging: Bool = false
    @State private var isUserSwiping: Bool = false
    @State private var accumulatedScrollX: CGFloat = 0
    @State private var wheelAccumulatedSinceFlip: CGFloat = 0
    @State private var wheelLastDirection: Int = 0
    @State private var wheelLastFlipAt: Date? = nil
    private let wheelFlipCooldown: TimeInterval = 0.15
    @State private var dragPointerOffset: CGPoint = .zero
    @State private var blankDragStartPoint: CGPoint? = nil
    @State private var blankDragShouldIgnore: Bool = false
    @State private var blankDragConsumed: Bool = false
    @State private var fpsMonitor: FPSMonitor?
    @State private var fpsValue: Double = 0
    @State private var frameTimeMilliseconds: Double = 0
    @State private var isWindowVisible: Bool = true
    @State private var draggingOriginIndex: Int? = nil

    private var isFolderOpen: Bool { appStore.openFolder != nil }

    private var config: GridConfig {
        GridConfig(
            isFullscreen: appStore.isFullscreenMode,
            columns: appStore.gridColumnsPerPage,
            rows: appStore.gridRowsPerPage,
            columnSpacing: CGFloat(appStore.iconColumnSpacing),
            rowSpacing: CGFloat(appStore.iconRowSpacing)
        )
    }

    private var backdropOpacity: Double {
        appStore.isFullscreenMode ? (colorScheme == .dark ? 0.30 : 0.25) : 0.0
    }

    var filteredItems: [LaunchpadItem] {
        let query = appStore.searchQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else { return appStore.items }

        // Normalize query for pinyin matching: lowercase, strip diacritics, remove spaces
        func normalizedQuery(_ q: String) -> (raw: String, folded: String) {
            let raw = q
            let lowered = q.lowercased()
            let mutable = NSMutableString(string: lowered)
            CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
            let folded = String(mutable).replacingOccurrences(of: " ", with: "")
            return (raw, folded)
        }
        let q = normalizedQuery(query)

        var result: [LaunchpadItem] = []
        var searchedApps = Set<String>()  // For deduplication; avoid displaying the same app twice

        // Search items on the main grid first
        for item in appStore.items {
            switch item {
            case .app(let app):
                let nameMatch = app.name.localizedCaseInsensitiveContains(query)
                let pinyinMatch = app.pinyinFull.contains(q.folded) || app.pinyinAcronym.contains(q.folded)
                if nameMatch || pinyinMatch {
                    result.append(.app(app))
                    searchedApps.insert(app.url.path)
                }
            case .folder(let folder):
                // Check folder name
                if folder.name.localizedCaseInsensitiveContains(query) {
                    result.append(.folder(folder))
                }

                // Check apps inside the folder; if matched, extract and show directly
                let matchingApps = folder.apps.filter { app in
                    let nameMatch = app.name.localizedCaseInsensitiveContains(query)
                    let pinyinMatch = app.pinyinFull.contains(q.folded) || app.pinyinAcronym.contains(q.folded)
                    return nameMatch || pinyinMatch
                }
                for app in matchingApps {
                    if !searchedApps.contains(app.url.path) {
                        // Ensure the app object is valid and icon is available
                        let icon =
                            app.icon.size.width > 0
                            ? app.icon
                            : NSWorkspace.shared.icon(forFile: app.url.path)
                        let validApp = AppInfo(
                            name: app.name,
                            icon: icon,
                            url: app.url
                        )
                        result.append(.app(validApp))
                        searchedApps.insert(app.url.path)
                    }
                }

            case .empty:
                break
            }
        }

        // Relevance sorting (apps): consider name and pinyin
        // exact > prefix > substring on name, then same tiers on pinyinFull, then acronym hit
        func scoreForApp(_ app: AppInfo) -> Int {
            let lowerName = app.name.lowercased()
            let lowerQ = query.lowercased()
            if lowerName == lowerQ { return 6 }
            if lowerName.hasPrefix(lowerQ) { return 5 }
            if lowerName.contains(lowerQ) { return 4 }
            if app.pinyinFull == q.folded { return 3 }
            if app.pinyinFull.hasPrefix(q.folded) { return 2 }
            if app.pinyinFull.contains(q.folded) { return 1 }
            if app.pinyinAcronym.contains(q.folded) { return 1 }
            return 0
        }

        // Relevance sorting (folders): only name
        func scoreForName(_ name: String, q: String) -> Int {
            let lowerName = name.lowercased()
            let lowerQ = q.lowercased()
            if lowerName == lowerQ { return 3 }
            if lowerName.hasPrefix(lowerQ) { return 2 }
            if lowerName.contains(lowerQ) { return 1 }
            return 0
        }

        // Keep a map to stabilize by original order as final tie-breaker
        var originalIndex: [String: Int] = [:]  // key: LaunchpadItem.id-like
        for (idx, item) in appStore.items.enumerated() {
            switch item {
            case .app(let app):
                originalIndex[app.url.path] = idx
            case .folder(let folder):
                originalIndex["folder:\\(folder.id)"] = idx
                for inner in folder.apps {
                    if originalIndex[inner.url.path] == nil {
                        originalIndex[inner.url.path] = idx
                    }
                }
            case .empty:
                break
            }
        }

        let sorted = result.sorted { a, b in
            func key(_ item: LaunchpadItem) -> (Int, String, Int) {
                switch item {
                case .app(let app):
                    let s = scoreForApp(app)
                    let alpha = app.name.lowercased()
                    let orig = originalIndex[app.url.path] ?? Int.max
                    return (s, alpha, orig)
                case .folder(let folder):
                    let s = scoreForName(folder.name, q: query)
                    let alpha = folder.name.lowercased()
                    let orig = originalIndex["folder:\\(folder.id)"] ?? Int.max
                    return (s, alpha, orig)
                case .empty:
                    return (0, "", Int.max)
                }
            }
            let ka = key(a)
            let kb = key(b)
            if ka.0 != kb.0 { return ka.0 > kb.0 }  // higher score first
            if ka.1 != kb.1 { return ka.1 < kb.1 }  // alphabetical
            return ka.2 < kb.2  // original order
        }

        return sorted
    }

    var pages: [[LaunchpadItem]] {
        let items = draggingItem != nil ? visualItems : filteredItems
        return makePages(from: items)
    }

    private var currentItems: [LaunchpadItem] {
        draggingItem != nil ? visualItems : filteredItems
    }

    private var visualItems: [LaunchpadItem] {
        // During dragging, maintain page boundaries to avoid backfilling from next pages.
        // Remove the dragging item from its source page, and insert an invisible placeholder
        // either at the predicted drop index (if available) or back at the original source index.
        guard let dragging = draggingItem else { return filteredItems }

        let itemsPerPage = config.itemsPerPage
        var pageSlices: [[LaunchpadItem]] = makePages(from: filteredItems)

        // Locate source page and local index
        guard let sourcePage = pageSlices.firstIndex(where: { $0.contains(dragging) }),
              let sourceLocalIndex = pageSlices[sourcePage].firstIndex(of: dragging) else {
            // Fallback to simple removal if we cannot locate the source reliably
            return filteredItems.filter { $0 != dragging }
        }

        // Remove from source page
        pageSlices[sourcePage].remove(at: sourceLocalIndex)

        if let pending = pendingDropIndex {
            // Insert placeholder at the target page/local index
            let targetPage = max(0, pending / itemsPerPage)
            let desiredLocal = pending % itemsPerPage

            while pageSlices.count <= targetPage { pageSlices.append([]) }
            let localIndex = max(0, min(desiredLocal, pageSlices[targetPage].count))
            pageSlices[targetPage].insert(
                makePlaceholder(for: dragging, page: targetPage, localIndex: localIndex),
                at: localIndex
            )

            // Cascade forward if any page overflows
            cascadeOverflow(&pageSlices, startingAt: targetPage, itemsPerPage: itemsPerPage)
        } else {
            // No hover target: keep page sizes stable by inserting placeholder
            // back into the source page at the original local index (or end if shortened)
            let insertLocal = max(0, min(sourceLocalIndex, pageSlices[sourcePage].count))
            pageSlices[sourcePage].insert(
                makePlaceholder(for: dragging, page: sourcePage, localIndex: insertLocal),
                at: insertLocal
            )
        }

        return pageSlices.flatMap { $0 }
    }

    // MARK: - Drag preview helpers (no behavior change; readability only)
    private func makePlaceholder(
        for dragging: LaunchpadItem,
        page: Int,
        localIndex: Int
    ) -> LaunchpadItem {
        return .empty("placeholder_\(dragging.id)_p\(page)_l\(localIndex)")
    }

    private func cascadeOverflow(
        _ pageSlices: inout [[LaunchpadItem]],
        startingAt startPage: Int,
        itemsPerPage: Int
    ) {
        var p = startPage
        while p < pageSlices.count {
            if pageSlices[p].count > itemsPerPage {
                let spilled = pageSlices[p].removeLast()
                if p + 1 >= pageSlices.count { pageSlices.append([]) }
                pageSlices[p + 1].insert(spilled, at: 0)
                p += 1
            } else {
                p += 1
            }
        }
    }

    private func makePages(from items: [LaunchpadItem]) -> [[LaunchpadItem]] {
        guard !items.isEmpty else { return [] }
        return stride(from: 0, to: items.count, by: config.itemsPerPage).map {
            start in
            let end = min(start + config.itemsPerPage, items.count)
            return Array(items[start..<end])
        }
    }

    var body: some View {
        GeometryReader { geo in
            let actualTopPadding =
                config.isFullscreen ? geo.size.height * config.topPadding : 0
            let actualBottomPadding =
                config.isFullscreen ? geo.size.height * config.bottomPadding : 0
            let actualHorizontalPadding =
                config.isFullscreen
                ? geo.size.width * config.horizontalPadding : 0

            VStack {
                // Add dynamic top padding (fullscreen mode)
                if config.isFullscreen {
                    Spacer()
                        .frame(height: actualTopPadding)
                }
                ZStack {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(
                            appStore.localized(.searchPlaceholder),
                            text: $appStore.searchText
                        )
                        .textFieldStyle(.plain)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .liquidGlass(
                        in: RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
                    .frame(maxWidth: 480)
                    .disabled(isFolderOpen)
                    .onChange(of: appStore.searchQuery) {
                        guard !isFolderOpen else { return }
                        // Avoid publishing changes within the current update cycle; defer to the next runloop
                        let maxPageIndex = max(pages.count - 1, 0)
                        DispatchQueue.main.async {
                            appStore.currentPage = 0
                            if appStore.currentPage > maxPageIndex {
                                appStore.currentPage = maxPageIndex
                            }
                        }
                        selectedIndex = filteredItems.isEmpty ? nil : 0
                        isKeyboardNavigationActive = false
                        clampSelection()
                    }
                    .focused($isSearchFieldFocused)
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 8) {
                        Spacer()
                        if appStore.showQuickRefreshButton {
                            Button {
                                appStore.refresh()
                            } label: {
                                Image(systemName: "arrow.clockwise.circle")
                                    .font(.title)
                                    .foregroundStyle(.placeholder.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .help(appStore.localized(.refresh))
                        }
                        Button {
                            appStore.settingsInitialSection = .general
                            appStore.isSetting = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title)
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top)
                .padding(.horizontal)
                .background(
                    GeometryReader { proxy in
                        // Record the total height of the top area (dynamic top padding + area height + extra)
                        Color.clear.onAppear {
                            let extra: CGFloat = 24
                            let total =
                                (config.isFullscreen
                                    ? geo.size.height * config.topPadding : 0)
                                + proxy.size.height + extra
                            DispatchQueue.main.async {
                                headerTotalHeight = total
                            }
                        }
                        .onChange(of: proxy.size) { _, _ in
                            let extra: CGFloat = 24
                            let total =
                                (config.isFullscreen
                                    ? geo.size.height * config.topPadding : 0)
                                + proxy.size.height + extra
                            DispatchQueue.main.async {
                                headerTotalHeight = total
                            }
                        }
                    }
                )
                .opacity(isFolderOpen ? 0.1 : 1)
                .allowsHitTesting(!isFolderOpen)

                // Keep vertical spacing; remove visible separators
                Spacer()
                    .frame(height: 16)

                GeometryReader { geo in
                    let appCountPerRow = config.columns
                    let maxRowsPerPage = Int(
                        ceil(
                            Double(config.itemsPerPage) / Double(appCountPerRow)
                        )
                    )
                    let availableWidth = geo.size.width
                    let availableHeight =
                        geo.size.height
                        - (actualTopPadding + actualBottomPadding)

                    let appHeight: CGFloat = {
                        let totalRowSpacing =
                            config.rowSpacing * CGFloat(maxRowsPerPage - 1)
                        let height =
                            (availableHeight - totalRowSpacing)
                            / CGFloat(maxRowsPerPage)
                        return max(56, height)
                    }()

                    let columnWidth: CGFloat = {
                        let totalColumnSpacing =
                            config.columnSpacing * CGFloat(appCountPerRow - 1)
                        let width =
                            (availableWidth - totalColumnSpacing)
                            / CGFloat(appCountPerRow)
                        return max(40, width)
                    }()

                    let iconSize: CGFloat =
                        min(columnWidth, appHeight)
                        * CGFloat(min(max(appStore.iconScale, 0.6), 1.15))

                    let effectivePageWidth = geo.size.width + config.pageSpacing

                    // Helper: decide whether to close when tapping at a point in grid space
                    let _: (CGPoint) -> Void = { p in
                        guard appStore.openFolder == nil, draggingItem == nil
                        else { return }
                        if let idx = indexAt(
                            point: p,
                            in: geo.size,
                            pageIndex: appStore.currentPage,
                            columnWidth: columnWidth,
                            appHeight: appHeight
                        ) {
                            if currentItems.indices.contains(idx),
                                case .empty = currentItems[idx]
                            {
                                AppDelegate.shared?.hideWindow()
                            }
                        } else {
                            AppDelegate.shared?.hideWindow()
                        }
                    }

                    if appStore.isInitialLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                                .progressViewStyle(.circular)
                            Text(appStore.localized(.loadingApplications))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredItems.isEmpty
                        && !appStore.searchQuery.isEmpty
                    {
                        VStack(spacing: 20) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.placeholder)
                            Text(appStore.localized(.noAppsFound))
                                .font(.title)
                                .foregroundStyle(.placeholder)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        let hStackOffset =
                            -CGFloat(appStore.currentPage) * effectivePageWidth
                        ZStack(alignment: .topLeading) {
                            // Content
                            HStack(spacing: config.pageSpacing) {
                                ForEach(pages.indices, id: \.self) { index in
                                    VStack(alignment: .leading, spacing: 0) {
                                        // Add dynamic padding above the grid
                                        if config.isFullscreen {
                                            Spacer()
                                                .frame(height: actualTopPadding)
                                        }
                                        LazyVGrid(
                                            columns: config.gridItems,
                                            spacing: config.rowSpacing
                                        ) {
                                            let pageItems = pages[index]
                                            ForEach(
                                                0..<pageItems.count,
                                                id: \.self
                                            ) { localOffset in
                                                let item = pageItems[
                                                    localOffset
                                                ]
                                                let globalIndex =
                                                    index * config.itemsPerPage
                                                    + localOffset
                                                itemDraggable(
                                                    item: item,
                                                    globalIndex: globalIndex,
                                                    pageIndex: index,
                                                    containerSize: geo.size,
                                                    columnWidth: columnWidth,
                                                    iconSize: iconSize,
                                                    appHeight: appHeight,
                                                    labelWidth: columnWidth
                                                        * 0.9,
                                                    isSelected: (!isFolderOpen
                                                        && isKeyboardNavigationActive
                                                        && selectedIndex
                                                            == globalIndex)
                                                )
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, config.columnSpacing / 2)
                                        .animation(
                                            LNAnimations.gridUpdate,
                                            value: pendingDropIndex
                                        )
                                        .id(
                                            "grid_\(index)_\(appStore.gridRefreshTrigger.uuidString)"
                                        )
                                        // Avoid unnecessary global refresh animations to reduce drag repainting
                                        .frame(
                                            maxHeight: .infinity,
                                            alignment: .top
                                        )
                                    }
                                    .frame(
                                        width: geo.size.width,
                                        height: geo.size.height
                                    )
                                }
                            }
                            .offset(x: hStackOffset)
                            .opacity(isFolderOpen ? 0.1 : 1)
                            .allowsHitTesting(!isFolderOpen)

                            // Elevate preview into outer coordinate space to avoid being affected by offset
                            if let draggingItem {
                                DragPreviewItem(
                                    item: draggingItem,
                                    iconSize: iconSize,
                                    labelWidth: columnWidth * 0.9,
                                    scale: dragPreviewScale
                                )
                                .position(
                                    x: dragPreviewPosition.x,
                                    y: dragPreviewPosition.y
                                )
                                .zIndex(100)
                                .allowsHitTesting(false)
                            }
                        }

                        .coordinateSpace(name: "grid")
                        // Make the entire grid container hittest-able to capture blank-area taps
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            blankDragGesture(
                                geoSize: geo.size,
                                columnWidth: columnWidth,
                                appHeight: appHeight,
                                iconSize: iconSize
                            ),
                            including: .gesture
                        )
                        .onTapGesture {
                            // Remove focus from inputs
                            NSApp.keyWindow?.makeFirstResponder(nil)
                            // Convert from screen to grid coordinates; allow closing when tapping blank areas
                            let p = convertScreenToGrid(NSEvent.mouseLocation)
                            closeIfTappedOnEmptyOrGap(
                                at: p,
                                geoSize: geo.size,
                                columnWidth: columnWidth,
                                appHeight: appHeight,
                                iconSize: iconSize
                            )
                        }
                        .onAppear {}

                        .onChange(of: appStore.handoffDraggingApp) {
                            if appStore.openFolder == nil,
                                appStore.handoffDraggingApp != nil
                            {
                                startHandoffDragIfNeeded(
                                    geo: geo,
                                    columnWidth: columnWidth,
                                    appHeight: appHeight,
                                    iconSize: iconSize
                                )
                            }
                        }
                        .onChange(of: appStore.openFolder) {
                            if appStore.openFolder == nil,
                                appStore.handoffDraggingApp != nil
                            {
                                startHandoffDragIfNeeded(
                                    geo: geo,
                                    columnWidth: columnWidth,
                                    appHeight: appHeight,
                                    iconSize: iconSize
                                )
                            }
                        }
                        .onChange(of: appStore.currentPage) {
                            DispatchQueue.main.async {
                                captureGridGeometry(
                                    geo,
                                    columnWidth: columnWidth,
                                    appHeight: appHeight,
                                    iconSize: iconSize
                                )

                                // Smart preload icons for the current and adjacent pages
                                AppCacheManager.shared.smartPreloadIcons(
                                    for: appStore.items,
                                    currentPage: appStore.currentPage,
                                    itemsPerPage: config.itemsPerPage
                                )
                            }
                        }
                        .onChange(of: appStore.gridRefreshTrigger) { _, _ in
                            DispatchQueue.main.async {
                                captureGridGeometry(
                                    geo,
                                    columnWidth: columnWidth,
                                    appHeight: appHeight,
                                    iconSize: iconSize
                                )
                            }
                        }
                        .onChange(of: geo.size) {
                            DispatchQueue.main.async {
                                captureGridGeometry(
                                    geo,
                                    columnWidth: columnWidth,
                                    appHeight: appHeight,
                                    iconSize: iconSize
                                )
                            }
                        }
                        .task {
                            await MainActor.run {
                                captureGridGeometry(
                                    geo,
                                    columnWidth: columnWidth,
                                    appHeight: appHeight,
                                    iconSize: iconSize
                                )
                            }
                        }
                    }
                }

                // Merged PageIndicator - add tap to jump to page
                if pages.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(
                                    appStore.currentPage == index
                                        ? Color.gray : Color.gray.opacity(0.3)
                                )
                                .frame(width: 8, height: 8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    navigateToPage(index)
                                }
                        }
                    }
                    .padding(.bottom, CGFloat(appStore.pageIndicatorOffset))
                    .opacity(isFolderOpen ? 0.1 : 1)
                    .allowsHitTesting(!isFolderOpen)
                }

                // Add dynamic padding below page indicator dots
                if config.isFullscreen {
                    Spacer()
                        .frame(height: actualBottomPadding)
                }

            }
            .padding(.horizontal, actualHorizontalPadding)
        }
        .padding()
        .launchpadBackgroundStyle(
            appStore.launchpadBackgroundStyle,
            cornerRadius: appStore.isFullscreenMode ? 0 : 30
        )
        .background(
            appStore.isFullscreenMode
                ? Color.black.opacity(backdropOpacity)
                : Color.clear
        )
        .ignoresSafeArea()
        .overlay(
            ZStack {
                // Full-window scroll capture layer (does not intercept taps; listens to scroll only)
                ScrollEventCatcher {
                    deltaX,
                    deltaY,
                    phase,
                    isMomentum,
                    isPrecise in
                    guard !appStore.isSetting else { return }
                    let pageWidth =
                        currentContainerSize.width + config.pageSpacing
                    handleScroll(
                        deltaX: deltaX,
                        deltaY: deltaY,
                        phase: phase,
                        isMomentum: isMomentum,
                        isPrecise: isPrecise,
                        pageWidth: pageWidth
                    )
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Translucent backdrop: only when a folder is open; uses fade transition
                if isFolderOpen {
                    Color.black
                        .opacity(0.1)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            if !appStore.isFolderNameEditing {
                                let closingFolder = appStore.openFolder
                                withAnimation(LNAnimations.springFast) {
                                    appStore.openFolder = nil
                                }
                                if let folder = closingFolder,
                                    let idx = filteredItems.firstIndex(
                                        of: .folder(folder)
                                    )
                                {
                                    isKeyboardNavigationActive = true
                                    selectedIndex = idx
                                    let targetPage = idx / config.itemsPerPage
                                    if targetPage != appStore.currentPage {
                                        appStore.currentPage = targetPage
                                    }
                                }
                                isSearchFieldFocused = true
                            }
                        }
                }

                if let openFolder = appStore.openFolder {
                    GeometryReader { proxy in
                        let widthFactor: CGFloat =
                            appStore.isFullscreenMode
                            ? 0.7 : CGFloat(appStore.folderPopoverWidthFactor)
                        let heightFactor: CGFloat =
                            appStore.isFullscreenMode
                            ? 0.7 : CGFloat(appStore.folderPopoverHeightFactor)
                        let minWidth: CGFloat =
                            appStore.isFullscreenMode ? 520 : 560
                        let minHeight: CGFloat = 420
                        let rawHorizontalMargin: CGFloat =
                            appStore.isFullscreenMode
                            ? max(proxy.size.width * 0.15, 120) : 32
                        let rawVerticalMargin: CGFloat =
                            appStore.isFullscreenMode
                            ? max(proxy.size.height * 0.15, 120) : 32
                        let horizontalMargin = min(
                            rawHorizontalMargin,
                            proxy.size.width / 2
                        )
                        let verticalMargin = min(
                            rawVerticalMargin,
                            proxy.size.height / 2
                        )

                        let proposedWidth = proxy.size.width * widthFactor
                        let proposedHeight = proxy.size.height * heightFactor

                        let maxAllowedWidth = max(
                            proxy.size.width - horizontalMargin * 2,
                            0
                        )
                        let maxAllowedHeight = max(
                            proxy.size.height - verticalMargin * 2,
                            0
                        )

                        let minAllowedWidth = min(minWidth, maxAllowedWidth)
                        let minAllowedHeight = min(minHeight, maxAllowedHeight)

                        let clampedWidth = max(
                            min(proposedWidth, maxAllowedWidth),
                            minAllowedWidth
                        )
                        let clampedHeight = max(
                            min(proposedHeight, maxAllowedHeight),
                            minAllowedHeight
                        )
                        let folderId = openFolder.id

                        // Use a computed binding to correctly respond to folderUpdateTrigger changes
                        let folderBinding = Binding<FolderInfo>(
                            get: {
                                // Re-fetch the folder on every access to ensure the latest state
                                if let idx = appStore.folders.firstIndex(
                                    where: { $0.id == folderId })
                                {
                                    return appStore.folders[idx]
                                }
                                return openFolder
                            },
                            set: { newValue in
                                if let idx = appStore.folders.firstIndex(
                                    where: { $0.id == folderId })
                                {
                                    appStore.folders[idx] = newValue
                                }
                            }
                        )

                        FolderView(
                            appStore: appStore,
                            folder: folderBinding,
                            preferredIconSize: currentIconSize
                                * CGFloat(
                                    min(max(appStore.iconScale, 0.6), 1.15)
                                ),
                            onClose: {
                                let closingFolder = appStore.openFolder
                                withAnimation(LNAnimations.springFast) {
                                    appStore.openFolder = nil
                                }
                                // After closing, move keyboard selection to this folder
                                if let folder = closingFolder,
                                    let idx = filteredItems.firstIndex(
                                        of: .folder(folder)
                                    )
                                {
                                    isKeyboardNavigationActive = true
                                    selectedIndex = idx
                                    let targetPage = idx / config.itemsPerPage
                                    if targetPage != appStore.currentPage {
                                        appStore.currentPage = targetPage
                                    }
                                }
                                // Restore focus to the search field after closing the folder
                                isSearchFieldFocused = true
                            },
                            onLaunchApp: { app in
                                launchApp(app)
                            }
                        )
                        .frame(width: clampedWidth, height: clampedHeight)
                        .position(
                            x: proxy.size.width / 2,
                            y: proxy.size.height / 2
                        )
                        .id("folder_\(folderId)")  // Use a stable ID to avoid view rebuild on updates
                        .transition(LNAnimations.folderOpenTransition)

                    }
                }

                // Click-to-close: not on the top area (including search); clicks on window margins close
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    let topSafe = max(0, headerTotalHeight)
                    let bottomPad = max(
                        config.isFullscreen ? h * config.bottomPadding : 0,
                        24
                    )
                    let sidePad = max(
                        config.isFullscreen ? w * config.horizontalPadding : 0,
                        24
                    )

                    // Top safe area: pass-through
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.clear)
                            .frame(height: topSafe)
                            .allowsHitTesting(false)
                        Spacer()
                        // Bottom margin: click to close
                        Rectangle().fill(Color.clear)
                            .frame(height: bottomPad)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if appStore.openFolder != nil {
                                    // If the folder window is open, close it
                                    withAnimation(LNAnimations.springFast) {
                                        appStore.openFolder = nil
                                    }
                                } else if !appStore.isFolderNameEditing {
                                    // If no folder window is open and not editing, close main window
                                    AppDelegate.shared?.hideWindow()
                                }
                            }
                    }
                    .ignoresSafeArea()

                    // Left/right margins: click to close
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.clear)
                            .frame(width: sidePad)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if appStore.openFolder != nil {
                                    // If the folder window is open, close it
                                    withAnimation(LNAnimations.springFast) {
                                        appStore.openFolder = nil
                                    }
                                } else if !appStore.isFolderNameEditing {
                                    // If no folder window is open and not editing, close main window
                                    AppDelegate.shared?.hideWindow()
                                }
                            }
                        Spacer()
                        Rectangle().fill(Color.clear)
                            .frame(width: sidePad)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if appStore.openFolder != nil {
                                    // If the folder window is open, close it
                                    withAnimation(LNAnimations.springFast) {
                                        appStore.openFolder = nil
                                    }
                                } else if !appStore.isFolderNameEditing {
                                    // If no folder window is open and not editing, close main window
                                    AppDelegate.shared?.hideWindow()
                                }
                            }
                    }
                    .ignoresSafeArea()
                }
            }
        )
        .overlay(alignment: .bottomTrailing) {
            if appStore.showFPSOverlay {
                Text(
                    String(
                        format: "%.0f FPS  %.1f ms",
                        fpsValue,
                        frameTimeMilliseconds
                    )
                )
                .font(.caption.monospacedDigit()).bold()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .padding(18)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appStore.showFPSOverlay)
        .onChange(of: appStore.items) {
            guard draggingItem == nil else { return }
            clampSelection()
            let maxPageIndex = max(pages.count - 1, 0)
            if appStore.currentPage > maxPageIndex {
                appStore.currentPage = maxPageIndex
            }
        }
        .onChange(of: isSearchFieldFocused) { _, focused in
            if focused { isKeyboardNavigationActive = false }
        }

        .onAppear {
            setupKeyHandlers()
            setupInitialSelection()
            setupWindowShownObserver()
            setupWindowHiddenObserver()
            // Listen for global mouse up to clean drag state correctly (when released outside the window)
            if let existing = globalMouseUpMonitor {
                NSEvent.removeMonitor(existing)
            }
            globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
                .leftMouseUp
            ]) { _ in
                if handoffEventMonitor != nil || draggingItem != nil {
                    finalizeHandoffDrag()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if draggingItem != nil {
                        draggingItem = nil
                        pendingDropIndex = nil
                        appStore.isDragCreatingFolder = false
                        appStore.folderCreationTarget = nil
                        pageFlipManager.isCooldown = false
                        isHandoffDragging = false
                        dragPointerOffset = .zero
                        draggingOriginIndex = nil
                        clampSelection()
                    }
                }
            }
            isKeyboardNavigationActive = false
            clampSelection()

            // Check cache status
            checkCacheStatus()
            if appStore.showFPSOverlay {
                startFPSMonitoring()
            }
        }
        .onDisappear {
            [keyMonitor, handoffEventMonitor].forEach { monitor in
                if let monitor = monitor { NSEvent.removeMonitor(monitor) }
            }
            if let monitor = globalMouseUpMonitor {
                NSEvent.removeMonitor(monitor)
            }
            [windowObserver, windowHiddenObserver].forEach { observer in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
            keyMonitor = nil
            handoffEventMonitor = nil
            globalMouseUpMonitor = nil
            windowObserver = nil
            windowHiddenObserver = nil
            stopFPSMonitoring()
        }
        .onChange(of: appStore.showFPSOverlay) { _, enabled in
            if enabled {
                startFPSMonitoring()
            } else {
                stopFPSMonitoring()
                fpsValue = 0
            }
        }
    }

    private func launchApp(_ app: AppInfo) {
        AppDelegate.shared?.hideWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSWorkspace.shared.open(app.url)
        }
    }

    private func handleItemTap(_ item: LaunchpadItem) {
        guard draggingItem == nil else { return }
        switch item {
        case .app(let app):
            launchApp(app)
        case .folder(let folder):
            withAnimation(LNAnimations.springFast) {
                appStore.openFolder = folder
            }
        case .empty:
            break
        }
    }

    // MARK: - Handoff drag from folder
    private func startHandoffDragIfNeeded(
        geo: GeometryProxy,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) {
        guard draggingItem == nil, let app = appStore.handoffDraggingApp else {
            return
        }
        // Update geometry context
        captureGridGeometry(
            geo,
            columnWidth: columnWidth,
            appHeight: appHeight,
            iconSize: iconSize
        )

        // Initial position: screen -> grid-local
        let screenPoint =
            appStore.handoffDragScreenLocation ?? NSEvent.mouseLocation
        let localPoint = convertScreenToGrid(screenPoint)

        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) { draggingItem = .app(app) }
        draggingOriginIndex = nil
        isKeyboardNavigationActive = false
        appStore.isDragCreatingFolder = false
        appStore.folderCreationTarget = nil
        dragPointerOffset = .zero
        dragPreviewScale = 1.2
        dragPreviewPosition = localPoint
        // Make handoff drag consistent with normal drag: pre-create new page to support edge flipping
        isHandoffDragging = true

        // Smart page jump: decide whether to switch to a suitable page based on drag position
        if let targetIndex = indexAt(
            point: localPoint,
            in: currentContainerSize,
            pageIndex: appStore.currentPage,
            columnWidth: columnWidth,
            appHeight: appHeight
        ),
            currentItems.indices.contains(targetIndex)
        {
            let targetPage = targetIndex / config.itemsPerPage
            if targetPage != appStore.currentPage && targetPage < pages.count {
                appStore.currentPage = targetPage
            }
        }

        if let existing = handoffEventMonitor {
            NSEvent.removeMonitor(existing)
        }
        handoffEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .leftMouseDragged, .leftMouseUp,
        ]) { event in
            switch event.type {
            case .leftMouseDragged:
                let lp = convertScreenToGrid(NSEvent.mouseLocation)
                // Reuse the same core update logic as normal drag
                applyDragUpdate(
                    at: lp,
                    containerSize: currentContainerSize,
                    columnWidth: currentColumnWidth,
                    appHeight: currentAppHeight,
                    iconSize: currentIconSize
                )
                return nil
            case .leftMouseUp:
                finalizeHandoffDrag()
                return nil
            default:
                return event
            }
        }

        appStore.handoffDraggingApp = nil
        appStore.handoffDragScreenLocation = nil
    }

    private func convertScreenToGrid(_ screenPoint: CGPoint) -> CGPoint {
        guard let window = NSApp.keyWindow else { return screenPoint }
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        // SwiftUI .global has its origin at the top; AppKit window coords at the bottom — flip y
        let windowHeight =
            window.contentView?.bounds.height ?? window.frame.size.height
        let x = windowPoint.x - gridOriginInWindow.x
        let yFromTop = windowHeight - windowPoint.y
        let y = yFromTop - gridOriginInWindow.y
        return CGPoint(x: x, y: y)
    }

    private func handleHandoffDragMove(to localPoint: CGPoint) {
        // Reuse the exact same update logic as normal drag
        applyDragUpdate(
            at: localPoint,
            containerSize: currentContainerSize,
            columnWidth: currentColumnWidth,
            appHeight: currentAppHeight,
            iconSize: currentIconSize
        )
    }

    private func finalizeHandoffDrag() {
        guard draggingItem != nil else { return }
        defer {
            if let monitor = handoffEventMonitor {
                NSEvent.removeMonitor(monitor)
                handoffEventMonitor = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                draggingItem = nil
                pendingDropIndex = nil
                draggingOriginIndex = nil
                clampSelection()
                // Reset page-flip state
                pageFlipManager.isCooldown = false
                isHandoffDragging = false
                // Reset folder-creation drag state to ensure later drags work properly
                appStore.isDragCreatingFolder = false
                appStore.folderCreationTarget = nil
                // Perform the same cleanup as a normal drag ending
                appStore.cleanupUnusedNewPage()
                appStore.removeEmptyPages()
                appStore.saveAllOrder()
                // Trigger grid refresh to ensure drag gestures are reattached
                appStore.triggerGridRefresh()
            }
        }
        // In handoff-drag mode, compute the target index on drop; no snap preview during drag
        if isHandoffDragging && pendingDropIndex == nil {
            let pointerPoint = CGPoint(
                x: dragPreviewPosition.x + dragPointerOffset.x,
                y: dragPreviewPosition.y + dragPointerOffset.y
            )
            if let idx = indexAt(
                point: pointerPoint,
                in: currentContainerSize,
                pageIndex: appStore.currentPage,
                columnWidth: currentColumnWidth,
                appHeight: currentAppHeight
            ) {
                pendingDropIndex = idx
            } else {
                pendingDropIndex = predictedDropIndex(
                    for: pointerPoint,
                    in: currentContainerSize,
                    columnWidth: currentColumnWidth,
                    appHeight: currentAppHeight
                )
            }
        }

        // Use the unified drag-finish handling logic
        finalizeDragOperation(
            containerSize: currentContainerSize,
            columnWidth: currentColumnWidth,
            appHeight: currentAppHeight,
            iconSize: currentIconSize
        )

        // Immediately trigger grid refresh to ensure drag gestures are reattached
        appStore.triggerGridRefresh()
    }

    private func navigateToPage(_ targetPage: Int, animated: Bool = true) {
        guard targetPage >= 0 && targetPage < pages.count else { return }
        if animated {
            withAnimation(LNAnimations.springFast) {
                appStore.currentPage = targetPage
            }
        } else {
            appStore.currentPage = targetPage
        }

        if isKeyboardNavigationActive, selectedIndex != nil,
            let target = desiredIndexForPageKeepingPosition(
                targetPage: targetPage
            )
        {
            selectedIndex = target
        }
    }

    private func navigateToNextPage() {
        navigateToPage(appStore.currentPage + 1)
    }

    private func navigateToPreviousPage() {
        navigateToPage(appStore.currentPage - 1)
    }

}

// MARK: - FPS Monitoring
extension LaunchpadView {
    private func startFPSMonitoring() {
        stopFPSMonitoring()
        let monitor = FPSMonitor { fps, frameTime in
            let clamped = max(0, min(fps, 240))
            DispatchQueue.main.async {
                let smoothed = fpsValue * 0.7 + clamped * 0.3
                fpsValue = smoothed
                frameTimeMilliseconds = frameTime * 1000
            }
        }

        monitor.start()
        fpsMonitor = monitor
    }

    private func stopFPSMonitoring() {
        fpsMonitor?.stop()
        fpsMonitor = nil
        fpsValue = 0
        frameTimeMilliseconds = 0
    }
}

// MARK: - Blank area drag to flip pages
extension LaunchpadView {
    private func blankDragGesture(
        geoSize: CGSize,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("grid"))
            .onChanged { value in
                handleBlankAreaDragChange(
                    value,
                    geoSize: geoSize,
                    columnWidth: columnWidth,
                    appHeight: appHeight,
                    iconSize: iconSize
                )
            }
            .onEnded { value in
                handleBlankAreaDragEnd(
                    value,
                    geoSize: geoSize,
                    columnWidth: columnWidth,
                    appHeight: appHeight,
                    iconSize: iconSize
                )
            }
    }

    private func handleBlankAreaDragChange(
        _ value: DragGesture.Value,
        geoSize: CGSize,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) {
        guard draggingItem == nil, !isFolderOpen else { return }
        if blankDragConsumed { return }

        if blankDragStartPoint == nil {
            blankDragStartPoint = value.startLocation
            blankDragShouldIgnore = isPointOnInteractiveItem(
                value.startLocation,
                geoSize: geoSize,
                columnWidth: columnWidth,
                appHeight: appHeight,
                iconSize: iconSize
            )
            blankDragConsumed = false
            // let ignoreReason = blankDragShouldIgnore ? "hit item" : "blank"
            // print("[Launchpad] blank drag began at \(value.startLocation) -> \(ignoreReason)")
        }

        guard !blankDragShouldIgnore, let start = blankDragStartPoint else {
            return
        }

        let translationX = value.location.x - start.x
        let threshold = blankDragThreshold(for: geoSize.width)
        // print("[Launchpad] blank drag change translation=\(translationX), threshold=\(threshold)")

        if translationX <= -threshold {
            navigateToNextPage()
            blankDragStartPoint = value.location
            blankDragConsumed = true
            // print("[Launchpad] blank drag translation \(translationX) <= -\(threshold), flipped to next page")
        } else if translationX >= threshold {
            navigateToPreviousPage()
            blankDragStartPoint = value.location
            blankDragConsumed = true
            // print("[Launchpad] blank drag translation \(translationX) >= \(threshold), flipped to previous page")
        }
    }

    private func handleBlankAreaDragEnd(
        _ value: DragGesture.Value,
        geoSize: CGSize,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) {
        defer { resetBlankDragState() }

        guard draggingItem == nil, !isFolderOpen else { return }

        if blankDragShouldIgnore { return }

        guard blankDragStartPoint != nil else {
            closeIfTappedOnEmptyOrGap(
                at: value.location,
                geoSize: geoSize,
                columnWidth: columnWidth,
                appHeight: appHeight,
                iconSize: iconSize
            )
            return
        }

        if blankDragConsumed {
            // print("[Launchpad] blank drag already consumed")
            return
        }

        // Treat as tapping empty area if drag distance is too small
        let travel = hypot(value.translation.width, value.translation.height)
        if travel <= 12 {
            closeIfTappedOnEmptyOrGap(
                at: value.location,
                geoSize: geoSize,
                columnWidth: columnWidth,
                appHeight: appHeight,
                iconSize: iconSize
            )
            // print("[Launchpad] blank drag travel \(travel) treated as tap")
        } else {
            // print("[Launchpad] blank drag end travel=\(travel) no action")
        }
    }

    private func blankDragThreshold(for width: CGFloat) -> CGFloat {
        max(width * 0.08, 60)
    }

    private func resetBlankDragState() {
        blankDragStartPoint = nil
        blankDragShouldIgnore = false
        blankDragConsumed = false
    }

    private func isPointOnInteractiveItem(
        _ point: CGPoint,
        geoSize: CGSize,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) -> Bool {
        guard
            let index = indexAt(
                point: point,
                in: geoSize,
                pageIndex: appStore.currentPage,
                columnWidth: columnWidth,
                appHeight: appHeight
            )
        else { return false }

        guard currentItems.indices.contains(index) else { return false }
        if case .empty = currentItems[index] { return false }

        let rect = itemInteractiveRect(
            for: index,
            geoSize: geoSize,
            columnWidth: columnWidth,
            appHeight: appHeight,
            iconSize: iconSize
        )

        let horizontalPadding: CGFloat = 8
        let verticalPadding: CGFloat = 8
        let hasLabel = appStore.showLabels
        let iconLabelSpacing: CGFloat = hasLabel ? 8 : 0

        let iconRect = CGRect(
            x: rect.midX - iconSize / 2 + 16,
            y: rect.minY + verticalPadding + 16,
            width: iconSize - 32,
            height: iconSize - 32
        ).standardized

        var labelRect = CGRect.null
        if hasLabel {
            let labelTop = iconRect.maxY + iconLabelSpacing
            let labelBottom = rect.maxY - verticalPadding
            let labelHeight = max(0, labelBottom - labelTop)
            labelRect =
                CGRect(
                    x: rect.minX + horizontalPadding + 12,
                    y: labelTop,
                    width: rect.width - horizontalPadding * 2 - 24,
                    height: labelHeight
                ).standardized
        }

        let isIconHit = iconRect.contains(point)
        let isLabelHit = labelRect.contains(point)
        // print("[Launchpad] hit-test at \(point) -> iconRect=\(iconRect), labelRect=\(labelRect), iconHit=\(isIconHit), labelHit=\(isLabelHit)")
        return isIconHit || isLabelHit
    }
}

// MARK: - Tap close helper
extension LaunchpadView {
    fileprivate func closeIfTappedOnEmptyOrGap(
        at point: CGPoint,
        geoSize: CGSize,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) {
        // If a folder window is open, clicking the main area should close it
        if appStore.openFolder != nil {
            withAnimation(LNAnimations.springFast) {
                appStore.openFolder = nil
            }
            return
        }

        guard draggingItem == nil else { return }
        if let idx = indexAt(
            point: point,
            in: geoSize,
            pageIndex: appStore.currentPage,
            columnWidth: columnWidth,
            appHeight: appHeight
        ) {
            guard currentItems.indices.contains(idx) else {
                AppDelegate.shared?.hideWindow()
                return
            }

            if case .empty = currentItems[idx] {
                AppDelegate.shared?.hideWindow()
                return
            }

            let interactiveRect = itemInteractiveRect(
                for: idx,
                geoSize: geoSize,
                columnWidth: columnWidth,
                appHeight: appHeight,
                iconSize: iconSize
            )

            if !interactiveRect.contains(point) {
                AppDelegate.shared?.hideWindow()
            }
        } else {
            AppDelegate.shared?.hideWindow()
        }
    }
}

// MARK: - Keyboard Navigation
extension LaunchpadView {
    private func setupWindowShownObserver() {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
            windowObserver = nil
        }
        windowObserver = NotificationCenter.default.addObserver(
            forName: .launchpadWindowShown,
            object: nil,
            queue: .main
        ) { _ in
            isKeyboardNavigationActive = false
            selectedIndex = 0
            isSearchFieldFocused = true
            if !appStore.apps.isEmpty {
                appStore.applyOrderAndFolders()
            }
        }
    }

    private func setupWindowHiddenObserver() {
        if let observer = windowHiddenObserver {
            NotificationCenter.default.removeObserver(observer)
            windowHiddenObserver = nil
        }
        windowHiddenObserver = NotificationCenter.default.addObserver(
            forName: .launchpadWindowHidden,
            object: nil,
            queue: .main
        ) { _ in
            selectedIndex = 0
        }
    }

    private func setupInitialSelection() {
        if selectedIndex == nil, let firstIndex = filteredItems.indices.first {
            selectedIndex = firstIndex
        }
    }

    private func setupKeyHandlers() {
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
            event in
            handleKeyEvent(event)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        if isFolderOpen {
            if event.keyCode == 53 {  // esc
                let closingFolder = appStore.openFolder
                withAnimation(LNAnimations.springFast) {
                    appStore.openFolder = nil
                }
                if let folder = closingFolder,
                    let idx = filteredItems.firstIndex(of: .folder(folder))
                {
                    isKeyboardNavigationActive = true
                    selectedIndex = idx
                    let targetPage = idx / config.itemsPerPage
                    if targetPage != appStore.currentPage {
                        appStore.currentPage = targetPage
                    }
                }
                // Restore focus to the search field after closing a folder
                isSearchFieldFocused = true
                return nil
            }
            return event
        }

        guard !filteredItems.isEmpty else { return event }
        let code = event.keyCode

        if draggingItem != nil {
            switch code {
            case 123, 124, 125, 126, 48, 36: return nil
            default: return event
            }
        }

        if code == 53 {  // esc
            AppDelegate.shared?.hideWindow()
            return nil
        }

        if code == 36 {  // return
            if isSearchFieldFocused, isIMEComposing() { return event }
            if !isKeyboardNavigationActive {
                isKeyboardNavigationActive = true
                setSelectionToPageStart(appStore.currentPage)
                clampSelection()
                return nil
            }

            if let idx = selectedIndex, filteredItems.indices.contains(idx) {
                let sel = filteredItems[idx]
                if case .folder = sel {
                    appStore.openFolderActivatedByKeyboard = true
                }
                handleItemTap(sel)
                return nil
            }
            return event
        }

        if code == 48 {  // tab
            if !isKeyboardNavigationActive {
                isKeyboardNavigationActive = true
                setSelectionToPageStart(appStore.currentPage)
                clampSelection()
                return nil
            }
            // When active, keep original page navigation behavior (Shift reverses)
            let backward = event.modifierFlags.contains(.shift)
            if backward {
                navigateToPreviousPage()
            } else {
                navigateToNextPage()
            }
            setSelectionToPageStart(appStore.currentPage)
            return nil
        }

        // Use Shift + arrow keys to change pages
        if event.modifierFlags.contains(.shift) {
            switch code {
            case 123:  // left arrow - go to previous page
                guard isKeyboardNavigationActive else { return event }
                navigateToPreviousPage()
                setSelectionToPageStart(appStore.currentPage)
                return nil
            case 124:  // right arrow - go to next page
                guard isKeyboardNavigationActive else { return event }
                navigateToNextPage()
                setSelectionToPageStart(appStore.currentPage)
                return nil
            default:
                break
            }
        }

        if code == 125 {  // down arrow activates navigation first
            if isSearchFieldFocused, isIMEComposing() { return event }
            if !isKeyboardNavigationActive {
                isKeyboardNavigationActive = true
                setSelectionToPageStart(appStore.currentPage)
                clampSelection()
                return nil
            }
            moveSelection(dx: 0, dy: 1)
            return nil
        }

        if code == 126 {  // up arrow
            guard isKeyboardNavigationActive else { return event }
            if let idx = selectedIndex {
                let columns = config.columns
                let itemsPerPage = config.itemsPerPage
                let rowInPage = (idx % itemsPerPage) / columns
                if rowInPage == 0 {
                    isKeyboardNavigationActive = false
                    selectedIndex = nil
                    return nil
                }
            }
            moveSelection(dx: 0, dy: -1)
            return nil
        }

        // Regular arrow-key navigation (only when Shift is not held)
        if !event.modifierFlags.contains(.shift),
            let (dx, dy) = arrowDelta(for: code)
        {
            guard isKeyboardNavigationActive else { return event }
            moveSelection(dx: dx, dy: dy)
            return nil
        }

        return event
    }

    private func moveSelection(dx: Int, dy: Int) {
        guard let current = selectedIndex else { return }
        let columns = config.columns
        let newIndex: Int = dy == 0 ? current + dx : current + dy * columns
        guard filteredItems.indices.contains(newIndex) else { return }
        selectedIndex = newIndex

        let page = newIndex / config.itemsPerPage
        if page != appStore.currentPage {
            navigateToPage(page, animated: true)
        }
    }

    private func setSelectionToPageStart(_ page: Int) {
        let startIndex = page * config.itemsPerPage
        if filteredItems.indices.contains(startIndex) {
            selectedIndex = startIndex
        } else if let last = filteredItems.indices.last {
            selectedIndex = last
        } else {
            selectedIndex = nil
        }
    }

    private func desiredIndexForPageKeepingPosition(targetPage: Int) -> Int? {
        guard let current = selectedIndex else { return nil }
        let columns = config.columns
        let itemsPerPage = config.itemsPerPage
        let currentOffsetInPage = current % itemsPerPage
        let currentRow = currentOffsetInPage / columns
        let currentCol = currentOffsetInPage % columns
        let targetOffset = currentRow * columns + currentCol
        let candidate = targetPage * itemsPerPage + targetOffset

        if filteredItems.indices.contains(candidate) {
            return candidate
        }

        let startOfPage = targetPage * itemsPerPage
        let endExclusive = min(
            (targetPage + 1) * itemsPerPage,
            filteredItems.count
        )
        let lastIndexInPage = endExclusive - 1
        return lastIndexInPage >= startOfPage ? lastIndexInPage : nil
    }
}

// MARK: - Key mapping helpers
extension LaunchpadView {
    private func isIMEComposing() -> Bool {
        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else {
            return false
        }
        return editor.hasMarkedText()
    }
}

// MARK: - View builders
extension LaunchpadView {
    @ViewBuilder
    private func itemDraggable(
        item: LaunchpadItem,
        globalIndex: Int,
        pageIndex: Int,
        containerSize: CGSize,
        columnWidth: CGFloat,
        iconSize: CGFloat,
        appHeight: CGFloat,
        labelWidth: CGFloat,
        isSelected: Bool
    ) -> some View {
        if case .empty = item {
            Rectangle().fill(Color.clear)
                .frame(height: appHeight)
        } else {
            let shouldAllowHover = draggingItem == nil

            let isCenterCreatingTarget: Bool = {
                guard let draggingItem,
                    let idx = currentItems.firstIndex(of: item)
                else { return false }
                guard case .app = draggingItem else { return false }
                guard appStore.isDragCreatingFolder else { return false }
                switch item {
                case .app(let targetApp):
                    return appStore.folderCreationTarget?.id == targetApp.id
                case .folder:
                    return folderHoverCandidateIndex == idx
                case .empty:
                    return false
                }
            }()

            let base = LaunchpadItemButton(
                item: item,
                iconSize: iconSize,
                labelWidth: labelWidth,
                isSelected: isSelected,
                showLabel: appStore.showLabels,
                labelFontSize: CGFloat(appStore.iconLabelFontSize),
                labelFontWeight: appStore.iconLabelFontWeightValue,
                shouldAllowHover: shouldAllowHover,
                externalScale: isCenterCreatingTarget ? 1.2 : nil,
                hoverMagnificationEnabled: appStore.enableHoverMagnification,
                hoverMagnificationScale: CGFloat(
                    appStore.hoverMagnificationScale
                ),
                activePressEffectEnabled: appStore.enableActivePressEffect,
                activePressScale: CGFloat(appStore.activePressScale),
                onTap: { if draggingItem == nil { handleItemTap(item) } }
            )
            .frame(height: appHeight)
            // Keep stable view identity to avoid interrupting drag gesture after folder updates
            .id(item.id)

            if appStore.searchText.isEmpty && !isFolderOpen {
                let isDraggingOriginalTile = (draggingItem == item && draggingOriginIndex == globalIndex)

                base
                    .opacity(isDraggingOriginalTile ? 0 : 1)
                    .allowsHitTesting(!isDraggingOriginalTile)
                    .simultaneousGesture(
                        DragGesture(
                            minimumDistance: 2,
                            coordinateSpace: .named("grid")
                        )
                        .onChanged { value in
                            handleDragChange(
                                value,
                                item: item,
                                in: containerSize,
                                columnWidth: columnWidth,
                                appHeight: appHeight,
                                iconSize: iconSize
                            )
                        }
                        .onEnded { _ in
                            guard draggingItem != nil else { return }

                            // Use the unified drag-end handler
                            finalizeDragOperation(
                                containerSize: containerSize,
                                columnWidth: columnWidth,
                                appHeight: appHeight,
                                iconSize: iconSize
                            )

                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 0.22
                            ) {
                                draggingItem = nil
                                pendingDropIndex = nil
                                draggingOriginIndex = nil
                                clampSelection()
                                appStore.cleanupUnusedNewPage()
                                appStore.removeEmptyPages()

                                // Ensure saving immediately after drag completes
                                appStore.saveAllOrder()
                            }
                        }
                    )
            } else {
                base
            }
        }
    }
}

// MARK: - Drag math helpers
extension LaunchpadView {
    private func pageOf(index: Int) -> Int { index / config.itemsPerPage }

    private func cellOrigin(
        for globalIndex: Int,
        in containerSize: CGSize,
        pageIndex: Int,
        columnWidth: CGFloat,
        appHeight: CGFloat
    ) -> CGPoint {
        let columns = config.columns
        let displayedOffsetInPage: Int = {
            guard pages.indices.contains(pageIndex),
                currentItems.indices.contains(globalIndex)
            else {
                return globalIndex % config.itemsPerPage
            }
            let pageItems = pages[pageIndex]
            let item = currentItems[globalIndex]
            return pageItems.firstIndex(of: item)
                ?? (globalIndex % config.itemsPerPage)
        }()

        return GeometryUtils.cellOrigin(
            for: displayedOffsetInPage,
            containerSize: containerSize,
            pageIndex: pageIndex,
            columnWidth: columnWidth,
            appHeight: appHeight,
            columns: columns,
            columnSpacing: config.columnSpacing,
            rowSpacing: config.rowSpacing,
            pageSpacing: config.pageSpacing,
            currentPage: appStore.currentPage
        )
    }

    private func cellCenter(
        for globalIndex: Int,
        in containerSize: CGSize,
        pageIndex: Int,
        columnWidth: CGFloat,
        appHeight: CGFloat
    ) -> CGPoint {
        // Performance: cache to avoid recomputation
        let cacheKey =
            "center_\(globalIndex)_\(pageIndex)_\(containerSize.width)_\(containerSize.height)_\(columnWidth)_\(appHeight)"

        // Check whether the cache entry is valid
        let now = Date()
        if now.timeIntervalSince(Self.lastGeometryUpdate)
            < geometryCacheTimeout,
            let cached = Self.geometryCache[cacheKey]
        {
            return cached
        }

        let origin = cellOrigin(
            for: globalIndex,
            in: containerSize,
            pageIndex: pageIndex,
            columnWidth: columnWidth,
            appHeight: appHeight
        )
        let center = CGPoint(
            x: origin.x + columnWidth / 2,
            y: origin.y + appHeight / 2
        )

        // Update cache asynchronously to avoid mutating state during view updates
        DispatchQueue.main.async {
            Self.geometryCache[cacheKey] = center
            Self.lastGeometryUpdate = now
        }

        return center
    }

    private func indexAt(
        point: CGPoint,
        in containerSize: CGSize,
        pageIndex: Int,
        columnWidth: CGFloat,
        appHeight: CGFloat
    ) -> Int? {
        guard pages.indices.contains(pageIndex) else { return nil }
        let pageItems = pages[pageIndex]

        guard
            let offsetInPage = GeometryUtils.indexAt(
                point: point,
                containerSize: containerSize,
                pageIndex: pageIndex,
                columnWidth: columnWidth,
                appHeight: appHeight,
                columns: config.columns,
                columnSpacing: config.columnSpacing,
                rowSpacing: config.rowSpacing,
                pageSpacing: config.pageSpacing,
                currentPage: appStore.currentPage,
                itemsPerPage: config.itemsPerPage,
                pageItems: pageItems
            )
        else { return nil }

        let startIndexInCurrentItems = pages.prefix(pageIndex).reduce(0) {
            $0 + $1.count
        }
        let globalIndex = startIndexInCurrentItems + offsetInPage
        return currentItems.indices.contains(globalIndex) ? globalIndex : nil
    }

    private func itemInteractiveRect(
        for globalIndex: Int,
        geoSize: CGSize,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) -> CGRect {
        let pageIndex = max(0, globalIndex / config.itemsPerPage)
        let localIndex = globalIndex % config.itemsPerPage
        let cellOrigin = GeometryUtils.cellOrigin(
            for: localIndex,
            containerSize: geoSize,
            pageIndex: pageIndex,
            columnWidth: columnWidth,
            appHeight: appHeight,
            columns: config.columns,
            columnSpacing: config.columnSpacing,
            rowSpacing: config.rowSpacing,
            pageSpacing: config.pageSpacing,
            currentPage: appStore.currentPage
        )
        let cellRect = CGRect(
            x: cellOrigin.x,
            y: cellOrigin.y,
            width: columnWidth,
            height: appHeight
        )

        // Match LaunchpadItemButton layout: 8pt padding, 8pt icon-to-label spacing
        let horizontalPadding: CGFloat = 8
        let verticalPadding: CGFloat = 8
        let labelWidth = columnWidth * 0.9
        let hasLabel = appStore.showLabels
        let iconLabelSpacing: CGFloat = hasLabel ? 8 : 0
        let contentWidth = min(
            columnWidth,
            max(iconSize, labelWidth) + horizontalPadding * 2
        )
        let rawLabelHeight = max(
            0,
            appHeight - iconSize - verticalPadding * 2 - iconLabelSpacing
        )
        let labelHeight = hasLabel ? rawLabelHeight : 0
        let contentHeight = min(
            appHeight,
            iconSize + iconLabelSpacing + labelHeight + verticalPadding * 2
        )

        let insetX = max(0, (columnWidth - contentWidth) / 2)
        let insetY = max(0, (appHeight - contentHeight) / 2)

        return cellRect.insetBy(dx: insetX, dy: insetY)
    }

    private func clampPointWithinBounds(_ point: CGPoint, containerSize: CGSize)
        -> CGPoint
    {
        let maxX = max(containerSize.width - 0.1, 0)
        let maxY = max(containerSize.height - 0.1, 0)
        let clampedX = min(max(point.x, 0), maxX)
        let clampedY = min(max(point.y, 0), maxY)
        return CGPoint(x: clampedX, y: clampedY)
    }

    private func isPointInCenterArea(
        point: CGPoint,
        targetIndex: Int,
        containerSize: CGSize,
        pageIndex: Int,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) -> Bool {
        // Performance optimization: use cache to avoid repeated calculations
        let cacheKey =
            "centerArea_\(targetIndex)_\(pageIndex)_\(containerSize.width)_\(containerSize.height)_\(columnWidth)_\(appHeight)_\(iconSize)"

        let now = Date()
        if now.timeIntervalSince(Self.lastGeometryUpdate)
            < geometryCacheTimeout,
            let cached = Self.geometryCache[cacheKey]
        {
            let centerAreaSize = iconSize * 1.6
            let centerAreaRect = CGRect(
                x: cached.x - centerAreaSize / 2,
                y: cached.y - centerAreaSize / 2,
                width: centerAreaSize,
                height: centerAreaSize
            )
            return centerAreaRect.contains(point)
        }

        let targetCenter = cellCenter(
            for: targetIndex,
            in: containerSize,
            pageIndex: pageIndex,
            columnWidth: columnWidth,
            appHeight: appHeight
        )
        let scale: CGFloat = 1.6
        let centerAreaSize = iconSize * scale
        let centerAreaRect = CGRect(
            x: targetCenter.x - centerAreaSize / 2,
            y: targetCenter.y - centerAreaSize / 2,
            width: centerAreaSize,
            height: centerAreaSize
        )

        // Update cache asynchronously to avoid mutating state during view updates
        DispatchQueue.main.async {
            Self.geometryCache[cacheKey] = targetCenter
            Self.lastGeometryUpdate = now
        }

        return centerAreaRect.contains(point)
    }
}

// MARK: - Scroll handling (mouse wheel and trackpad)
extension LaunchpadView {
    private func handleScroll(
        deltaX: CGFloat,
        deltaY: CGFloat,
        phase: NSEvent.Phase,
        isMomentum: Bool,
        isPrecise: Bool,
        pageWidth: CGFloat
    ) {
        guard !isFolderOpen else { return }
        // Mouse wheel (non-precise): accumulate distance; apply small cooldown to avoid multi-page flips
        if !isPrecise {
            // Map vertical wheel to horizontal direction like precise scroll
            let primaryDelta = abs(deltaX) >= abs(deltaY) ? deltaX : -deltaY
            if primaryDelta == 0 { return }
            let direction = primaryDelta > 0 ? 1 : -1
            if wheelLastDirection != direction { wheelAccumulatedSinceFlip = 0 }
            wheelLastDirection = direction
            wheelAccumulatedSinceFlip += abs(primaryDelta)
            let baselineSensitivity = max(
                AppStore.defaultScrollSensitivity,
                0.0001
            )
            let relativeSensitivity =
                max(appStore.scrollSensitivity, 0.0001) / baselineSensitivity
            let threshold: CGFloat = 2.0 / CGFloat(relativeSensitivity)  // Adjust mouse wheel threshold based on sensitivity
            let now = Date()
            if wheelAccumulatedSinceFlip >= threshold {
                if let last = wheelLastFlipAt,
                    now.timeIntervalSince(last) < wheelFlipCooldown
                {
                    return
                }
                if direction > 0 {
                    navigateToNextPage()
                } else {
                    navigateToPreviousPage()
                }
                wheelLastFlipAt = now
                // reset accumulation so one wheel tick only flips once
                wheelAccumulatedSinceFlip = 0
            }
            return
        }

        // Trackpad precise scroll: accumulate and flip after threshold
        // Ignore momentum phase to ensure only one flip per gesture
        if isMomentum { return }
        let delta = abs(deltaX) >= abs(deltaY) ? deltaX : -deltaY  // vertical swipes map to horizontal
        switch phase {
        case .began:
            isUserSwiping = true
            accumulatedScrollX = 0
        case .changed:
            isUserSwiping = true
            accumulatedScrollX += delta
        case .ended, .cancelled:
            // Higher sensitivity reduces threshold for intuitive feel (like mouse wheel)
            // Normalize to default: threshold = pageWidth * (baseline^2 / sensitivity)
            // When sensitivity equals baseline, threshold is baseline*pageWidth; higher sensitivity lowers the threshold
            let baselineSensitivity = max(
                AppStore.defaultScrollSensitivity,
                0.001
            )
            let threshold =
                pageWidth
                * ((baselineSensitivity * baselineSensitivity)
                    / max(appStore.scrollSensitivity, 0.001))
            if accumulatedScrollX <= -threshold {
                navigateToNextPage()
            } else if accumulatedScrollX >= threshold {
                navigateToPreviousPage()
            }
            accumulatedScrollX = 0
            isUserSwiping = false
        default:
            break
        }
    }
}

// MARK: - AppKit Scroll catcher
struct ScrollEventCatcher: NSViewRepresentable {
    typealias NSViewType = ScrollEventCatcherView
    let onScroll: (CGFloat, CGFloat, NSEvent.Phase, Bool, Bool) -> Void

    func makeNSView(context: Context) -> ScrollEventCatcherView {
        let view = ScrollEventCatcherView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollEventCatcherView, context: Context) {
        nsView.onScroll = onScroll
    }

    final class ScrollEventCatcherView: NSView {
        var onScroll: ((CGFloat, CGFloat, NSEvent.Phase, Bool, Bool) -> Void)?
        private var eventMonitor: Any?

        override var acceptsFirstResponder: Bool { true }

        override func scrollWheel(with event: NSEvent) {
            // Prefer primary phase; fallback to momentum
            let phase = event.phase != [] ? event.phase : event.momentumPhase
            let isMomentum = event.momentumPhase != []
            let isPreciseOrTrackpad =
                event.hasPreciseScrollingDeltas || event.phase != []
                || event.momentumPhase != []
            onScroll?(
                event.scrollingDeltaX,
                event.scrollingDeltaY,
                phase,
                isMomentum,
                isPreciseOrTrackpad
            )
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
            // Globally listen to scroll events for the current window without consuming them
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
                .scrollWheel
            ]) { [weak self] event in
                let phase =
                    event.phase != [] ? event.phase : event.momentumPhase
                let isMomentum = event.momentumPhase != []
                let isPreciseOrTrackpad =
                    event.hasPreciseScrollingDeltas || event.phase != []
                    || event.momentumPhase != []
                self?.onScroll?(
                    event.scrollingDeltaX,
                    event.scrollingDeltaY,
                    phase,
                    isMomentum,
                    isPreciseOrTrackpad
                )
                return event
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            // Do not intercept hit-testing; let underlying views handle clicks/drags
            return nil
        }

        deinit {
            if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
        }
    }
}

// MARK: - Drag preview view

// MARK: - Selection Helpers
extension LaunchpadView {
    private func clampSelection() {
        guard isKeyboardNavigationActive else { return }
        let count = filteredItems.count
        if count == 0 {
            selectedIndex = nil
            return
        }
        if let idx = selectedIndex {
            if idx >= count { selectedIndex = count - 1 }
            if idx < 0 { selectedIndex = 0 }
        } else {
            selectedIndex = 0
        }

        if let idx = selectedIndex, filteredItems.indices.contains(idx) {
            let page = idx / config.itemsPerPage
            if page != appStore.currentPage {
                navigateToPage(page, animated: true)
            }
        } else {
            selectedIndex = filteredItems.isEmpty ? nil : 0
        }
    }
}

// MARK: - Geometry & Drag helpers
extension LaunchpadView {
    fileprivate func captureGridGeometry(
        _ geo: GeometryProxy,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) {
        gridOriginInWindow = geo.frame(in: .global).origin
        currentContainerSize = geo.size
        currentColumnWidth = columnWidth
        currentAppHeight = appHeight
        currentIconSize = iconSize

        // Performance: purge expired geometry cache
        let now = Date()
        if now.timeIntervalSince(Self.lastGeometryUpdate) > geometryCacheTimeout
            * 2
        {
            // Clear cache asynchronously to avoid mutating state during updates
            DispatchQueue.main.async {
                Self.geometryCache.removeAll()
                Self.lastGeometryUpdate = now
            }
        }
    }

    fileprivate func flipPageIfNeeded(
        iconCenter: CGPoint,
        pointer: CGPoint,
        iconSize: CGFloat,
        in containerSize: CGSize
    ) -> Bool {
        let edgeMargin: CGFloat = config.pageNavigation.edgeFlipMargin

        // Check page-flip cooldown
        pageFlipManager.autoFlipInterval =
            config.pageNavigation.autoFlipInterval
        guard pageFlipManager.canFlip() else { return false }

        let verticalTolerance = max(iconSize * 0.8, 60)
        if pointer.y < -verticalTolerance
            || pointer.y > containerSize.height + verticalTolerance
        {
            return false
        }

        if iconCenter.x <= edgeMargin && appStore.currentPage > 0 {
            navigateToPreviousPage()
            pageFlipManager.recordFlip()
            return true
        } else if iconCenter.x >= containerSize.width - edgeMargin {
            // Check whether a new page needs to be created
            let nextPage = appStore.currentPage + 1
            let itemsPerPage = config.itemsPerPage
            let nextPageStart = nextPage * itemsPerPage

            // When dragging to a new page, ensure enough space exists
            if nextPageStart >= currentItems.count {
                let neededItems =
                    nextPageStart + itemsPerPage - currentItems.count
                for _ in 0..<neededItems {
                    appStore.items.append(.empty(UUID().uuidString))
                }
            }

            navigateToNextPage()
            pageFlipManager.recordFlip()
            return true
        }

        return false
    }

    fileprivate func predictedDropIndex(
        for pointer: CGPoint,
        in containerSize: CGSize,
        columnWidth: CGFloat,
        appHeight: CGFloat
    ) -> Int? {
        let queryPoint =
            appStore.enableDropPrediction
            ? clampPointWithinBounds(pointer, containerSize: containerSize)
            : pointer

        if let predicted = indexAt(
            point: queryPoint,
            in: containerSize,
            pageIndex: appStore.currentPage,
            columnWidth: columnWidth,
            appHeight: appHeight
        ) {
            return predicted
        }

        let edgeMargin: CGFloat = config.pageNavigation.edgeFlipMargin
        let itemsPerPage = config.itemsPerPage

        if queryPoint.x <= edgeMargin && appStore.currentPage > 0 {
            let prevPage = appStore.currentPage - 1
            let prevPageStart = prevPage * itemsPerPage
            let prevPageEnd = min(
                prevPageStart + itemsPerPage,
                currentItems.count
            )
            return max(prevPageStart, prevPageEnd - 1)
        } else if queryPoint.x >= containerSize.width - edgeMargin {
            let nextPage = appStore.currentPage + 1
            let nextPageStart = nextPage * itemsPerPage

            // When dragging to a new page, ensure we can predict the first slot on the new page
            if nextPageStart >= currentItems.count {
                // Dragged to a brand-new page; return the first slot on that page
                return nextPageStart
            } else {
                return min(nextPageStart, currentItems.count - 1)
            }
        } else {
            if queryPoint.x <= edgeMargin {
                return appStore.currentPage * itemsPerPage
            } else {
                let currentPageEnd = min(
                    (appStore.currentPage + 1) * itemsPerPage,
                    currentItems.count
                )
                return max(
                    appStore.currentPage * itemsPerPage,
                    currentPageEnd - 1
                )
            }
        }
    }
}

struct GridConfig {
    let isFullscreen: Bool
    private let columnCount: Int
    private let rowCount: Int
    private let columnSpacingValue: CGFloat
    private let rowSpacingValue: CGFloat

    init(
        isFullscreen: Bool = false,
        columns: Int = 7,
        rows: Int = 5,
        columnSpacing: CGFloat = 20,
        rowSpacing: CGFloat = 14
    ) {
        self.isFullscreen = isFullscreen
        self.columnCount = max(1, columns)
        self.rowCount = max(1, rows)
        self.columnSpacingValue = max(0, columnSpacing)
        self.rowSpacingValue = max(0, rowSpacing)
    }

    var itemsPerPage: Int { columnCount * rowCount }
    var columns: Int { columnCount }
    var rows: Int { rowCount }
    var columnSpacing: CGFloat { columnSpacingValue }
    var rowSpacing: CGFloat { rowSpacingValue }

    let maxBounce: CGFloat = 80
    let pageSpacing: CGFloat = 80

    struct PageNavigation {
        let edgeFlipMargin: CGFloat = 15
        let autoFlipInterval: TimeInterval = 0.8  // Edge-drag page flip cooldown interval: 0.8s
        let scrollPageThreshold: CGFloat = 0.75
        let scrollFinishThreshold: CGFloat = 0.5
    }

    let pageNavigation = PageNavigation()
    let folderCreateDwell: TimeInterval = 0

    var horizontalPadding: CGFloat { isFullscreen ? 0.04 : 0 }
    var topPadding: CGFloat { isFullscreen ? 0.035 : 0 }
    var bottomPadding: CGFloat { isFullscreen ? 0.06 : 0 }

    var gridItems: [GridItem] {
        Array(
            repeating: GridItem(.flexible()),
            count: columns
        )
    }
}

//

struct DragPreviewItem: View {
    let item: LaunchpadItem
    let iconSize: CGFloat
    let labelWidth: CGFloat
    var scale: CGFloat = 1.2

    // Performance: use computed property to avoid state mutation
    private var displayIcon: NSImage {
        switch item {
        case .app(let app):
            return app.icon
        case .folder(let folder):
            return folder.icon(of: iconSize)
        case .empty:
            return item.icon
        }
    }

    var body: some View {
        switch item {
        case .app(let app):
            VStack(spacing: 6) {
                Image(nsImage: displayIcon)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: iconSize, height: iconSize)
                Text(app.name)
                    .font(.default)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: labelWidth)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .scaleEffect(scale)
            .animation(LNAnimations.springFast, value: scale)

        case .folder(let folder):
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: iconSize * 0.2)
                        .foregroundStyle(Color.clear)
                        .frame(width: iconSize * 0.8, height: iconSize * 0.8)
                        .liquidGlass(
                            in: RoundedRectangle(cornerRadius: iconSize * 0.2)
                        )
                        .shadow(radius: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: iconSize * 0.2)
                                .stroke(
                                    Color.launchpadBorder.opacity(0.5),
                                    lineWidth: 1
                                )
                        )
                    Image(nsImage: folder.icon(of: iconSize))
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .frame(width: iconSize, height: iconSize)
                }

                Text(folder.name)
                    .font(.default)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: labelWidth)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .scaleEffect(scale)
            .animation(LNAnimations.springFast, value: scale)

        case .empty:
            EmptyView()
        }
    }
}

func arrowDelta(for keyCode: UInt16) -> (dx: Int, dy: Int)? {
    switch keyCode {
    case 123: return (-1, 0)  // left
    case 124: return (1, 0)  // right
    case 126: return (0, -1)  // up
    case 125: return (0, 1)  // down
    default: return nil
    }
}

// MARK: - Cache management extension

extension LaunchpadView {
    /// Check cache status
    private func checkCacheStatus() {
        // Trigger a rescan if cache is invalid
        if !AppCacheManager.shared.isCacheValid {

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.appStore.performInitialScanIfNeeded()
            }
        }
    }

    // MARK: - Simplified drag handlers
    private func handleDragChange(
        _ value: DragGesture.Value,
        item: LaunchpadItem,
        in containerSize: CGSize,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) {
        // Initialize drag
        if draggingItem == nil {
            let originIndex = filteredItems.firstIndex(of: item)
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) { draggingItem = item }
            draggingOriginIndex = originIndex
            isKeyboardNavigationActive = false
            appStore.isDragCreatingFolder = false
            appStore.folderCreationTarget = nil
            if let idx = originIndex {
                _ = idx / config.itemsPerPage
                let interactiveRect = itemInteractiveRect(
                    for: idx,
                    geoSize: containerSize,
                    columnWidth: columnWidth,
                    appHeight: appHeight,
                    iconSize: iconSize
                )
                let center = CGPoint(
                    x: interactiveRect.midX,
                    y: interactiveRect.midY
                )
                dragPointerOffset = CGPoint(
                    x: value.location.x - center.x,
                    y: value.location.y - center.y
                )
            } else {
                dragPointerOffset = .zero
            }
            dragPreviewPosition = CGPoint(
                x: value.location.x - dragPointerOffset.x,
                y: value.location.y - dragPointerOffset.y
            )
        }
        applyDragUpdate(
            at: value.location,
            containerSize: containerSize,
            columnWidth: columnWidth,
            appHeight: appHeight,
            iconSize: iconSize
        )
    }

    // Unified drag-end logic (shared by normal and relay drag)
    private func finalizeDragOperation(
        containerSize: CGSize,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) {
        guard let dragging = draggingItem else { return }
        defer { dragPointerOffset = .zero }

        // Handle folder creation logic
        if appStore.isDragCreatingFolder, case .app(let app) = dragging {
            if let targetApp = appStore.folderCreationTarget {
                if let insertAt = filteredItems.firstIndex(of: .app(targetApp))
                {
                    let newFolder = appStore.createFolder(
                        with: [app, targetApp],
                        insertAt: insertAt
                    )
                    if let folderIndex = filteredItems.firstIndex(
                        of: .folder(newFolder)
                    ) {
                        let targetCenter = cellCenter(
                            for: folderIndex,
                            in: containerSize,
                            pageIndex: appStore.currentPage,
                            columnWidth: columnWidth,
                            appHeight: appHeight
                        )
                        withAnimation(LNAnimations.springFast) {
                            dragPreviewPosition = targetCenter
                            dragPreviewScale = 1.0
                        }
                    }
                } else {
                    let newFolder = appStore.createFolder(with: [
                        app, targetApp,
                    ])
                    if let folderIndex = filteredItems.firstIndex(
                        of: .folder(newFolder)
                    ) {
                        let targetCenter = cellCenter(
                            for: folderIndex,
                            in: containerSize,
                            pageIndex: appStore.currentPage,
                            columnWidth: columnWidth,
                            appHeight: appHeight
                        )
                        withAnimation(LNAnimations.springFast) {
                            dragPreviewPosition = targetCenter
                            dragPreviewScale = 1.0
                        }
                    }
                }
            } else {
                let pointerPoint = CGPoint(
                    x: dragPreviewPosition.x + dragPointerOffset.x,
                    y: dragPreviewPosition.y + dragPointerOffset.y
                )
                if let hoveringIndex = indexAt(
                    point: pointerPoint,
                    in: containerSize,
                    pageIndex: appStore.currentPage,
                    columnWidth: columnWidth,
                    appHeight: appHeight
                ),
                    filteredItems.indices.contains(hoveringIndex),
                    case .folder(let folder) = filteredItems[hoveringIndex]
                {
                    appStore.addAppToFolder(app, folder: folder)
                    let targetCenter = cellCenter(
                        for: hoveringIndex,
                        in: containerSize,
                        pageIndex: appStore.currentPage,
                        columnWidth: columnWidth,
                        appHeight: appHeight
                    )
                    withAnimation(LNAnimations.springFast) {
                        dragPreviewPosition = targetCenter
                        dragPreviewScale = 1.0
                    }
                }
            }
            appStore.isDragCreatingFolder = false
            appStore.folderCreationTarget = nil
            return
        }

        // Handle regular drag logic
        if let finalIndex = pendingDropIndex,
            filteredItems.firstIndex(of: dragging) != nil
        {
            // Check whether this is a cross-page drag
            let sourceIndexInItems =
                appStore.items.firstIndex(of: dragging) ?? 0
            let targetPage = finalIndex / config.itemsPerPage
            let sourcePage = sourceIndexInItems / config.itemsPerPage

            // Visually snap to the target cell center
            let dropDisplayIndex = finalIndex
            let finalPage = pageOf(index: dropDisplayIndex)
            let targetCenter = cellCenter(
                for: dropDisplayIndex,
                in: containerSize,
                pageIndex: finalPage,
                columnWidth: columnWidth,
                appHeight: appHeight
            )
            withAnimation(LNAnimations.springFast) {
                dragPreviewPosition = targetCenter
                dragPreviewScale = 1.0
            }

            if targetPage == sourcePage {
                // Within the same page: use intra-page reordering
                let pageStart =
                    (finalIndex / config.itemsPerPage) * config.itemsPerPage
                let pageEnd = min(
                    pageStart + config.itemsPerPage,
                    appStore.items.count
                )
                var newItems = appStore.items
                var pageSlice = Array(newItems[pageStart..<pageEnd])
                let localFrom = sourceIndexInItems - pageStart
                let moving = pageSlice.remove(at: localFrom)
                let desiredLocal = max(0, finalIndex - pageStart)
                let clampedLocal = min(desiredLocal, pageSlice.count)
                pageSlice.insert(moving, at: clampedLocal)
                newItems.replaceSubrange(pageStart..<pageEnd, with: pageSlice)
                withAnimation(LNAnimations.springFast) {
                    appStore.items = newItems
                }
                appStore.triggerGridRefresh()
                appStore.saveAllOrder()

                // After same-page drag, also compact to move empty items to page end
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    appStore.compactItemsWithinPages()
                }
            } else {
                // Cross-page drag: use cascade insertion
                appStore.moveItemAcrossPagesWithCascade(
                    item: dragging,
                    to: finalIndex
                )
            }
        } else {
            // Fallback: place the app at the end of the current page if no valid target index
            if filteredItems.firstIndex(of: dragging) != nil {
                let currentPageStart =
                    appStore.currentPage * config.itemsPerPage
                let currentPageEnd = min(
                    currentPageStart + config.itemsPerPage,
                    appStore.items.count
                )
                let targetIndex = currentPageEnd

                // Use cascade insert to ensure proper placement
                appStore.moveItemAcrossPagesWithCascade(
                    item: dragging,
                    to: targetIndex
                )
            }
        }
    }

    // Unified drag-update logic (shared by normal and relay drag)
    private func applyDragUpdate(
        at point: CGPoint,
        containerSize: CGSize,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) {
        let rawIconCenter = CGPoint(
            x: point.x - dragPointerOffset.x,
            y: point.y - dragPointerOffset.y
        )
        let iconCenter =
            appStore.enableDropPrediction
            ? clampPointWithinBounds(
                rawIconCenter,
                containerSize: containerSize
            )
            : rawIconCenter
        let hoverPoint = appStore.enableDropPrediction ? iconCenter : point
        // Performance: reduce frequent position updates
        let distance = sqrt(
            pow(dragPreviewPosition.x - iconCenter.x, 2)
                + pow(dragPreviewPosition.y - iconCenter.y, 2)
        )
        if distance < 2.0 { return }  // Skip update if movement is less than 2 pixels

        dragPreviewPosition = iconCenter

        // Performance: throttle to reduce computation frequency
        let now = Date()
        if now.timeIntervalSince(Self.lastGeometryUpdate) < 0.016 {  // approx 60fps
            return
        }

        // Update geometry cache timestamp asynchronously to avoid mutating state during updates
        DispatchQueue.main.async {
            Self.lastGeometryUpdate = now
        }

        if let hoveringIndex = indexAt(
            point: hoverPoint,
            in: containerSize,
            pageIndex: appStore.currentPage,
            columnWidth: columnWidth,
            appHeight: appHeight
        ),
            currentItems.indices.contains(hoveringIndex)
        {
            handleHoveringLogic(
                hoveringIndex: hoveringIndex,
                columnWidth: columnWidth,
                appHeight: appHeight,
                iconSize: iconSize
            )
        } else {
            clearHoveringState()
        }

        if flipPageIfNeeded(
            iconCenter: iconCenter,
            pointer: point,
            iconSize: iconSize,
            in: containerSize
        ) {
            let dropPoint = appStore.enableDropPrediction ? iconCenter : point
            pendingDropIndex = predictedDropIndex(
                for: dropPoint,
                in: containerSize,
                columnWidth: columnWidth,
                appHeight: appHeight
            )
        }
    }

    private func handleHoveringLogic(
        hoveringIndex: Int,
        columnWidth: CGFloat,
        appHeight: CGFloat,
        iconSize: CGFloat
    ) {
        let hoveringItem = currentItems[hoveringIndex]
        guard pageOf(index: hoveringIndex) == appStore.currentPage else {
            clearHoveringState()
            return
        }

        let pointerPoint = CGPoint(
            x: dragPreviewPosition.x + dragPointerOffset.x,
            y: dragPreviewPosition.y + dragPointerOffset.y
        )
        let isInCenterArea = isPointInCenterArea(
            point: pointerPoint,
            targetIndex: hoveringIndex,
            containerSize: currentContainerSize,
            pageIndex: appStore.currentPage,
            columnWidth: columnWidth,
            appHeight: appHeight,
            iconSize: iconSize
        )

        guard let dragging = draggingItem else { return }

        switch hoveringItem {
        case .app(let targetApp):
            handleAppHover(
                dragging: dragging,
                targetApp: targetApp,
                hoveringIndex: hoveringIndex,
                isInCenterArea: isInCenterArea
            )
        case .folder(_):
            handleFolderHover(
                dragging: dragging,
                hoveringIndex: hoveringIndex,
                isInCenterArea: isInCenterArea
            )
        case .empty:
            appStore.isDragCreatingFolder = false
            appStore.folderCreationTarget = nil
            pendingDropIndex = hoveringIndex
        }
    }

    private func handleAppHover(
        dragging: LaunchpadItem,
        targetApp: AppInfo,
        hoveringIndex: Int,
        isInCenterArea: Bool
    ) {
        if dragging == .app(targetApp) {
            clearHoveringState()
            pendingDropIndex = hoveringIndex
        } else if case .app = dragging {
            handleAppToAppHover(
                hoveringIndex: hoveringIndex,
                isInCenterArea: isInCenterArea,
                targetApp: targetApp
            )
        } else {
            clearHoveringState()
            pendingDropIndex = hoveringIndex
        }
    }

    private func handleAppToAppHover(
        hoveringIndex: Int,
        isInCenterArea: Bool,
        targetApp: AppInfo
    ) {
        let now = Date()
        let candidateChanged =
            folderHoverCandidateIndex != hoveringIndex || !isInCenterArea

        if candidateChanged {
            folderHoverCandidateIndex = isInCenterArea ? hoveringIndex : nil
            folderHoverBeganAt = isInCenterArea ? now : nil
            appStore.isDragCreatingFolder = false
            appStore.folderCreationTarget = nil
        }

        if isInCenterArea {
            appStore.isDragCreatingFolder = true
            appStore.folderCreationTarget = targetApp
            pendingDropIndex = nil
        } else {
            if !isInCenterArea || folderHoverCandidateIndex == nil {
                appStore.isDragCreatingFolder = false
                appStore.folderCreationTarget = nil
                pendingDropIndex = hoveringIndex
            } else {
                pendingDropIndex = nil
            }
        }
    }

    private func handleFolderHover(
        dragging: LaunchpadItem,
        hoveringIndex: Int,
        isInCenterArea: Bool
    ) {
        if case .app = dragging {
            let now = Date()
            let candidateChanged =
                folderHoverCandidateIndex != hoveringIndex || !isInCenterArea

            if candidateChanged {
                folderHoverCandidateIndex = isInCenterArea ? hoveringIndex : nil
                folderHoverBeganAt = isInCenterArea ? now : nil
                appStore.isDragCreatingFolder = false
                appStore.folderCreationTarget = nil
            }

            if isInCenterArea {
                appStore.isDragCreatingFolder = true
                appStore.folderCreationTarget = nil
                pendingDropIndex = nil
            } else {
                if !isInCenterArea || folderHoverCandidateIndex == nil {
                    appStore.isDragCreatingFolder = false
                    appStore.folderCreationTarget = nil
                    pendingDropIndex = hoveringIndex
                } else {
                    pendingDropIndex = nil
                }
            }
        } else {
            clearHoveringState()
            pendingDropIndex = hoveringIndex
        }
    }

    private func clearHoveringState() {
        appStore.isDragCreatingFolder = false
        appStore.folderCreationTarget = nil
        pendingDropIndex = nil
        folderHoverCandidateIndex = nil
        folderHoverBeganAt = nil
    }

}
