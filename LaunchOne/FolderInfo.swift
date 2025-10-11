import AppKit
import Foundation
import SwiftData

struct FolderInfo: Identifiable, Equatable {
    let id: String
    var name: String
    var apps: [AppInfo]
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String = "Untitled",
        apps: [AppInfo] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.apps = apps
        self.createdAt = createdAt
    }

    var folderIcon: NSImage {
        // Regenerate the icon on each access to reflect the latest app state
        let icon = icon(of: 72)
        return icon
    }

    func icon(of side: CGFloat) -> NSImage {
        let normalizedSide = max(16, side)
        let icon = renderFolderIcon(side: normalizedSide)
        return icon
    }

    private func renderFolderIcon(side: CGFloat) -> NSImage {
        let size = NSSize(width: side, height: side)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        if let ctx = NSGraphicsContext.current {
            ctx.imageInterpolation = .high
            ctx.shouldAntialias = true
        }

        let rect = NSRect(origin: .zero, size: size)

        let outerInset = round(side * 0.12)
        let contentRect = rect.insetBy(dx: outerInset, dy: outerInset)
        let innerInset = round(contentRect.width * 0.08)
        let innerRect = contentRect.insetBy(dx: innerInset, dy: innerInset)

        // Outer thumbnail: 3x3 mosaic
        let cols = 3
        let rows = 3
        let spacing = max(1, round(innerRect.width * 0.02))
        let tileW = floor(
            (innerRect.width - CGFloat(cols - 1) * spacing) / CGFloat(cols)
        )
        let tileH = floor(
            (innerRect.height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
        )
        let tile = min(tileW, tileH)
        let totalW = CGFloat(cols) * tile + CGFloat(cols - 1) * spacing
        let totalH = CGFloat(rows) * tile + CGFloat(rows - 1) * spacing
        let startX = innerRect.minX + (innerRect.width - totalW) / 2
        let startYTop = innerRect.maxY - (innerRect.height - totalH) / 2

        for (index, app) in apps.prefix(cols * rows).enumerated() {
            let row = index / cols
            let col = index % cols
            let x = startX + CGFloat(col) * (tile + spacing)
            let y = startYTop - CGFloat(row + 1) * tile - CGFloat(row) * spacing
            let iconRect = NSRect(x: x, y: y, width: tile, height: tile)

            // Icon fallback: if app icon size is 0, fall back to system file icon
            let iconToDraw: NSImage = {
                if app.icon.size.width > 0 && app.icon.size.height > 0 {
                    return app.icon
                } else {
                    return NSWorkspace.shared.icon(forFile: app.url.path)
                }
            }()
            iconToDraw.draw(in: iconRect)
        }

        return image
    }

    static func == (lhs: FolderInfo, rhs: FolderInfo) -> Bool {
        lhs.id == rhs.id
    }
}

enum LaunchpadItem: Identifiable, Equatable {
    case app(AppInfo)
    case folder(FolderInfo)
    case empty(String)

    var id: String {
        switch self {
        case .app(let app):
            return "app_\(app.id)"
        case .folder(let folder):
            return "folder_\(folder.id)"
        case .empty(let token):
            return "empty_\(token)"
        }
    }

    var name: String {
        switch self {
        case .app(let app):
            return app.name
        case .folder(let folder):
            return folder.name
        case .empty:
            return ""
        }
    }

    var icon: NSImage {
        switch self {
        case .app(let app):
            return app.icon
        case .folder(let folder):
            let icon = folder.folderIcon
            return icon
        case .empty:
            // Transparent placeholder
            return NSImage(size: .zero)
        }
    }

    // Convenience: return AppInfo if .app, otherwise nil
    var appInfoIfApp: AppInfo? {
        if case .app(let app) = self { return app }
        return nil
    }

    static func == (lhs: LaunchpadItem, rhs: LaunchpadItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Unified persistence model (top-level items: app or folder)
@Model
final class TopItemData {
    // Unified primary key: appPath for apps, folderId for folders
    @Attribute(.unique) var id: String
    var kind: String  // "app" or "folder"
    var orderIndex: Int  // Mixed order index at top level
    // App fields
    var appPath: String?
    // Folder fields
    var folderName: String?
    var appPaths: [String]  // App order inside the folder
    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // Folder initializer
    init(
        folderId: String,
        folderName: String,
        appPaths: [String],
        orderIndex: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = folderId
        self.kind = "folder"
        self.orderIndex = orderIndex
        self.appPath = nil
        self.folderName = folderName
        self.appPaths = appPaths
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // App initializer
    init(
        appPath: String,
        orderIndex: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = appPath
        self.kind = "app"
        self.orderIndex = orderIndex
        self.appPath = appPath
        self.folderName = nil
        self.appPaths = []
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Empty slot initializer
    init(
        emptyId: String,
        orderIndex: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = emptyId
        self.kind = "empty"
        self.orderIndex = orderIndex
        self.appPath = nil
        self.folderName = nil
        self.appPaths = []
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Per-page ordering persistence model (stored by "page-slot")
@Model
final class PageEntryData {
    // Unique slot key, e.g. "page-0-pos-3"
    @Attribute(.unique) var slotId: String
    var pageIndex: Int
    var position: Int
    var kind: String  // "app" | "folder" | "empty"
    // App entry
    var appPath: String?
    // Folder entry
    var folderId: String?
    var folderName: String?
    var appPaths: [String]
    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    init(
        slotId: String,
        pageIndex: Int,
        position: Int,
        kind: String,
        appPath: String? = nil,
        folderId: String? = nil,
        folderName: String? = nil,
        appPaths: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.slotId = slotId
        self.pageIndex = pageIndex
        self.position = position
        self.kind = kind
        self.appPath = appPath
        self.folderId = folderId
        self.folderName = folderName
        self.appPaths = appPaths
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
