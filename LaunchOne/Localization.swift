import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case spanish = "es"
    case german = "de"
    case russian = "ru"
    case hindi = "hi"
    case vietnamese = "vi"

    var id: String { rawValue }

    static func resolveSystemDefault() -> AppLanguage {
        guard let preferred = Locale.preferredLanguages.first else {
            return .english
        }
        let lower = preferred.lowercased()
        if lower.hasPrefix("zh") { return .simplifiedChinese }
        if lower.hasPrefix("ja") { return .japanese }
        if lower.hasPrefix("ko") { return .korean }
        if lower.hasPrefix("fr") { return .french }
        if lower.hasPrefix("es") { return .spanish }
        if lower.hasPrefix("de") { return .german }
        if lower.hasPrefix("ru") { return .russian }
        if lower.hasPrefix("hi") { return .hindi }
        if lower.hasPrefix("vi") { return .vietnamese }
        return .english
    }
}

enum LocalizationKey: String {
    case noAppsFound
    case searchPlaceholder
    case appTitle
    case modifiedFrom
    case backgroundHint
    case classicMode
    case iconSize
    case iconsPerRow
    case rowsPerPage
    case iconHorizontalSpacing
    case iconVerticalSpacing
    case labelFontSize
    case iconLabelFontWeight
    case pageIndicatorHint
    case rememberPageTitle
    case globalShortcutTitle
    case shortcutSetButton
    case shortcutSaveButton
    case shortcutClearButton
    case shortcutNotSet
    case shortcutListening
    case shortcutCapturePrompt
    case shortcutNoModifierWarning
    case smaller
    case larger
    case predictDrop
    case showLabels
    case useLocalizedThirdPartyTitles
    case enableAnimations
    case hoverMagnification
    case hoverMagnificationScale
    case activePressEffect
    case activePressScale
    case animationDurationLabel
    case gridSizeChangeWarning
    case viewOnGitHub
    case scrollSensitivity
    case low
    case high
    case importSystem
    case importLegacy
    case importTip
    case exportData
    case importData
    case refresh
    case showQuickRefreshButton
    case resetLayout
    case resetAlertTitle
    case resetAlertMessage
    case resetConfirm
    case cancel
    case quit
    case menuAbout
    case menuSettings
    case menuQuit
    case languagePickerTitle
    case appearanceModeTitle
    case appearanceModeFollowSystem
    case appearanceModeLight
    case appearanceModeDark
    case versionPrefix
    case settingsSectionPerformance
    case settingsSectionTitles
    case settingsSectionDevelopment
    case settingsSectionAbout
    case settingsSectionGeneral
    case settingsSectionAppearance
    case settingsSectionHiddenApps
    case backgroundStyleTitle
    case backgroundStyleOptionBlur
    case backgroundStyleOptionGlass
    case developmentPlaceholderTitle
    case developmentPlaceholderSubtitle
    case hiddenAppsAddButton
    case hiddenAppsEmptyTitle
    case hiddenAppsEmptySubtitle
    case hiddenAppsHint
    case hiddenAppsRemoveButton
    case hiddenAppsSearchPlaceholder
    case performancePlaceholderTitle
    case performancePlaceholderSubtitle
    case renameSearchPlaceholder
    case customTitlePlaceholder
    case customTitleHint
    case customTitleDefaultFormat
    case customTitleReset
    case customTitleAddButton
    case customTitleEmptyTitle
    case customTitleEmptySubtitle
    case customTitleNoResults
    case customTitlePickerMessage
    case customTitleEdit
    case customTitleSave
    case customTitleCancel
    case customTitleDelete
    case loadingApplications
    case showFPSOverlay
    case showFPSOverlayDisclaimer
    case dockDisplayTitle
    case dockDisplayToggle
    case dockDisplayDescription
    case customIconTitle
    case customIconChoose
    case customIconReset
    case customIconHint
    case customIconError
    case pageIndicatorOffsetLabel
    case folderWindowWidth
    case folderWindowHeight
    case folderWindowSizeHint
    case languageNameSystem
    case languageNameEnglish
    case languageNameChinese
    case languageNameJapanese
    case languageNameKorean
    case languageNameFrench
    case languageNameSpanish
    case languageNameGerman
    case languageNameRussian
    case languageNameHindi
    case languageNameVietnamese
    case folderNamePlaceholder
    case chooseButton
    case exportPanelMessage
    case importPrompt
    case importPanelMessage
    case legacyArchivePanelMessage
    case importSuccessfulTitle
    case importFailedTitle
    case okButton

    // Update check related
    case checkForUpdates
    case checkForUpdatesButton
    case checkingForUpdates
    case upToDate
    case updateAvailable
    case newVersion
    case downloadUpdate
    case updateCheckFailed
    case tryAgain
    case autoCheckForUpdates
    case versionParseError

    // Login item (silent) related
    case startAtLoginTitle
    case startAtLoginToggle
    case startAtLoginDescription
    case loginItemPermissionHint
}

final class LocalizationManager {
    static let shared = LocalizationManager()

    private let translations: [AppLanguage: [LocalizationKey: String]]

    private init() {
        var builder: [AppLanguage: [LocalizationKey: String]] = [
            .english: [
                .noAppsFound: "No apps found",
                .searchPlaceholder: "Search",
                .renameSearchPlaceholder: "Search apps",
                .customTitlePlaceholder: "Enter a custom name",
                .customTitleHint:
                    "Rename apps here. Custom titles persist across imports and localization changes.",
                .customTitleDefaultFormat: "Default: %@",
                .customTitleReset: "Restore default",
                .customTitleAddButton: "Add application",
                .customTitleEmptyTitle: "No custom titles yet",
                .customTitleEmptySubtitle:
                    "Choose an app to start renaming. Custom titles stay even after imports or localization changes.",
                .customTitleNoResults: "No matches",
                .customTitlePickerMessage:
                    "Select an application to manage its title.",
                .customTitleEdit: "Edit",
                .customTitleSave: "Save",
                .customTitleCancel: "Cancel",
                .customTitleDelete: "Remove",
                .loadingApplications: "Loading applications…",
                .showFPSOverlay: "Show FPS overlay",
                .showFPSOverlayDisclaimer:
                    "Approximate measurement; may not reflect actual frame pacing.",
                .dockDisplayTitle: "Dock Display",
                .dockDisplayToggle: "Show icon in Dock",
                .dockDisplayDescription:
                    "When enabled, the app icon will appear in the Dock. When disabled, the app will run completely in the background. Changes take effect immediately.",
                .customIconTitle: "Application icon",
                .customIconChoose: "Choose…",
                .customIconReset: "Restore default",
                .customIconHint:
                    "PNG/ICNS files at 512×512 work best. Changes apply instantly.",
                .customIconError: "Could not load the selected image.",
                .pageIndicatorOffsetLabel: "Page indicator spacing",
                .folderWindowWidth: "Folder window width",
                .folderWindowHeight: "Folder window height",
                .folderWindowSizeHint:
                    "Applies to windowed mode only; classic fullscreen uses a fixed layout.",
                .appTitle: "LaunchOne",
                .modifiedFrom: "Modified from LaunchNext version 1.0.6",
                .backgroundHint:
                    "Automatically run on background: add LaunchOne to dock or use keyboard shortcuts to open the application window",
                .classicMode: "Classic Launchpad (Fullscreen)",
                .iconSize: "Icon size",
                .iconsPerRow: "Icons per row",
                .rowsPerPage: "Rows per page",
                .iconHorizontalSpacing: "Horizontal spacing",
                .iconVerticalSpacing: "Vertical spacing",
                .labelFontSize: "Label font size",
                .iconLabelFontWeight: "Icon label weight",
                .smaller: "Smaller",
                .larger: "Larger",
                .predictDrop: "Predict drop position",
                .showLabels: "Show labels under icons",
                .useLocalizedThirdPartyTitles: "Use localized app names",
                .enableAnimations: "Enable slide animation",
                .hoverMagnification: "Hover magnification",
                .hoverMagnificationScale: "Hover scale",
                .activePressEffect: "Press feedback",
                .activePressScale: "Press scale",
                .animationDurationLabel: "Slide animation duration",
                .gridSizeChangeWarning:
                    "Changing the grid size may reposition some icons.",
                .pageIndicatorHint:
                    "If vertical spacing feels subtle, adjust the page indicator offset below.",
                .rememberPageTitle: "Remember last opened page",
                .globalShortcutTitle: "Global shortcut",
                .shortcutSetButton: "Set shortcut",
                .shortcutSaveButton: "Save",
                .shortcutClearButton: "Clear",
                .shortcutNotSet: "Not set",
                .shortcutListening: "Listening…",
                .shortcutCapturePrompt:
                    "Press the desired key combination. Press Esc to cancel.",
                .shortcutNoModifierWarning:
                    "Using no modifier may clash with other apps.",
                .scrollSensitivity: "Scrolling sensitivity",
                .low: "Low",
                .high: "High",
                .importSystem: "Import System Launchpad",
                .importLegacy: "Import Legacy (.lmy)",
                .importTip:
                    "Tip: Click ‘Import System Launchpad’ to import directly from the system Launchpad.",
                .exportData: "Export Data",
                .importData: "Import Data",
                .refresh: "Refresh",
                .showQuickRefreshButton: "Show quick refresh button",
                .resetLayout: "Reset Layout",
                .resetAlertTitle: "Confirm to reset layout?",
                .resetAlertMessage:
                    "This will completely reset the layout: remove all folders, clear saved order, and rescan all applications. All customizations will be lost.",
                .resetConfirm: "Reset",
                .cancel: "Cancel",
                .quit: "Quit",
                .menuAbout: "About LaunchOne",
                .menuSettings: "Settings…",
                .menuQuit: "Quit",
                .languagePickerTitle: "Language",
                .appearanceModeTitle: "Appearance",
                .appearanceModeFollowSystem: "Follow system",
                .appearanceModeLight: "Light",
                .appearanceModeDark: "Dark",
                .versionPrefix: "v",
                .languageNameSystem: "Follow System",
                .languageNameEnglish: "英语",
                .languageNameChinese: "中文",
                .languageNameJapanese: "日语",
                .languageNameKorean: "韩语",
                .languageNameFrench: "法语",
                .languageNameSpanish: "西班牙语",
                .languageNameGerman: "德语",
                .languageNameRussian: "俄语",
                .languageNameHindi: "Hindi",
                .languageNameVietnamese: "Vietnamese",
                .folderNamePlaceholder: "Folder Name",
                .viewOnGitHub: "Open project link",
                .chooseButton: "Choose",
                .exportPanelMessage:
                    "Choose a destination folder to export LaunchOne data",
                .importPrompt: "Import",
                .importPanelMessage:
                    "Choose a folder previously exported from LaunchOne",
                .legacyArchivePanelMessage:
                    "Choose a legacy Launchpad archive (.lmy/.zip) or a db file",
                .importSuccessfulTitle: "Import Successful",
                .importFailedTitle: "Import Failed",
                .okButton: "OK",

                // Update check related
                .checkForUpdates: "Check for Updates",
                .checkForUpdatesButton: "Check for Updates",
                .checkingForUpdates: "Checking for updates...",
                .upToDate: "You're up to date",
                .updateAvailable: "Update Available",
                .newVersion: "New version:",
                .downloadUpdate: "Download Update",
                .updateCheckFailed: "Update check failed",
                .tryAgain: "Try Again",
                .autoCheckForUpdates: "Check for updates automatically",
                .versionParseError: "Version parsing error",

                // Login item (silent)
                .startAtLoginTitle: "Start at login (silent)",
                .startAtLoginToggle: "Enable",
                .startAtLoginDescription: "Launch on login without showing any UI. You can bring up the window later via the global shortcut.",
                .loginItemPermissionHint: "Please allow ‘LaunchOne’ to run in the background in System Settings → Login Items.",
            ],
            .vietnamese: [
                .noAppsFound: "Không tìm thấy ứng dụng nào",
                .searchPlaceholder: "Tìm kiếm",
                .renameSearchPlaceholder: "Tìm ứng dụng",
                .customTitlePlaceholder: "Nhập tên tuỳ chỉnh",
                .customTitleHint:
                    "Đổi tên ứng dụng tại đây. Tên tuỳ chỉnh vẫn được giữ khi nhập dữ liệu hoặc đổi ngôn ngữ.",
                .customTitleDefaultFormat: "Mặc định: %@",
                .customTitleReset: "Khôi phục mặc định",
                .customTitleAddButton: "Thêm ứng dụng",
                .customTitleEmptyTitle: "Chưa có tên tuỳ chỉnh",
                .customTitleEmptySubtitle:
                    "Chọn một ứng dụng để bắt đầu đổi tên. Các tên tuỳ chỉnh sẽ được giữ lại kể cả khi nhập khẩu hoặc thay đổi ngôn ngữ.",
                .customTitleNoResults: "Không có kết quả",
                .customTitlePickerMessage:
                    "Chọn ứng dụng cần quản lý tên hiển thị.",
                .customTitleEdit: "Sửa",
                .customTitleSave: "Lưu",
                .customTitleCancel: "Huỷ",
                .customTitleDelete: "Xoá",
                .loadingApplications: "Đang tải ứng dụng…",
                .showFPSOverlay: "Hiển thị lớp phủ FPS",
                .showFPSOverlayDisclaimer:
                    "Chỉ là số đo xấp xỉ; có thể không khớp với nhịp khung hình thực tế.",
                .dockDisplayTitle: "Hiển thị Dock",
                .dockDisplayToggle: "Hiển thị biểu tượng trong Dock",
                .dockDisplayDescription:
                    "Khi bật, biểu tượng ứng dụng sẽ xuất hiện trong Dock. Khi tắt, ứng dụng sẽ chạy hoàn toàn trong nền. Thay đổi có hiệu lực ngay lập tức.",
                .customIconTitle: "Biểu tượng ứng dụng",
                .customIconChoose: "Chọn…",
                .customIconReset: "Khôi phục mặc định",
                .customIconHint:
                    "Nên dùng tệp PNG/ICNS 512×512. Thay đổi được áp dụng ngay.",
                .customIconError: "Không thể tải hình ảnh đã chọn.",
                .pageIndicatorOffsetLabel: "Khoảng cách chỉ báo trang",
                .folderWindowWidth: "Chiều rộng cửa sổ thư mục",
                .folderWindowHeight: "Chiều cao cửa sổ thư mục",
                .folderWindowSizeHint:
                    "Chỉ áp dụng cho chế độ cửa sổ; toàn màn hình cổ điển dùng bố cục cố định.",
                .appTitle: "LaunchOne",
                .modifiedFrom: "Điều chỉnh từ LaunchNext phiên bản 1.0.6",
                .backgroundHint:
                    "Để chạy nền: ghim LaunchOne vào Dock hoặc dùng phím tắt để mở cửa sổ ứng dụng",
                .classicMode: "Launchpad cổ điển (toàn màn hình)",
                .iconSize: "Kích thước biểu tượng",
                .iconsPerRow: "Số biểu tượng mỗi hàng",
                .rowsPerPage: "Số hàng mỗi trang",
                .iconHorizontalSpacing: "Khoảng cách ngang",
                .iconVerticalSpacing: "Khoảng cách dọc",
                .labelFontSize: "Cỡ chữ nhãn",
                .iconLabelFontWeight: "Độ đậm nhãn biểu tượng",
                .smaller: "Nhỏ hơn",
                .larger: "Lớn hơn",
                .predictDrop: "Dự đoán vị trí thả",
                .showLabels: "Hiển thị nhãn dưới biểu tượng",
                .useLocalizedThirdPartyTitles:
                    "Dùng tên ứng dụng đã bản địa hoá",
                .enableAnimations: "Bật hoạt ảnh trượt",
                .hoverMagnification: "Phóng to khi trỏ",
                .hoverMagnificationScale: "Tỷ lệ phóng to khi trỏ",
                .activePressEffect: "Phản hồi khi nhấn",
                .activePressScale: "Tỷ lệ khi nhấn",
                .animationDurationLabel: "Thời lượng hoạt ảnh trượt",
                .gridSizeChangeWarning:
                    "Thay đổi kích thước lưới có thể làm đổi vị trí một số biểu tượng.",
                .pageIndicatorHint:
                    "Nếu khoảng cách dọc khó nhận ra, hãy điều chỉnh vị trí chỉ báo trang bên dưới.",
                .rememberPageTitle: "Ghi nhớ trang mở gần nhất",
                .globalShortcutTitle: "Phím tắt toàn cục",
                .shortcutSetButton: "Đặt phím tắt",
                .shortcutSaveButton: "Lưu",
                .shortcutClearButton: "Xoá",
                .shortcutNotSet: "Chưa đặt",
                .shortcutListening: "Đang chờ…",
                .shortcutCapturePrompt:
                    "Nhấn tổ hợp phím mong muốn. Bấm Esc để huỷ.",
                .shortcutNoModifierWarning:
                    "Không dùng phím bổ trợ có thể gây xung đột với ứng dụng khác.",
                .scrollSensitivity: "Độ nhạy cuộn",
                .low: "Thấp",
                .high: "Cao",
                .importSystem: "Nhập Launchpad hệ thống",
                .importLegacy: "Nhập Legacy (.lmy)",
                .importTip:
                    "Mẹo: nhấn ‘Nhập Launchpad hệ thống’ để lấy trực tiếp bố cục hiện tại.",
                .exportData: "Xuất dữ liệu",
                .importData: "Nhập dữ liệu",
                .refresh: "Làm mới",
                .showQuickRefreshButton: "Hiển thị nút làm mới nhanh",
                .resetLayout: "Đặt lại bố cục",
                .resetAlertTitle: "Đặt lại bố cục?",
                .resetAlertMessage:
                    "Thao tác này sẽ xoá mọi thư mục, làm trống thứ tự đã lưu và quét lại toàn bộ ứng dụng. Mọi tuỳ chỉnh sẽ bị mất.",
                .resetConfirm: "Đặt lại",
                .cancel: "Huỷ",
                .quit: "Thoát",
                .menuAbout: "Giới thiệu LaunchOne",
                .menuSettings: "Cài đặt…",
                .menuQuit: "Thoát",
                .languagePickerTitle: "Ngôn ngữ",
                .appearanceModeTitle: "Giao diện",
                .appearanceModeFollowSystem: "Theo hệ thống",
                .appearanceModeLight: "Sáng",
                .appearanceModeDark: "Tối",
                .versionPrefix: "v",
                .languageNameSystem: "Theo hệ thống",
                .languageNameEnglish: "Tiếng Anh",
                .languageNameChinese: "Tiếng Trung",
                .languageNameJapanese: "Tiếng Nhật",
                .languageNameKorean: "Tiếng Hàn",
                .languageNameFrench: "Tiếng Pháp",
                .languageNameSpanish: "Tiếng Tây Ban Nha",
                .languageNameGerman: "Tiếng Đức",
                .languageNameRussian: "Tiếng Nga",
                .languageNameHindi: "Tiếng Hindi",
                .languageNameVietnamese: "Tiếng Việt",
                .folderNamePlaceholder: "Tên thư mục",
                .viewOnGitHub: "Mở liên kết dự án",
                .chooseButton: "Chọn",
                .exportPanelMessage:
                    "Chọn thư mục đích để xuất dữ liệu LaunchOne",
                .importPrompt: "Nhập",
                .importPanelMessage:
                    "Chọn thư mục được xuất từ LaunchOne trước đó",
                .legacyArchivePanelMessage:
                    "Chọn lưu trữ Launchpad Legacy (.lmy/.zip) hoặc tệp db",
                .importSuccessfulTitle: "Nhập thành công",
                .importFailedTitle: "Nhập thất bại",
                .okButton: "OK",

                // Cập nhật
                .checkForUpdates: "Kiểm tra cập nhật",
                .checkForUpdatesButton: "Kiểm tra cập nhật",
                .checkingForUpdates: "Đang kiểm tra cập nhật...",
                .upToDate: "Bạn đang dùng phiên bản mới nhất",
                .updateAvailable: "Có bản cập nhật mới",
                .newVersion: "Phiên bản mới:",
                .downloadUpdate: "Tải bản cập nhật",
                .updateCheckFailed: "Kiểm tra cập nhật thất bại",
                .tryAgain: "Thử lại",
                .autoCheckForUpdates: "Tự động kiểm tra cập nhật",
                .versionParseError: "Lỗi phân tích phiên bản",

                // Login item (silent)
                .startAtLoginTitle: "Khởi động cùng hệ thống (ẩn)",
                .startAtLoginToggle: "Bật",
                .startAtLoginDescription: "Tự chạy khi đăng nhập mà không hiển thị giao diện. Dùng phím tắt toàn cục để mở khi cần.",
                .loginItemPermissionHint: "Hãy cho phép ‘LaunchOne’ chạy nền tại Cài đặt hệ thống → Mục đăng nhập.",
            ],
            .simplifiedChinese: [
                .noAppsFound: "未找到任何应用",
                .searchPlaceholder: "搜索",
                .renameSearchPlaceholder: "搜索应用",
                .customTitlePlaceholder: "输入自定义名称",
                .customTitleHint: "在这里为任意应用重命名；即使重新导入或切换本地化也会保留。",
                .customTitleDefaultFormat: "默认：%@",
                .customTitleReset: "恢复默认",
                .customTitleAddButton: "添加应用",
                .customTitleEmptyTitle: "当前没有自定义名称",
                .customTitleEmptySubtitle: "点击按钮选择应用即可开始重命名；重新导入或切换语言都会保留这些设置。",
                .customTitleNoResults: "没有匹配项",
                .customTitlePickerMessage: "选择一个应用来管理显示名称。",
                .customTitleEdit: "编辑",
                .customTitleSave: "保存",
                .customTitleCancel: "取消",
                .customTitleDelete: "删除",
                .loadingApplications: "正在加载应用…",
                .showFPSOverlay: "显示 FPS",
                .showFPSOverlayDisclaimer: "当前数值仅供参考，可能与实际帧率存在差异。",
                .dockDisplayTitle: "Dock 显示",
                .dockDisplayToggle: "在 Dock 中显示图标",
                .dockDisplayDescription:
                    "开启后应用图标会显示在 Dock 中，关闭后应用将完全后台运行。更改立即生效。",
                .customIconTitle: "应用图标",
                .customIconChoose: "选择…",
                .customIconReset: "恢复默认图标",
                .customIconHint: "建议使用 512×512 的 PNG/ICNS 文件，修改会立即生效。",
                .customIconError: "无法加载所选图像。",
                .pageIndicatorOffsetLabel: "页面指示器间距",
                .appTitle: "LaunchOne",
                .modifiedFrom: "基于 LaunchNext 1.0.6 修改",
                .backgroundHint: "保持后台运行：可将 LaunchOne 固定在 Dock 或使用快捷键打开窗口",
                .classicMode: "经典 Launchpad（全屏）",
                .iconSize: "图标大小",
                .iconsPerRow: "每行图标数量",
                .rowsPerPage: "每页行数",
                .iconHorizontalSpacing: "横向间距",
                .iconVerticalSpacing: "纵向间距",
                .labelFontSize: "标签字体大小",
                .iconLabelFontWeight: "图标文字粗细",
                .smaller: "更小",
                .larger: "更大",
                .predictDrop: "启用落点预判",
                .showLabels: "显示图标文字",
                .useLocalizedThirdPartyTitles: "使用本地化应用名称",
                .enableAnimations: "启用滑动动画",
                .hoverMagnification: "悬停放大效果",
                .hoverMagnificationScale: "悬停放大倍率",
                .activePressEffect: "按下缩放反馈",
                .activePressScale: "按下缩放倍率",
                .animationDurationLabel: "滑动动画时长",
                .gridSizeChangeWarning: "调整网格设置可能导致部分图标位置发生变化。",
                .pageIndicatorHint: "若间距变化不明显，可下调页面指示点的位置。",
                .rememberPageTitle: "记住上次打开的页面",
                .globalShortcutTitle: "全局快捷键",
                .shortcutSetButton: "设置快捷键",
                .shortcutSaveButton: "保存",
                .shortcutClearButton: "清除",
                .shortcutNotSet: "未设置",
                .shortcutListening: "等待按键…",
                .shortcutCapturePrompt: "按下想要的快捷键组合，按 Esc 取消。",
                .shortcutNoModifierWarning: "未使用修饰键可能与其他应用冲突。",
                .scrollSensitivity: "滚动灵敏度",
                .low: "低",
                .high: "高",
                .importSystem: "导入系统 Launchpad",
                .importLegacy: "导入 Legacy (.lmy)",
                .importTip: "提示：点击“导入系统 Launchpad”即可直接导入原生布局。",
                .exportData: "导出数据",
                .importData: "导入数据",
                .refresh: "刷新",
                .showQuickRefreshButton: "显示快速刷新按钮",
                .resetLayout: "重置布局",
                .resetAlertTitle: "确认要重置布局？",
                .resetAlertMessage: "这将完全重置布局：删除所有文件夹、清除保存顺序并重新扫描应用。所有自定义都会丢失。",
                .resetConfirm: "重置",
                .cancel: "取消",
                .quit: "退出",
                .menuAbout: "关于 LaunchOne",
                .menuSettings: "设置…",
                .menuQuit: "退出",
                .languagePickerTitle: "语言",
                .appearanceModeTitle: "外观模式",
                .appearanceModeFollowSystem: "跟随系统",
                .appearanceModeLight: "浅色",
                .appearanceModeDark: "暗色",
                .folderWindowWidth: "文件夹窗口宽度",
                .folderWindowHeight: "文件夹窗口高度",
                .folderWindowSizeHint: "仅在非经典模式下生效；经典全屏使用固定布局。",
                .versionPrefix: "版本 ",
                .languageNameSystem: "跟随系统",
                .languageNameEnglish: "英語",
                .languageNameChinese: "中国語",
                .languageNameJapanese: "日本語",
                .languageNameKorean: "韩语",
                .languageNameFrench: "フランス語",
                .languageNameSpanish: "スペイン語",
                .languageNameGerman: "ドイツ語",
                .languageNameRussian: "俄语",
                .languageNameHindi: "印地语",
                .languageNameVietnamese: "越南语",
                .folderNamePlaceholder: "文件夹名称",
                .viewOnGitHub: "打开项目链接",
                .chooseButton: "选择",
                .exportPanelMessage: "选择一个目标文件夹导出 LaunchOne 数据",
                .importPrompt: "导入",
                .importPanelMessage: "请选择之前由 LaunchOne 导出的文件夹",
                .legacyArchivePanelMessage:
                    "请选择 Legacy Launchpad 归档（.lmy/.zip）或 db 文件",
                .importSuccessfulTitle: "导入成功",
                .importFailedTitle: "导入失败",
                .okButton: "确定",

                // Update check related
                .checkForUpdates: "检查更新",
                .checkForUpdatesButton: "检查更新",
                .checkingForUpdates: "正在检查更新...",
                .upToDate: "已是最新版本",
                .updateAvailable: "发现新版本",
                .newVersion: "新版本：",
                .downloadUpdate: "下载更新",
                .updateCheckFailed: "更新检查失败",
                .tryAgain: "重试",
                .autoCheckForUpdates: "自动检查更新",
                .versionParseError: "版本解析错误",

                // Login item (silent)
                .startAtLoginTitle: "开机自启（静默）",
                .startAtLoginToggle: "启用",
                .startAtLoginDescription: "登录时启动且不显示界面。可通过全局快捷键在需要时唤起窗口。",
                .loginItemPermissionHint: "请在 系统设置 → 登录项 中允许 ‘LaunchOne’ 在后台运行。",
            ],
            .japanese: [
                .noAppsFound: "アプリが見つかりません",
                .searchPlaceholder: "検索",
                .renameSearchPlaceholder: "アプリを検索",
                .customTitlePlaceholder: "カスタム名を入力",
                .customTitleHint:
                    "ここでアプリ名を自由に変更できます。再インポートやローカライズ設定を切り替えても保持されます。",
                .customTitleDefaultFormat: "デフォルト: %@",
                .customTitleReset: "デフォルトに戻す",
                .customTitleAddButton: "アプリを追加",
                .customTitleEmptyTitle: "カスタム名はまだありません",
                .customTitleEmptySubtitle:
                    "ボタンを押してアプリを選べばリネームを始められます。再インポートや言語変更後も保持されます。",
                .customTitleNoResults: "一致する項目がありません",
                .customTitlePickerMessage: "表示名を管理したいアプリを選択してください。",
                .customTitleEdit: "編集",
                .customTitleSave: "保存",
                .customTitleCancel: "キャンセル",
                .customTitleDelete: "削除",
                .loadingApplications: "アプリを読み込み中…",
                .showFPSOverlay: "FPS オーバーレイを表示",
                .showFPSOverlayDisclaimer:
                    "簡易的な計測値であり、実際のフレームタイミングとは異なる場合があります。",
                .dockDisplayTitle: "Dock 表示",
                .dockDisplayToggle: "Dock にアイコンを表示",
                .dockDisplayDescription:
                    "有効にすると、アプリアイコンが Dock に表示されます。無効にすると、アプリは完全にバックグラウンドで実行されます。変更は即座に反映されます。",
                .customIconTitle: "アプリのアイコン",
                .customIconChoose: "選択…",
                .customIconReset: "デフォルトに戻す",
                .customIconHint: "512×512 の PNG/ICNS ファイルが推奨です。変更はすぐに反映されます。",
                .customIconError: "選択した画像を読み込めませんでした。",
                .pageIndicatorOffsetLabel: "ページインジケーターの距離",
                .appTitle: "LaunchOne",
                .modifiedFrom: "LaunchNext 1.0.6 をベースに改良",
                .backgroundHint:
                    "バックグラウンドで実行するには、LaunchOne を Dock に追加するかショートカットで開いてください",
                .classicMode: "クラシック Launchpad（フルスクリーン）",
                .iconSize: "アイコンサイズ",
                .iconsPerRow: "1 行あたりのアイコン数",
                .rowsPerPage: "ページあたりの行数",
                .iconHorizontalSpacing: "横方向の間隔",
                .iconVerticalSpacing: "縦方向の間隔",
                .labelFontSize: "ラベルの文字サイズ",
                .iconLabelFontWeight: "アイコンラベルの太さ",
                .smaller: "小さく",
                .larger: "大きく",
                .predictDrop: "ドロップ位置を予測",
                .showLabels: "アイコン名を表示",
                .useLocalizedThirdPartyTitles: "アプリ名をローカライズ",
                .enableAnimations: "スライドアニメーションを有効化",
                .hoverMagnification: "ホバー拡大",
                .hoverMagnificationScale: "ホバー倍率",
                .activePressEffect: "押下時の縮小",
                .activePressScale: "押下時の倍率",
                .animationDurationLabel: "スライドアニメーション時間",
                .gridSizeChangeWarning: "グリッドサイズを変更すると、アイコンの配置が変わる場合があります。",
                .pageIndicatorHint: "変化が分かりにくいときは、ページインジケーターの位置を調整してください。",
                .rememberPageTitle: "最後に開いたページを記憶",
                .globalShortcutTitle: "グローバルショートカット",
                .shortcutSetButton: "ショートカットを設定",
                .shortcutSaveButton: "保存",
                .shortcutClearButton: "クリア",
                .shortcutNotSet: "未設定",
                .shortcutListening: "入力待ち…",
                .shortcutCapturePrompt: "希望するキーを押してください。Esc でキャンセルできます。",
                .shortcutNoModifierWarning: "修飾キーなしの設定は他のアプリと競合する可能性があります。",
                .scrollSensitivity: "スクロール感度",
                .low: "低",
                .high: "高",
                .importSystem: "システム Launchpad をインポート",
                .importLegacy: "Legacy (.lmy) をインポート",
                .importTip:
                    "ヒント：『システム Launchpad をインポート』をクリックすると既存レイアウトを直接取り込めます。",
                .exportData: "データをエクスポート",
                .importData: "データをインポート",
                .refresh: "リフレッシュ",
                .showQuickRefreshButton: "クイックリフレッシュボタンを表示",
                .resetLayout: "レイアウトをリセット",
                .resetAlertTitle: "レイアウトをリセットしますか？",
                .resetAlertMessage:
                    "すべてのフォルダを削除し、順序をリセットしてアプリを再スキャンします。カスタマイズは失われます。",
                .resetConfirm: "リセット",
                .cancel: "キャンセル",
                .quit: "終了",
                .menuAbout: "LaunchOne について",
                .menuSettings: "設定…",
                .menuQuit: "終了",
                .languagePickerTitle: "言語",
                .appearanceModeTitle: "外観モード",
                .appearanceModeFollowSystem: "システムに合わせる",
                .appearanceModeLight: "ライト",
                .appearanceModeDark: "ダーク",
                .folderWindowWidth: "フォルダーウィンドウの幅",
                .folderWindowHeight: "フォルダーウィンドウの高さ",
                .folderWindowSizeHint: "ウィンドウモードでのみ有効。クラシック全画面では固定サイズです。",
                .versionPrefix: "v",
                .languageNameSystem: "システムに従う",
                .languageNameEnglish: "Anglais",
                .languageNameChinese: "Chinois",
                .languageNameJapanese: "Japonais",
                .languageNameKorean: "Coréen",
                .languageNameFrench: "Français",
                .languageNameSpanish: "Espagnol",
                .languageNameGerman: "Allemand",
                .languageNameRussian: "Russe",
                .languageNameHindi: "Hindi",
                .languageNameVietnamese: "Vietnamien",
                .folderNamePlaceholder: "フォルダ名",
                .viewOnGitHub: "プロジェクトリンクを開く",
                .chooseButton: "選択",
                .exportPanelMessage: "LaunchOne のデータを書き出す保存先フォルダを選択してください",
                .importPrompt: "インポート",
                .importPanelMessage: "以前 LaunchOne から書き出したフォルダを選択してください",
                .legacyArchivePanelMessage:
                    "Legacy Launchpad アーカイブ（.lmy/.zip）または db ファイルを選択してください",
                .importSuccessfulTitle: "インポート成功",
                .importFailedTitle: "インポート失敗",
                .okButton: "OK",

                // Update check related (Japanese)
                .checkForUpdates: "アップデートを確認",
                .checkForUpdatesButton: "アップデートを確認",
                .checkingForUpdates: "アップデートを確認中...",
                .upToDate: "最新版です",
                .updateAvailable: "アップデートが利用可能",
                .newVersion: "新しいバージョン：",
                .downloadUpdate: "アップデートをダウンロード",
                .updateCheckFailed: "アップデート確認に失敗",
                .tryAgain: "再試行",
                .autoCheckForUpdates: "自動でアップデートを確認",
                .versionParseError: "バージョン解析エラー",

                // Login item (silent)
                .startAtLoginTitle: "ログイン時に起動（サイレント）",
                .startAtLoginToggle: "有効化",
                .startAtLoginDescription: "ログイン時にUIを表示せずに起動します。必要になったらグローバルショートカットでウィンドウを開けます。",
                .loginItemPermissionHint: "システム設定 → ログイン項目 で ‘LaunchOne’ のバックグラウンド実行を許可してください。",
            ],
            .korean: [
                .noAppsFound: "앱을 찾을 수 없어요",
                .searchPlaceholder: "검색",
                .renameSearchPlaceholder: "앱 검색",
                .customTitlePlaceholder: "사용자 지정 이름 입력",
                .customTitleHint:
                    "여기에서 앱 이름을 변경할 수 있습니다. 다시 가져오거나 언어를 바꿔도 유지돼요.",
                .customTitleDefaultFormat: "기본값: %@",
                .customTitleReset: "기본값으로 복원",
                .customTitleAddButton: "앱 추가",
                .customTitleEmptyTitle: "사용자 지정 이름이 없습니다",
                .customTitleEmptySubtitle:
                    "버튼을 눌러 앱을 선택하면 이름 변경을 시작할 수 있어요. 가져오기나 언어 변경 후에도 유지돼요.",
                .customTitleNoResults: "일치하는 항목이 없어요",
                .customTitlePickerMessage: "표시 이름을 관리할 앱을 선택하세요.",
                .customTitleEdit: "편집",
                .customTitleSave: "저장",
                .customTitleCancel: "취소",
                .customTitleDelete: "삭제",
                .loadingApplications: "앱을 불러오는 중…",
                .showFPSOverlay: "FPS 오버레이 표시",
                .showFPSOverlayDisclaimer: "대략적인 수치로 실제 프레임 속도와 다를 수 있어요.",
                .dockDisplayTitle: "Dock 표시",
                .dockDisplayToggle: "Dock에 아이콘 표시",
                .dockDisplayDescription:
                    "활성화하면 앱 아이콘이 Dock에 표시됩니다. 비활성화하면 앱이 완전히 백그라운드에서 실행됩니다. 변경사항이 즉시 적용됩니다.",
                .customIconTitle: "앱 아이콘",
                .customIconChoose: "선택…",
                .customIconReset: "기본 아이콘으로 복원",
                .customIconHint: "512×512 PNG/ICNS 파일을 권장해요. 변경 사항은 즉시 적용돼요.",
                .customIconError: "선택한 이미지를 불러올 수 없습니다.",
                .pageIndicatorOffsetLabel: "페이지 지시점 간격",
                .appTitle: "LaunchOne",
                .modifiedFrom: "LaunchNext 1.0.6을 기반으로 수정",
                .backgroundHint:
                    "백그라운드에서 실행하려면 LaunchOne를 Dock에 고정하거나 단축키로 창을 여세요",
                .classicMode: "클래식 Launchpad(전체 화면)",
                .iconSize: "아이콘 크기",
                .iconsPerRow: "행당 아이콘 수",
                .rowsPerPage: "페이지당 행 수",
                .iconHorizontalSpacing: "가로 간격",
                .iconVerticalSpacing: "세로 간격",
                .labelFontSize: "레이블 글자 크기",
                .iconLabelFontWeight: "아이콘 라벨 두께",
                .smaller: "작게",
                .larger: "크게",
                .predictDrop: "놓을 위치 예측",
                .showLabels: "아이콘 이름 표시",
                .useLocalizedThirdPartyTitles: "번역된 앱 이름 사용",
                .enableAnimations: "슬라이드 애니메이션 사용",
                .hoverMagnification: "호버 확대",
                .hoverMagnificationScale: "호버 확대 배율",
                .activePressEffect: "누를 때 피드백",
                .activePressScale: "누를 때 배율",
                .animationDurationLabel: "슬라이드 애니메이션 길이",
                .gridSizeChangeWarning: "격자 크기를 바꾸면 일부 아이콘 위치가 변경될 수 있어요.",
                .pageIndicatorHint: "변화가 미미하다면 아래에서 페이지 지시점 위치를 조정하세요.",
                .rememberPageTitle: "마지막으로 연 페이지 기억",
                .globalShortcutTitle: "전역 단축키",
                .shortcutSetButton: "단축키 설정",
                .shortcutSaveButton: "저장",
                .shortcutClearButton: "지우기",
                .shortcutNotSet: "설정되지 않음",
                .shortcutListening: "키 입력 대기 중…",
                .shortcutCapturePrompt: "원하는 키 조합을 누르세요. Esc로 취소해요.",
                .shortcutNoModifierWarning: "보조키 설정을 하지않으면 다른 앱과 충돌할 수 있어요.",
                .scrollSensitivity: "스크롤 민감도",
                .low: "낮음",
                .high: "높음",
                .importSystem: "시스템 Launchpad 가져오기",
                .importLegacy: "Legacy (.lmy) 가져오기",
                .importTip:
                    "팁: ‘시스템 Launchpad 가져오기’를 누르면 기본 Launchpad 배치를 바로 불러옵니다.",
                .exportData: "데이터 내보내기",
                .importData: "데이터 가져오기",
                .refresh: "새로 고침",
                .showQuickRefreshButton: "빠른 새로 고침 버튼 표시",
                .resetLayout: "레이아웃 초기화",
                .resetAlertTitle: "레이아웃을 초기화할까요?",
                .resetAlertMessage:
                    "모든 폴더를 삭제하고 저장된 순서를 지운 뒤 앱을 다시 스캔해요. 모든 사용자 설정이 사라져요.",
                .resetConfirm: "초기화",
                .cancel: "취소",
                .quit: "종료",
                .menuAbout: "LaunchOne 정보",
                .menuSettings: "설정…",
                .menuQuit: "종료",
                .languagePickerTitle: "언어",
                .appearanceModeTitle: "모양",
                .appearanceModeFollowSystem: "시스템과 동일",
                .appearanceModeLight: "라이트",
                .appearanceModeDark: "다크",
                .folderWindowWidth: "폴더 창 너비",
                .folderWindowHeight: "폴더 창 높이",
                .folderWindowSizeHint:
                    "창 모드에서만 적용돼요. 클래식 전체 화면은 고정 레이아웃을 사용해요.",
                .versionPrefix: "v",
                .languageNameSystem: "시스템과 동일",
                .languageNameEnglish: "영어",
                .languageNameChinese: "중국어",
                .languageNameJapanese: "일본어",
                .languageNameKorean: "한국어",
                .languageNameFrench: "프랑스어",
                .languageNameSpanish: "스페인어",
                .languageNameGerman: "독일어",
                .languageNameRussian: "러시아어",
                .languageNameHindi: "힌디어",
                .languageNameVietnamese: "베트남어",
                .folderNamePlaceholder: "폴더 이름",
                .viewOnGitHub: "프로젝트 링크 열기",
                .chooseButton: "선택",
                .exportPanelMessage: "LaunchOne 데이터를 내보낼 폴더를 선택해주세요",
                .importPrompt: "가져오기",
                .importPanelMessage: "LaunchOne에서 내보낸 폴더를 선택해주세요",
                .legacyArchivePanelMessage:
                    "Legacy Launchpad 아카이브(.lmy/.zip) 또는 db 파일을 선택해주세요",
                .importSuccessfulTitle: "가져오기에 성공했어요",
                .importFailedTitle: "가져오기에 실패했어요",
                .okButton: "확인",

                // 업데이트 관련
                .checkForUpdates: "업데이트 확인",
                .checkForUpdatesButton: "업데이트 확인",
                .checkingForUpdates: "업데이트를 확인하고 있어요",
                .upToDate: "최신 버전이에요",
                .updateAvailable: "업데이트가 있어요",
                .newVersion: "새 버전:",
                .downloadUpdate: "업데이트 다운로드",
                .updateCheckFailed: "업데이트 확인에 실패했어요",
                .tryAgain: "다시 시도하기",
                .autoCheckForUpdates: "업데이트 자동 확인",
                .versionParseError: "버전 분석 오류",

                // Login item (silent)
                .startAtLoginTitle: "로그인 시 자동 시작(조용히)",
                .startAtLoginToggle: "켜기",
                .startAtLoginDescription: "로그인할 때 UI 없이 실행합니다. 필요 시 전역 단축키로 창을 띄울 수 있어요.",
                .loginItemPermissionHint: "시스템 설정 → 로그인 항목에서 ‘LaunchOne’의 백그라운드 실행을 허용하세요.",
            ],
            .french: [
                .noAppsFound: "Aucune application trouvée",
                .searchPlaceholder: "Recherche",
                .renameSearchPlaceholder: "Rechercher une application",
                .customTitlePlaceholder: "Saisir un nom personnalisé",
                .customTitleHint:
                    "Renommez vos applications ici. Les noms personnalisés restent même après réimportation ou changement de langue.",
                .customTitleDefaultFormat: "Nom par défaut : %@",
                .customTitleReset: "Restaurer le nom par défaut",
                .customTitleAddButton: "Ajouter une application",
                .customTitleEmptyTitle: "Aucun nom personnalisé",
                .customTitleEmptySubtitle:
                    "Sélectionnez une application pour commencer à la renommer. Les noms personnalisés restent après réimportation ou changement de langue.",
                .customTitleNoResults: "Aucun résultat",
                .customTitlePickerMessage:
                    "Choisissez l’application dont vous souhaitez modifier le nom",
                .customTitleEdit: "Modifier",
                .customTitleSave: "Enregistrer",
                .customTitleCancel: "Annuler",
                .customTitleDelete: "Supprimer",
                .loadingApplications: "Chargement des applications…",
                .showFPSOverlay: "Afficher le nombre d'image par seconde",
                .showFPSOverlayDisclaimer:
                    "Valeur indicative qui peut ne pas refléter précisément le rafraîchissement réel.",
                .customIconTitle: "Icône de l’application",
                .customIconChoose: "Choisir…",
                .customIconReset: "Réinitialiser l’icône",
                .customIconHint:
                    "Utilisez de préférence un fichier PNG/ICNS 512×512. Les changements sont appliqués immédiatement.",
                .customIconError: "Impossible de charger l’image sélectionnée.",
                .pageIndicatorOffsetLabel:
                    "Espacement des indicateurs de pages",
                .appTitle: "LaunchOne",
                .modifiedFrom: "Basé sur LaunchNext 1.0.6",
                .backgroundHint:
                    "Pour exécuter LaunchOne en arrière-plan, épinglez l'application au Dock ou utilisez un raccourci clavier pour ouvrir la fenêtre.",
                .classicMode: "Plein écran",
                .iconSize: "Taille des icônes",
                .iconsPerRow: "Icônes par ligne",
                .rowsPerPage: "Lignes par page",
                .iconHorizontalSpacing: "Espacement horizontal",
                .iconVerticalSpacing: "Espacement vertical",
                .labelFontSize: "Taille de la police des noms des applications",
                .iconLabelFontWeight: "Épaisseur du texte des icônes",
                .smaller: "Petites",
                .larger: "Grandes",
                .predictDrop: "Prédire la position de placement",
                .showLabels: "Afficher les noms des applications",
                .useLocalizedThirdPartyTitles:
                    "Afficher les noms des applications dans la langue du système",
                .enableAnimations: "Animation de transition",
                .hoverMagnification: "Effet de zoom au survol",
                .hoverMagnificationScale: "Facteur de zoom au survol",
                .activePressEffect: "Effet de zoom arrière lors du clic",
                .activePressScale: "Facteur de zoom arrière lors du clic",
                .animationDurationLabel: "Durée de l’animation de transition",
                .gridSizeChangeWarning:
                    "Modifier la taille de la grille peut déplacer certaines icônes.",
                .pageIndicatorHint:
                    "Si le changement semble subtil, ajustez l’espacement des indicateurs de pages ci-dessous.",
                .rememberPageTitle: "Mémoriser la dernière page ouverte",
                .globalShortcutTitle: "Raccourci global",
                .shortcutSetButton: "Définir le raccourci",
                .shortcutSaveButton: "Enregistrer",
                .shortcutClearButton: "Effacer",
                .shortcutNotSet: "Aucun",
                .shortcutListening: "En écoute…",
                .shortcutCapturePrompt:
                    "Appuyez sur le raccourci souhaité. Échap pour annuler.",
                .shortcutNoModifierWarning:
                    "Sans modificateur, le raccourci risque d’entrer en conflit.",
                .scrollSensitivity: "Sensibilité de défilement",
                .low: "Faible",
                .high: "Élevée",
                .importSystem: "Importer le Launchpad système",
                .importLegacy: "Importer un fichier .lmy",
                .importTip:
                    "Astuce : cliquez sur « Importer le Launchpad système » pour récupérer la disposition d’origine.",
                .exportData: "Exporter les données",
                .importData: "Importer des données",
                .refresh: "Actualiser",
                .showQuickRefreshButton:
                    "Afficher le bouton de rafraîchissement rapide",
                .resetLayout: "Réinitialiser la disposition",
                .resetAlertTitle: "Confirmer la réinitialisation ?",
                .resetAlertMessage:
                    "La disposition des icônes sera réinitialisée, les dossiers supprimés et les applications rescannées. Toutes les personnalisations seront donc perdues.",
                .resetConfirm: "Réinitialiser",
                .cancel: "Annuler",
                .quit: "Quitter",
                .menuAbout: "À propos de LaunchOne",
                .menuSettings: "Préférences…",
                .menuQuit: "Quitter",
                .languagePickerTitle: "Langue",
                .appearanceModeTitle: "Thème",
                .appearanceModeFollowSystem: "Défini par le système",
                .appearanceModeLight: "Clair",
                .appearanceModeDark: "Sombre",
                .folderWindowWidth: "Largeur de la fenêtre des dossiers",
                .folderWindowHeight: "Hauteur de la fenêtre des dossiers",
                .folderWindowSizeHint:
                    "S’applique uniquement en mode fenêtre, le mode plein écran utilise une taille fixe.",
                .versionPrefix: "v",
                .languageNameSystem: "Définie par le système",
                .languageNameEnglish: "English",
                .languageNameChinese: "中文",
                .languageNameJapanese: "日本語",
                .languageNameKorean: "韩语",
                .languageNameFrench: "Français",
                .languageNameSpanish: "Español",
                .languageNameGerman: "Deutsch",
                .languageNameRussian: "Русский",
                .languageNameHindi: "Hindi",
                .folderNamePlaceholder: "Nom du dossier",
                .viewOnGitHub: "Ouvrir le lien du projet",
                .chooseButton: "Choisir",
                .exportPanelMessage:
                    "Choisissez un dossier de destination pour exporter les données de LaunchOne",
                .importPrompt: "Importer",
                .importPanelMessage:
                    "Sélectionnez un dossier précédemment exporté depuis LaunchOne",
                .legacyArchivePanelMessage:
                    "Sélectionnez une archive Launchpad Legacy (.lmy/.zip) ou un fichier db",
                .importSuccessfulTitle: "Import réussi",
                .importFailedTitle: "Import échoué",
                .okButton: "OK",

                // Vérification des mises à jour
                .checkForUpdates: "Vérifier les mises à jour",
                .checkForUpdatesButton: "Vérifier les mises à jour",
                .checkingForUpdates: "Vérification en cours...",
                .upToDate: "Vous êtes à jour",
                .updateAvailable: "Mise à jour disponible",
                .newVersion: "Nouvelle version :",
                .downloadUpdate: "Télécharger la mise à jour",
                .updateCheckFailed: "Échec de la vérification",
                .tryAgain: "Réessayer",
                .autoCheckForUpdates: "Vérification automatique",
                .versionParseError: "Erreur d'analyse de version",

                // Login item (silent)
                .startAtLoginTitle: "Lancer à l’ouverture de session (silencieux)",
                .startAtLoginToggle: "Activer",
                .startAtLoginDescription: "Lance l’app au démarrage sans afficher d’UI. Utilisez le raccourci global pour afficher la fenêtre.",
                .loginItemPermissionHint: "Autorisez ‘LaunchOne’ à s’exécuter en arrière-plan dans Réglages système → Ouverture.",
            ],
            .spanish: [
                .noAppsFound: "No se encontraron apps",
                .searchPlaceholder: "Buscar",
                .renameSearchPlaceholder: "Buscar app",
                .customTitlePlaceholder: "Escribe un nombre personalizado",
                .customTitleHint:
                    "Renombra cualquier app aquí. Los nombres personalizados se conservan tras volver a importar o cambiar la localización.",
                .customTitleDefaultFormat: "Predeterminado: %@",
                .customTitleReset: "Restaurar predeterminado",
                .customTitleAddButton: "Agregar aplicación",
                .customTitleEmptyTitle: "Aún no hay nombres personalizados",
                .customTitleEmptySubtitle:
                    "Elige una app para empezar a renombrarla. Los nombres personalizados se conservan aunque reimportes o cambies de idioma.",
                .customTitleNoResults: "Sin coincidencias",
                .customTitlePickerMessage:
                    "Selecciona la aplicación cuyo título quieres gestionar.",
                .customTitleEdit: "Editar",
                .customTitleSave: "Guardar",
                .customTitleCancel: "Cancelar",
                .customTitleDelete: "Eliminar",
                .loadingApplications: "Cargando aplicaciones…",
                .showFPSOverlay: "Mostrar overlay de FPS",
                .showFPSOverlayDisclaimer:
                    "Medición aproximada; puede no coincidir con la cadencia real de cuadros.",
                .dockDisplayTitle: "Mostrar en Dock",
                .dockDisplayToggle: "Mostrar icono en Dock",
                .dockDisplayDescription:
                    "Cuando está habilitado, el icono de la aplicación aparecerá en el Dock. Cuando está deshabilitado, la aplicación se ejecutará completamente en segundo plano. Los cambios se aplican inmediatamente.",
                .customIconTitle: "Icono de la aplicación",
                .customIconChoose: "Elegir…",
                .customIconReset: "Restaurar icono predeterminado",
                .customIconHint:
                    "Se recomienda un archivo PNG/ICNS de 512×512. Los cambios se aplican al instante.",
                .customIconError: "No se pudo cargar la imagen seleccionada.",
                .pageIndicatorOffsetLabel: "Separación del indicador de página",
                .appTitle: "LaunchOne",
                .modifiedFrom: "Modificado a partir de LaunchNext versión 1.0.6",
                .backgroundHint:
                    "Para ejecutarlo en segundo plano, fija LaunchOne en el Dock o usa atajos de teclado para abrir la ventana",
                .classicMode: "Launchpad clásico (pantalla completa)",
                .iconSize: "Tamaño de iconos",
                .iconsPerRow: "Iconos por fila",
                .rowsPerPage: "Filas por página",
                .iconHorizontalSpacing: "Espaciado horizontal",
                .iconVerticalSpacing: "Espaciado vertical",
                .labelFontSize: "Tamaño de fuente de las etiquetas",
                .iconLabelFontWeight: "Grosor del texto del icono",
                .smaller: "Más pequeño",
                .larger: "Más grande",
                .predictDrop: "Predecir posición de caída",
                .showLabels: "Mostrar nombres de iconos",
                .useLocalizedThirdPartyTitles: "Usar nombres localizados",
                .enableAnimations: "Activar la animación de deslizamiento",
                .hoverMagnification: "Ampliación al pasar el cursor",
                .hoverMagnificationScale: "Factor de ampliación",
                .activePressEffect: "Retroalimentación al pulsar",
                .activePressScale: "Factor de pulsación",
                .animationDurationLabel:
                    "Duración de la animación de deslizamiento",
                .gridSizeChangeWarning:
                    "Cambiar el tamaño de la cuadrícula puede recolocar algunos iconos.",
                .pageIndicatorHint:
                    "Si notas poco cambio, ajusta el indicador de página más abajo.",
                .rememberPageTitle: "Recordar la última página abierta",
                .globalShortcutTitle: "Atajo global",
                .shortcutSetButton: "Definir atajo",
                .shortcutSaveButton: "Guardar",
                .shortcutClearButton: "Limpiar",
                .shortcutNotSet: "Sin definir",
                .shortcutListening: "Escuchando…",
                .shortcutCapturePrompt:
                    "Pulsa la combinación deseada. Esc para cancelar.",
                .shortcutNoModifierWarning:
                    "Sin modificadores puede entrar en conflicto con otras apps.",
                .scrollSensitivity: "Sensibilidad de desplazamiento",
                .low: "Baja",
                .high: "Alta",
                .importSystem: "Importar Launchpad del sistema",
                .importLegacy: "Importar Legacy (.lmy)",
                .importTip:
                    "Consejo: haz clic en «Importar Launchpad del sistema» para traer directamente tu disposición actual.",
                .exportData: "Exportar datos",
                .importData: "Importar datos",
                .refresh: "Actualizar",
                .showQuickRefreshButton:
                    "Mostrar botón de actualización rápida",
                .resetLayout: "Reiniciar diseño",
                .resetAlertTitle: "¿Reiniciar el diseño?",
                .resetAlertMessage:
                    "Esto restablecerá por completo el diseño: eliminará carpetas, limpiará el orden y volverá a escanear las apps. Se perderán todas las personalizaciones.",
                .resetConfirm: "Reiniciar",
                .cancel: "Cancelar",
                .quit: "Salir",
                .menuAbout: "Acerca de LaunchOne",
                .menuSettings: "Preferencias…",
                .menuQuit: "Salir",
                .languagePickerTitle: "Idioma",
                .appearanceModeTitle: "Apariencia",
                .appearanceModeFollowSystem: "Seguir al sistema",
                .appearanceModeLight: "Claro",
                .appearanceModeDark: "Oscuro",
                .folderWindowWidth: "Ancho de la ventana de carpetas",
                .folderWindowHeight: "Alto de la ventana de carpetas",
                .folderWindowSizeHint:
                    "Solo se aplica en modo ventana; el modo clásico a pantalla completa usa un tamaño fijo.",
                .versionPrefix: "v",
                .languageNameSystem: "Seguir sistema",
                .languageNameEnglish: "English",
                .languageNameChinese: "中文",
                .languageNameJapanese: "日本語",
                .languageNameKorean: "한국어",
                .languageNameFrench: "Français",
                .languageNameSpanish: "Español",
                .languageNameGerman: "Deutsch",
                .languageNameRussian: "Русский",
                .languageNameVietnamese: "Vietnamita",
                .folderNamePlaceholder: "Nombre de la carpeta",
                .viewOnGitHub: "Abrir enlace del proyecto",
                .chooseButton: "Elegir",
                .exportPanelMessage:
                    "Elige una carpeta de destino para exportar los datos de LaunchOne",
                .importPrompt: "Importar",
                .importPanelMessage:
                    "Selecciona una carpeta previamente exportada desde LaunchOne",
                .legacyArchivePanelMessage:
                    "Elige un archivo de Launchpad Legacy (.lmy/.zip) o un archivo db",
                .importSuccessfulTitle: "Importación completada",
                .importFailedTitle: "Importación fallida",
                .okButton: "OK",

                // Verificación de actualizaciones
                .checkForUpdates: "Buscar actualizaciones",
                .checkForUpdatesButton: "Buscar actualizaciones",
                .checkingForUpdates: "Buscando actualizaciones...",
                .upToDate: "Estás actualizado",
                .updateAvailable: "Actualización disponible",
                .newVersion: "Nueva versión:",
                .downloadUpdate: "Descargar actualización",
                .updateCheckFailed: "Error al buscar actualizaciones",
                .tryAgain: "Intentar de nuevo",
                .autoCheckForUpdates: "Buscar actualizaciones automáticamente",
                .versionParseError: "Error de análisis de versión",

                // Login item (silent)
                .startAtLoginTitle: "Iniciar al iniciar sesión (silencioso)",
                .startAtLoginToggle: "Activar",
                .startAtLoginDescription: "Se inicia al iniciar sesión sin mostrar interfaz. Usa el atajo global para mostrar la ventana cuando lo necesites.",
                .loginItemPermissionHint: "Permite que ‘LaunchOne’ se ejecute en segundo plano en Ajustes del sistema → Ítems de inicio.",
            ],
            .german: [
                .noAppsFound: "Keine Apps gefunden",
                .searchPlaceholder: "Suchen",
                .renameSearchPlaceholder: "Apps durchsuchen",
                .customTitlePlaceholder: "Eigenen Namen eingeben",
                .customTitleHint:
                    "Hier kannst du jeder App einen eigenen Namen geben. Bleibt auch nach erneutem Import oder Sprachwechsel erhalten.",
                .customTitleDefaultFormat: "Standard: %@",
                .customTitleReset: "Standard wiederherstellen",
                .customTitleAddButton: "App hinzufügen",
                .customTitleEmptyTitle: "Noch keine eigenen Namen",
                .customTitleEmptySubtitle:
                    "Wähle eine App aus, um sie umzubenennen. Eigene Namen bleiben auch nach erneutem Import oder Sprachwechsel erhalten.",
                .customTitleNoResults: "Keine Treffer",
                .customTitlePickerMessage:
                    "Wähle die App, deren Namen du verwalten möchtest.",
                .customTitleEdit: "Bearbeiten",
                .customTitleSave: "Speichern",
                .customTitleCancel: "Abbrechen",
                .customTitleDelete: "Entfernen",
                .loadingApplications: "Apps werden geladen…",
                .showFPSOverlay: "FPS-Overlay anzeigen",
                .showFPSOverlayDisclaimer:
                    "Nur ein Näherungswert, kann vom tatsächlichen Frame-Pacing abweichen.",
                .dockDisplayTitle: "Dock-Anzeige",
                .dockDisplayToggle: "Symbol im Dock anzeigen",
                .dockDisplayDescription:
                    "Wenn aktiviert, wird das App-Symbol im Dock angezeigt. Wenn deaktiviert, läuft die App vollständig im Hintergrund. Änderungen werden sofort angewendet.",
                .customIconTitle: "App-Symbol",
                .customIconChoose: "Auswählen…",
                .customIconReset: "Standard-Symbol wiederherstellen",
                .customIconHint:
                    "Empfohlen sind PNG/ICNS-Dateien mit 512×512 Pixel. Änderungen wirken sofort.",
                .customIconError:
                    "Das ausgewählte Bild konnte nicht geladen werden.",
                .pageIndicatorOffsetLabel: "Abstand der Seitenanzeige",
                .appTitle: "LaunchOne",
                .modifiedFrom: "Basierend auf LaunchNext Version 1.0.6",
                .backgroundHint:
                    "Für den Hintergrundbetrieb LaunchOne im Dock behalten oder mit Tastenkürzeln das Fenster öffnen",
                .classicMode: "Klassischer Launchpad (Vollbild)",
                .iconSize: "Symbolgröße",
                .iconsPerRow: "Symbole pro Zeile",
                .rowsPerPage: "Zeilen pro Seite",
                .iconHorizontalSpacing: "Horizontaler Abstand",
                .iconVerticalSpacing: "Vertikaler Abstand",
                .labelFontSize: "Schriftgröße der Beschriftung",
                .iconLabelFontWeight: "Schriftstärke der Symbolbeschriftung",
                .smaller: "Kleiner",
                .larger: "Größer",
                .predictDrop: "Ablageposition vorhersagen",
                .showLabels: "Beschriftungen unter Symbolen anzeigen",
                .useLocalizedThirdPartyTitles:
                    "Lokalisierte App-Namen verwenden",
                .enableAnimations: "Slide-Animation aktivieren",
                .hoverMagnification: "Vergrößern beim Überfahren",
                .hoverMagnificationScale: "Vergrößerungsfaktor",
                .activePressEffect: "Verkleinern beim Klicken",
                .activePressScale: "Klick-Faktor",
                .animationDurationLabel: "Dauer der Slide-Animation",
                .gridSizeChangeWarning:
                    "Das Ändern der Rastergröße kann einige Symbole neu anordnen.",
                .pageIndicatorHint:
                    "Wirkt der Effekt gering, passe den Seitenindikator darunter an.",
                .rememberPageTitle: "Letzte geöffnete Seite merken",
                .globalShortcutTitle: "Globaler Kurzbefehl",
                .shortcutSetButton: "Kurzbefehl setzen",
                .shortcutSaveButton: "Speichern",
                .shortcutClearButton: "Löschen",
                .shortcutNotSet: "Nicht gesetzt",
                .shortcutListening: "Warten…",
                .shortcutCapturePrompt:
                    "Drücke die gewünschte Tastenkombination. Esc zum Abbrechen.",
                .shortcutNoModifierWarning:
                    "Ohne Modifikatortaste kann es zu Konflikten mit Apps kommen.",
                .scrollSensitivity: "Scroll-Empfindlichkeit",
                .low: "Niedrig",
                .high: "Hoch",
                .importSystem: "System-Launchpad importieren",
                .importLegacy: "Legacy (.lmy) importieren",
                .importTip:
                    "Tipp: Klicken Sie auf „System-Launchpad importieren“, um das Layout direkt zu übernehmen.",
                .exportData: "Daten exportieren",
                .importData: "Daten importieren",
                .refresh: "Aktualisieren",
                .showQuickRefreshButton:
                    "Schnellaktualisierungsbutton anzeigen",
                .resetLayout: "Layout zurücksetzen",
                .resetAlertTitle: "Layout wirklich zurücksetzen?",
                .resetAlertMessage:
                    "Dies setzt das Layout vollständig zurück: Alle Ordner werden entfernt, die gespeicherte Reihenfolge gelöscht und alle Apps neu eingelesen. Anpassungen gehen verloren.",
                .resetConfirm: "Zurücksetzen",
                .cancel: "Abbrechen",
                .quit: "Beenden",
                .menuAbout: "Über LaunchOne",
                .menuSettings: "Einstellungen…",
                .menuQuit: "Beenden",
                .languagePickerTitle: "Sprache",
                .appearanceModeTitle: "Darstellung",
                .appearanceModeFollowSystem: "System folgen",
                .appearanceModeLight: "Hell",
                .appearanceModeDark: "Dunkel",
                .folderWindowWidth: "Ordnerfenster-Breite",
                .folderWindowHeight: "Ordnerfenster-Höhe",
                .folderWindowSizeHint:
                    "Gilt nur im Fenstermodus; der klassische Vollbildmodus nutzt eine feste Größe.",
                .versionPrefix: "v",
                .languageNameSystem: "Systemsprache",
                .languageNameEnglish: "Englisch",
                .languageNameChinese: "Chinesisch",
                .languageNameJapanese: "Japanisch",
                .languageNameKorean: "Koreanisch",
                .languageNameFrench: "Französisch",
                .languageNameSpanish: "Spanisch",
                .languageNameGerman: "Deutsch",
                .languageNameRussian: "Russisch",
                .languageNameHindi: "Hindi",
                .languageNameVietnamese: "Vietnamesisch",
                .folderNamePlaceholder: "Ordnername",
                .viewOnGitHub: "Projektlink öffnen",
                .chooseButton: "Auswählen",
                .exportPanelMessage:
                    "Wählen Sie einen Zielordner, um die LaunchOne-Daten zu exportieren",
                .importPrompt: "Importieren",
                .importPanelMessage:
                    "Wählen Sie einen zuvor aus LaunchOne exportierten Ordner",
                .legacyArchivePanelMessage:
                    "Wählen Sie ein Legacy-Launchpad-Archiv (.lmy/.zip) oder eine DB-Datei",
                .importSuccessfulTitle: "Import erfolgreich",
                .importFailedTitle: "Import fehlgeschlagen",
                .okButton: "OK",

                // Update-Überprüfung
                .checkForUpdates: "Nach Updates suchen",
                .checkForUpdatesButton: "Nach Updates suchen",
                .checkingForUpdates: "Suche nach Updates...",
                .upToDate: "Sie sind auf dem neuesten Stand",
                .updateAvailable: "Update verfügbar",
                .newVersion: "Neue Version:",
                .downloadUpdate: "Update herunterladen",
                .updateCheckFailed: "Update-Prüfung fehlgeschlagen",
                .tryAgain: "Erneut versuchen",
                .autoCheckForUpdates: "Automatisch nach Updates suchen",
                .versionParseError: "Versions-Parsing-Fehler",

                // Login item (silent)
                .startAtLoginTitle: "Beim Anmelden starten (still)",
                .startAtLoginToggle: "Aktivieren",
                .startAtLoginDescription: "Beim Anmelden ohne UI starten. Das Fenster kann später über den globalen Kurzbefehl geöffnet werden.",
                .loginItemPermissionHint: "Erlaube ‘LaunchOne’ im Hintergrund auszuführen: Systemeinstellungen → Anmeldeobjekte.",
            ],
            .russian: [
                .noAppsFound: "Приложения не найдены",
                .searchPlaceholder: "Поиск",
                .renameSearchPlaceholder: "Поиск приложений",
                .customTitlePlaceholder: "Введите своё название",
                .customTitleHint:
                    "Переименовывайте приложения здесь. Пользовательские названия сохраняются даже после повторного импорта или смены локализации.",
                .customTitleDefaultFormat: "По умолчанию: %@",
                .customTitleReset: "Сбросить название",
                .customTitleAddButton: "Добавить приложение",
                .customTitleEmptyTitle: "Пользовательских названий пока нет",
                .customTitleEmptySubtitle:
                    "Выберите приложение, чтобы начать переименование. Названия сохранятся после повторного импорта или смены языка.",
                .customTitleNoResults: "Совпадений нет",
                .customTitlePickerMessage:
                    "Выберите приложение, название которого хотите настроить.",
                .customTitleEdit: "Редактировать",
                .customTitleSave: "Сохранить",
                .customTitleCancel: "Отмена",
                .customTitleDelete: "Удалить",
                .loadingApplications: "Загрузка приложений…",
                .showFPSOverlay: "Показывать FPS",
                .showFPSOverlayDisclaimer:
                    "Показатель приблизительный и может отличаться от фактической частоты кадров.",
                .dockDisplayTitle: "Отображение в Dock",
                .dockDisplayToggle: "Показать значок в Dock",
                .dockDisplayDescription:
                    "Когда включено, значок приложения будет отображаться в Dock. Когда выключено, приложение будет работать полностью в фоновом режиме. Изменения применяются немедленно.",
                .customIconTitle: "Значок приложения",
                .customIconChoose: "Выбрать…",
                .customIconReset: "Вернуть стандартный значок",
                .customIconHint:
                    "Рекомендуется PNG/ICNS 512×512. Изменения применяются сразу.",
                .customIconError: "Не удалось загрузить выбранное изображение.",
                .pageIndicatorOffsetLabel: "Отступ индикатора страниц",
                .appTitle: "LaunchOne",
                .modifiedFrom: "Основано на LaunchNext версии 1.0.6",
                .backgroundHint:
                    "Чтобы работать в фоне, закрепите LaunchOne в Dock или откройте окно сочетанием клавиш",
                .classicMode: "Классический Launchpad (на весь экран)",
                .iconSize: "Размер значков",
                .iconsPerRow: "Иконок в строке",
                .rowsPerPage: "Строк на страницу",
                .iconHorizontalSpacing: "Горизонтальный промежуток",
                .iconVerticalSpacing: "Вертикальный промежуток",
                .labelFontSize: "Размер шрифта подписи",
                .iconLabelFontWeight: "Толщина шрифта подписи значка",
                .smaller: "Меньше",
                .larger: "Больше",
                .predictDrop: "Предсказывать позицию размещения",
                .showLabels: "Показывать подписи под значками",
                .useLocalizedThirdPartyTitles:
                    "Использовать локализованные названия",
                .enableAnimations: "Включить анимацию перелистывания",
                .hoverMagnification: "Увеличение при наведении",
                .hoverMagnificationScale: "Коэффициент увеличения",
                .activePressEffect: "Уменьшение при нажатии",
                .activePressScale: "Коэффициент нажатия",
                .animationDurationLabel: "Длительность анимации перелистывания",
                .gridSizeChangeWarning:
                    "Изменение размера сетки может изменить расположение некоторых значков.",
                .pageIndicatorHint:
                    "Если изменения едва заметны, настройте положение индикатора страниц ниже.",
                .rememberPageTitle: "Запоминать последнюю открытую страницу",
                .globalShortcutTitle: "Глобальное сочетание клавиш",
                .shortcutSetButton: "Назначить",
                .shortcutSaveButton: "Сохранить",
                .shortcutClearButton: "Очистить",
                .shortcutNotSet: "Не задано",
                .shortcutListening: "Ожидание…",
                .shortcutCapturePrompt:
                    "Нажмите нужное сочетание клавиш. Esc — отмена.",
                .shortcutNoModifierWarning:
                    "Без модификатора сочетание может конфликтовать с другими приложениями.",
                .scrollSensitivity: "Чувствительность прокрутки",
                .low: "Низкая",
                .high: "Высокая",
                .importSystem: "Импортировать системный Launchpad",
                .importLegacy: "Импортировать Legacy (.lmy)",
                .importTip:
                    "Подсказка: нажмите «Импортировать системный Launchpad», чтобы сразу загрузить текущее расположение.",
                .exportData: "Экспортировать данные",
                .importData: "Импортировать данные",
                .refresh: "Обновить",
                .showQuickRefreshButton:
                    "Показывать кнопку быстрого обновления",
                .resetLayout: "Сбросить раскладку",
                .resetAlertTitle: "Сбросить раскладку?",
                .resetAlertMessage:
                    "Раскладка будет полностью сброшена: папки удалятся, порядок очистится, приложения будут просканированы заново. Все настройки будут потеряны.",
                .resetConfirm: "Сбросить",
                .cancel: "Отмена",
                .quit: "Выйти",
                .menuAbout: "О программе LaunchOne",
                .menuSettings: "Настройки…",
                .menuQuit: "Выйти",
                .languagePickerTitle: "Язык",
                .appearanceModeTitle: "Оформление",
                .appearanceModeFollowSystem: "Как в системе",
                .appearanceModeLight: "Светлая",
                .appearanceModeDark: "Тёмная",
                .folderWindowWidth: "Ширина окна папки",
                .folderWindowHeight: "Высота окна папки",
                .folderWindowSizeHint:
                    "Работает только в оконном режиме; классический полноэкранный режим использует фиксированный размер.",
                .versionPrefix: "v",
                .languageNameSystem: "Следовать системе",
                .languageNameEnglish: "Английский",
                .languageNameChinese: "Китайский",
                .languageNameJapanese: "Японский",
                .languageNameKorean: "Корейский",
                .languageNameFrench: "Французский",
                .languageNameSpanish: "Испанский",
                .languageNameGerman: "Немецкий",
                .languageNameRussian: "Русский",
                .languageNameHindi: "Хинди",
                .languageNameVietnamese: "Вьетнамский",
                .folderNamePlaceholder: "Название папки",
                .viewOnGitHub: "Открыть ссылку проекта",
                .chooseButton: "Выбрать",
                .exportPanelMessage:
                    "Выберите папку назначения для экспорта данных LaunchOne",
                .importPrompt: "Импортировать",
                .importPanelMessage:
                    "Выберите папку, ранее экспортированную из LaunchOne",
                .legacyArchivePanelMessage:
                    "Выберите архив Legacy Launchpad (.lmy/.zip) или файл db",
                .importSuccessfulTitle: "Импорт завершён",
                .importFailedTitle: "Импорт не выполнен",
                .okButton: "OK",

                // Проверка обновлений
                .checkForUpdates: "Проверить обновления",
                .checkForUpdatesButton: "Проверить обновления",
                .checkingForUpdates: "Проверка обновлений...",
                .upToDate: "У вас последняя версия",
                .updateAvailable: "Доступно обновление",
                .newVersion: "Новая версия:",
                .downloadUpdate: "Скачать обновление",
                .updateCheckFailed: "Ошибка проверки обновлений",
                .tryAgain: "Попробовать снова",
                .autoCheckForUpdates: "Автоматически проверять обновления",
                .versionParseError: "Ошибка разбора версии",

                // Login item (silent)
                .startAtLoginTitle: "Запуск при входе (без UI)",
                .startAtLoginToggle: "Включить",
                .startAtLoginDescription: "Запускаться при входе в систему без интерфейса. Откройте окно по глобальному сочетанию.",
                .loginItemPermissionHint: "Разрешите ‘LaunchOne’ работу в фоне: Системные настройки → Объекты входа.",
            ],
        ]

        builder[.english]?.merge([
            .settingsSectionGeneral: "General",
            .settingsSectionAppearance: "Appearance",
            .settingsSectionHiddenApps: "Hidden apps",
            .settingsSectionTitles: "App titles",
            .settingsSectionPerformance: "Performance",
            .settingsSectionDevelopment: "Development",
            .settingsSectionAbout: "About",
            .developmentPlaceholderTitle: "Development playground",
            .developmentPlaceholderSubtitle:
                "Reserved for future tools and experimental features.",
            .backgroundStyleTitle: "Background style",
            .backgroundStyleOptionBlur: "Blur",
            .backgroundStyleOptionGlass: "Liquid glass",
            .hiddenAppsAddButton: "Hide application",
            .hiddenAppsEmptyTitle: "No hidden apps yet",
            .hiddenAppsEmptySubtitle:
                "Select an application to hide it from LaunchOne.",
            .hiddenAppsHint:
                "Hidden apps disappear from the grid. Remove them here to restore.",
            .hiddenAppsRemoveButton: "Unhide",
            .hiddenAppsSearchPlaceholder: "Filter hidden apps",
            .performancePlaceholderTitle: "Performance dashboard",
            .performancePlaceholderSubtitle:
                "Monitoring metrics will appear here soon.",
        ]) { _, new in new }

        builder[.simplifiedChinese]?.merge([
            .settingsSectionGeneral: "通用",
            .settingsSectionAppearance: "外观与行为",
            .settingsSectionHiddenApps: "隐藏应用",
            .settingsSectionTitles: "应用名称",
            .settingsSectionPerformance: "性能",
            .settingsSectionDevelopment: "开发",
            .settingsSectionAbout: "关于",
            .developmentPlaceholderTitle: "开发功能预留",
            .developmentPlaceholderSubtitle: "未来将用于调试工具或实验功能。",
            .backgroundStyleTitle: "背景样式",
            .backgroundStyleOptionBlur: "高斯模糊",
            .backgroundStyleOptionGlass: "液态玻璃",
            .hiddenAppsAddButton: "隐藏应用",
            .hiddenAppsEmptyTitle: "尚未隐藏任何应用",
            .hiddenAppsEmptySubtitle: "选择一个应用即可将其从 LaunchOne 网格中隐藏。",
            .hiddenAppsHint: "被隐藏的应用不会显示在网格中，可在此处取消隐藏。",
            .hiddenAppsRemoveButton: "取消隐藏",
            .hiddenAppsSearchPlaceholder: "搜索隐藏的应用",
            .performancePlaceholderTitle: "性能面板",
            .performancePlaceholderSubtitle: "性能指标将很快展示在此。",
        ]) { _, new in new }

        builder[.japanese]?.merge([
            .settingsSectionGeneral: "一般",
            .settingsSectionAppearance: "外観と動作",
            .settingsSectionHiddenApps: "非表示のアプリ",
            .settingsSectionTitles: "アプリ名",
            .settingsSectionPerformance: "パフォーマンス",
            .settingsSectionDevelopment: "開発",
            .settingsSectionAbout: "情報",
            .developmentPlaceholderTitle: "開発者プレイグラウンド",
            .developmentPlaceholderSubtitle: "将来的なツールや実験機能のためのスペースです。",
            .backgroundStyleTitle: "背景スタイル",
            .backgroundStyleOptionBlur: "ぼかし",
            .backgroundStyleOptionGlass: "リキッドガラス",
            .hiddenAppsAddButton: "アプリを非表示にする",
            .hiddenAppsEmptyTitle: "非表示のアプリはありません",
            .hiddenAppsEmptySubtitle: "ここでアプリを選ぶと LaunchOne から隠せます。",
            .hiddenAppsHint: "非表示にしたアプリはグリッドから消えます。再表示する場合はここで解除してください。",
            .hiddenAppsRemoveButton: "再表示",
            .hiddenAppsSearchPlaceholder: "非表示のアプリを検索",
            .performancePlaceholderTitle: "パフォーマンスダッシュボード",
            .performancePlaceholderSubtitle: "ここに指標が表示されます。",
        ]) { _, new in new }

        builder[.korean]?.merge([
            .settingsSectionGeneral: "일반",
            .settingsSectionAppearance: "모양과 동작",
            .settingsSectionHiddenApps: "숨김 앱",
            .settingsSectionTitles: "앱 이름",
            .settingsSectionPerformance: "성능",
            .settingsSectionDevelopment: "개발",
            .settingsSectionAbout: "정보",
            .developmentPlaceholderTitle: "개발자 플레이그라운드",
            .developmentPlaceholderSubtitle: "향후 도구와 실험 기능을 위한 공간입니다.",
            .backgroundStyleTitle: "배경 스타일",
            .backgroundStyleOptionBlur: "블러",
            .backgroundStyleOptionGlass: "액체 유리",
            .hiddenAppsAddButton: "앱 숨기기",
            .hiddenAppsEmptyTitle: "숨겨진 앱이 없습니다",
            .hiddenAppsEmptySubtitle:
                "이곳에서 앱을 선택하면 LaunchOne 그리드에서 숨길 수 있습니다.",
            .hiddenAppsHint: "숨긴 앱은 그리드에서 사라집니다. 여기에서 다시 표시할 수 있습니다.",
            .hiddenAppsRemoveButton: "다시 표시",
            .hiddenAppsSearchPlaceholder: "숨김 앱 검색",
            .performancePlaceholderTitle: "성능 대시보드",
            .performancePlaceholderSubtitle: "곧 이곳에서 지표를 확인할 수 있습니다.",
        ]) { _, new in new }

        builder[.vietnamese]?.merge([
            .settingsSectionGeneral: "Chung",
            .settingsSectionAppearance: "Giao diện & hành vi",
            .settingsSectionHiddenApps: "Ứng dụng ẩn",
            .settingsSectionTitles: "Tên ứng dụng",
            .settingsSectionPerformance: "Hiệu năng",
            .settingsSectionDevelopment: "Phát triển",
            .settingsSectionAbout: "Giới thiệu",
            .developmentPlaceholderTitle: "Khu vực dành cho nhà phát triển",
            .developmentPlaceholderSubtitle:
                "Không gian cho các công cụ và tính năng thử nghiệm trong tương lai.",
            .backgroundStyleTitle: "Kiểu nền",
            .backgroundStyleOptionBlur: "Làm mờ",
            .backgroundStyleOptionGlass: "Kính lỏng",
            .hiddenAppsAddButton: "Ẩn ứng dụng",
            .hiddenAppsEmptyTitle: "Chưa có ứng dụng nào bị ẩn",
            .hiddenAppsEmptySubtitle:
                "Chọn một ứng dụng để ẩn khỏi lưới LaunchOne.",
            .hiddenAppsHint:
                "Ứng dụng bị ẩn sẽ biến mất khỏi lưới. Huỷ ẩn tại đây để khôi phục.",
            .hiddenAppsRemoveButton: "Huỷ ẩn",
            .hiddenAppsSearchPlaceholder: "Tìm ứng dụng bị ẩn",
            .performancePlaceholderTitle: "Bảng điều khiển hiệu năng",
            .performancePlaceholderSubtitle:
                "Các chỉ số sẽ sớm xuất hiện tại đây.",
        ]) { _, new in new }

        builder[.french]?.merge([
            .settingsSectionGeneral: "Général",
            .settingsSectionAppearance: "Apparence",
            .settingsSectionHiddenApps: "Applications masquées",
            .settingsSectionTitles: "Noms des applications",
            .settingsSectionPerformance: "Performances",
            .settingsSectionDevelopment: "Développement",
            .settingsSectionAbout: "À propos",
            .developmentPlaceholderTitle: "Espace développeur",
            .developmentPlaceholderSubtitle:
                "Réservé aux outils et fonctionnalités expérimentales à venir.",
            .backgroundStyleTitle: "Style de l'arrière-plan",
            .backgroundStyleOptionBlur: "Flou",
            .backgroundStyleOptionGlass: "Liquid Glass",
            .hiddenAppsAddButton: "Masquer une application",
            .hiddenAppsEmptyTitle: "Aucune application masquée",
            .hiddenAppsEmptySubtitle:
                "Choisissez une application pour la masquer dans LaunchOne.",
            .hiddenAppsHint:
                "Les applications masquées n'apparaissent plus dans la grille. Vous pouvez les rétablir ici.",
            .hiddenAppsRemoveButton: "Afficher",
            .hiddenAppsSearchPlaceholder:
                "Rechercher des applications masquées",
            .performancePlaceholderTitle: "Tableau de bord des performances",
            .performancePlaceholderSubtitle:
                "Les indicateurs apparaîtront ici prochainement.",
        ]) { _, new in new }

        builder[.spanish]?.merge([
            .settingsSectionGeneral: "General",
            .settingsSectionAppearance: "Apariencia y comportamiento",
            .settingsSectionHiddenApps: "Apps ocultas",
            .settingsSectionTitles: "Nombres de apps",
            .settingsSectionPerformance: "Rendimiento",
            .settingsSectionDevelopment: "Desarrollo",
            .settingsSectionAbout: "Acerca de",
            .developmentPlaceholderTitle: "Zona de desarrollo",
            .developmentPlaceholderSubtitle:
                "Reservado para futuras herramientas y funciones experimentales.",
            .backgroundStyleTitle: "Estilo de fondo",
            .backgroundStyleOptionBlur: "Desenfoque",
            .backgroundStyleOptionGlass: "Vidrio líquido",
            .hiddenAppsAddButton: "Ocultar app",
            .hiddenAppsEmptyTitle: "Todavía no hay apps ocultas",
            .hiddenAppsEmptySubtitle:
                "Elige una aplicación para ocultarla en LaunchOne.",
            .hiddenAppsHint:
                "Las apps ocultas desaparecen de la cuadrícula. Restáuralas desde aquí.",
            .hiddenAppsRemoveButton: "Mostrar",
            .hiddenAppsSearchPlaceholder: "Buscar apps ocultas",
            .performancePlaceholderTitle: "Panel de rendimiento",
            .performancePlaceholderSubtitle:
                "Muy pronto podrás ver métricas aquí.",
        ]) { _, new in new }

        builder[.german]?.merge([
            .settingsSectionGeneral: "Allgemein",
            .settingsSectionAppearance: "Darstellung & Verhalten",
            .settingsSectionHiddenApps: "Ausgeblendete Apps",
            .settingsSectionTitles: "App-Namen",
            .settingsSectionPerformance: "Performance",
            .settingsSectionDevelopment: "Entwicklung",
            .settingsSectionAbout: "Info",
            .developmentPlaceholderTitle: "Entwicklerbereich",
            .developmentPlaceholderSubtitle:
                "Reserviert für zukünftige Tools und experimentelle Features.",
            .backgroundStyleTitle: "Hintergrundstil",
            .backgroundStyleOptionBlur: "Unschärfe",
            .backgroundStyleOptionGlass: "Liquid Glass",
            .hiddenAppsAddButton: "App ausblenden",
            .hiddenAppsEmptyTitle: "Noch keine Apps ausgeblendet",
            .hiddenAppsEmptySubtitle:
                "Wähle eine App, um sie in LaunchOne auszublenden.",
            .hiddenAppsHint:
                "Ausgeblendete Apps verschwinden aus dem Raster. Hier kannst du sie wieder einblenden.",
            .hiddenAppsRemoveButton: "Einblenden",
            .hiddenAppsSearchPlaceholder: "Ausgeblendete Apps suchen",
            .performancePlaceholderTitle: "Performance-Dashboard",
            .performancePlaceholderSubtitle: "Kennzahlen folgen in Kürze.",
        ]) { _, new in new }

        builder[.russian]?.merge([
            .settingsSectionGeneral: "Общие",
            .settingsSectionAppearance: "Внешний вид и поведение",
            .settingsSectionHiddenApps: "Скрытые приложения",
            .settingsSectionTitles: "Названия приложений",
            .settingsSectionPerformance: "Производительность",
            .settingsSectionDevelopment: "Разработка",
            .settingsSectionAbout: "О приложении",
            .developmentPlaceholderTitle: "Площадка для разработчиков",
            .developmentPlaceholderSubtitle:
                "Здесь появятся инструменты и экспериментальные возможности.",
            .backgroundStyleTitle: "Стиль фона",
            .backgroundStyleOptionBlur: "Размытие",
            .backgroundStyleOptionGlass: "Жидкое стекло",
            .hiddenAppsAddButton: "Скрыть приложение",
            .hiddenAppsEmptyTitle: "Скрытых приложений нет",
            .hiddenAppsEmptySubtitle:
                "Выберите приложение, чтобы скрыть его из LaunchOne.",
            .hiddenAppsHint:
                "Скрытые приложения не отображаются в сетке. Здесь можно вернуть их обратно.",
            .hiddenAppsRemoveButton: "Показать",
            .hiddenAppsSearchPlaceholder: "Поиск среди скрытых приложений",
            .performancePlaceholderTitle: "Панель производительности",
            .performancePlaceholderSubtitle:
                "Скоро здесь появятся показатели эффективности.",
        ]) { _, new in new }

        var hindiDictionary = builder[.english] ?? [:]
        hindiDictionary[.languagePickerTitle] = "भाषा"
        hindiDictionary[.languageNameSystem] = "सिस्टम का अनुसरण करें"
        hindiDictionary[.languageNameEnglish] = "English"
        hindiDictionary[.languageNameChinese] = "中文"
        hindiDictionary[.languageNameJapanese] = "日本語"
        hindiDictionary[.languageNameKorean] = "한국어"
        hindiDictionary[.languageNameFrench] = "Français"
        hindiDictionary[.languageNameSpanish] = "Español"
        hindiDictionary[.languageNameGerman] = "Deutsch"
        hindiDictionary[.languageNameRussian] = "Русский"
        hindiDictionary[.languageNameHindi] = "हिन्दी"
        hindiDictionary[.languageNameVietnamese] = "वियतनामी"

        hindiDictionary.merge([
            .noAppsFound: "कोई ऐप नहीं मिला",
            .searchPlaceholder: "खोजें",
            .renameSearchPlaceholder: "ऐप खोजें",
            .customTitlePlaceholder: "कस्टम नाम दर्ज करें",
            .customTitleHint:
                "यहाँ ऐप का नाम बदलें; कस्टम नाम आयात या भाषा बदलने पर भी बने रहेंगे।",
            .customTitleDefaultFormat: "डिफ़ॉल्ट: %@",
            .customTitleReset: "डिफ़ॉल्ट बहाल करें",
            .customTitleAddButton: "ऐप जोड़ें",
            .customTitleEmptyTitle: "अभी कोई कस्टम नाम नहीं",
            .customTitleEmptySubtitle:
                "ऐप चुनें और नया नाम दें; आयात या भाषा बदलने पर भी ये सुरक्षित रहेंगे।",
            .customTitleNoResults: "कोई मेल नहीं मिला",
            .customTitlePickerMessage: "जिस ऐप का नाम बदलना चाहते हैं उसे चुनें।",
            .customTitleEdit: "संपादित करें",
            .customTitleSave: "सहेजें",
            .customTitleCancel: "रद्द करें",
            .customTitleDelete: "हटाएँ",
            .loadingApplications: "ऐप लोड हो रहे हैं…",
            .showFPSOverlay: "FPS दिखाएँ",
            .showFPSOverlayDisclaimer: "अनुमानित मान; वास्तविक फ्रेम दर से भिन्न हो सकता है।",
            .dockDisplayTitle: "Dock प्रदर्शन",
            .dockDisplayToggle: "Dock में आइकन दिखाएं",
            .dockDisplayDescription:
                "जब सक्षम हो, ऐप आइकन Dock में दिखाई देगा। जब अक्षम हो, ऐप पूरी तरह से पृष्ठभूमि में चलेगा। परिवर्तन तुरंत लागू होते हैं।",
            .customIconTitle: "ऐप आइकन",
            .customIconChoose: "चुनें…",
            .customIconReset: "डिफ़ॉल्ट आइकन बहाल करें",
            .customIconHint: "512×512 PNG/ICNS फ़ाइल सर्वोत्तम है। बदलाव तुरंत लागू होंगे।",
            .customIconError: "चयनित चित्र लोड नहीं हो सका।",
            .pageIndicatorOffsetLabel: "पेज संकेतक अंतर",
            .appTitle: "LaunchOne",
            .modifiedFrom: "LaunchNext संस्करण 1.0.6 के आधार पर संशोधित",
            .backgroundHint:
                "पृष्ठभूमि में चलाने के लिए LaunchOne को Dock में रखें या शॉर्टकट से विंडो खोलें",
            .classicMode: "क्लासिक Launchpad (पूर्ण स्क्रीन)",
            .iconSize: "आइकन आकार",
            .iconsPerRow: "प्रति पंक्ति आइकन",
            .rowsPerPage: "प्रति पृष्ठ पंक्तियाँ",
            .iconHorizontalSpacing: "क्षैतिज दूरी",
            .iconVerticalSpacing: "ऊर्ध्वाधर दूरी",
            .labelFontSize: "लेबल फ़ॉन्ट आकार",
            .iconLabelFontWeight: "आइकन लेबल मोटाई",
            .smaller: "छोटा",
            .larger: "बड़ा",
            .predictDrop: "ड्रॉप स्थान का अनुमान",
            .showLabels: "आइकन के नीचे नाम दिखाएँ",
            .useLocalizedThirdPartyTitles: "लोकलाइज़्ड ऐप नाम उपयोग करें",
            .enableAnimations: "स्लाइड एनीमेशन सक्षम करें",
            .hoverMagnification: "हॉवर बढ़ोतरी",
            .hoverMagnificationScale: "हॉवर स्केल",
            .activePressEffect: "दबाने पर प्रभाव",
            .activePressScale: "दबाव स्केल",
            .animationDurationLabel: "स्लाइड एनीमेशन अवधि",
            .gridSizeChangeWarning: "ग्रिड आकार बदलने पर कुछ आइकन स्थान बदल सकते हैं।",
            .pageIndicatorHint: "यदि बदलाव कम लगे तो पेज संकेतक का अंतर समायोजित करें।",
            .rememberPageTitle: "अंतिम खुला पृष्ठ याद रखें",
            .globalShortcutTitle: "वैश्विक शॉर्टकट",
            .shortcutSetButton: "शॉर्टकट सेट करें",
            .shortcutSaveButton: "सहेजें",
            .shortcutClearButton: "साफ़ करें",
            .shortcutNotSet: "सेट नहीं",
            .shortcutListening: "कुंजी प्रतीक्षा…",
            .shortcutCapturePrompt: "वांछित संयोजन दबाएँ। Esc से रद्द करें।",
            .shortcutNoModifierWarning: "बिना मॉडिफ़ायर अन्य ऐप्स से टकराव हो सकता है।",
            .scrollSensitivity: "स्क्रॉल संवेदनशीलता",
            .low: "कम",
            .high: "उच्च",
            .importSystem: "सिस्टम Launchpad आयात करें",
            .importLegacy: "Legacy (.lmy) आयात करें",
            .importTip: "सुझाव: “सिस्टम Launchpad आयात करें” पर क्लिक कर वर्तमान लेआउट लाएँ।",
            .exportData: "डेटा निर्यात करें",
            .importData: "डेटा आयात करें",
            .refresh: "रिफ़्रेश",
            .showQuickRefreshButton: "क्विक रिफ़्रेश बटन दिखाएँ",
            .resetLayout: "लेआउट रीसेट करें",
            .resetAlertTitle: "क्या लेआउट रीसेट करें?",
            .resetAlertMessage:
                "यह सभी फ़ोल्डर हटाकर क्रम साफ़ करेगा और ऐप्स को पुनः स्कैन करेगा। सभी कस्टम बदलाव हटेंगे।",
            .resetConfirm: "रीसेट",
            .cancel: "रद्द करें",
            .quit: "बंद करें",
            .menuAbout: "LaunchOne के बारे में",
            .menuSettings: "सेटिंग्स…",
            .menuQuit: "बंद करें",
            .appearanceModeTitle: "रूप मोड",
            .appearanceModeFollowSystem: "सिस्टम के अनुसार",
            .appearanceModeLight: "हल्का",
            .appearanceModeDark: "गहरा",
            .folderWindowWidth: "फ़ोल्डर विंडो चौड़ाई",
            .folderWindowHeight: "फ़ोल्डर विंडो ऊँचाई",
            .folderWindowSizeHint: "केवल विंडो मोड में प्रभावी; क्लासिक फुलस्क्रीन में आकार तय रहता है।",
            .versionPrefix: "v",
            .folderNamePlaceholder: "फ़ोल्डर का नाम",
            .viewOnGitHub: "प्रोजेक्ट लिंक खोलें",
            .chooseButton: "चुनें",
            .exportPanelMessage: "LaunchOne डेटा निर्यात करने के लिए फ़ोल्डर चुनें",
            .importPrompt: "आयात करें",
            .importPanelMessage: "वह फ़ोल्डर चुनें जिसे LaunchOne से निर्यात किया गया था",
            .legacyArchivePanelMessage:
                "Legacy Launchpad आर्काइव (.lmy/.zip) या db फ़ाइल चुनें",
            .importSuccessfulTitle: "आयात सफल",
            .importFailedTitle: "आयात विफल",
            .okButton: "ठीक",
            .checkForUpdates: "अपडेट जाँचें",
            .checkForUpdatesButton: "अपडेट जाँचें",
            .checkingForUpdates: "अपडेट की जाँच हो रही है…",
            .upToDate: "आप नवीनतम संस्करण पर हैं",
            .updateAvailable: "नया अपडेट उपलब्ध",
            .newVersion: "नया संस्करण:",
            .downloadUpdate: "अपडेट डाउनलोड करें",
            .updateCheckFailed: "अपडेट जाँच विफल",
            .tryAgain: "पुनः प्रयास",
            .autoCheckForUpdates: "स्वचालित रूप से अपडेट जाँचें",
            .versionParseError: "संस्करण पार्स त्रुटि",
            .settingsSectionGeneral: "सामान्य",
            .settingsSectionAppearance: "रूप व व्यवहार",
            .settingsSectionHiddenApps: "छिपे हुए ऐप्स",
            .settingsSectionTitles: "ऐप नाम",
            .settingsSectionPerformance: "प्रदर्शन",
            .settingsSectionDevelopment: "विकास",
            .settingsSectionAbout: "परिचय",
            .developmentPlaceholderTitle: "डेवलपर प्लेग्राउंड",
            .developmentPlaceholderSubtitle:
                "आने वाले टूल और प्रयोगात्मक सुविधाओं के लिए आरक्षित।",
            .backgroundStyleTitle: "पृष्ठभूमि शैली",
            .backgroundStyleOptionBlur: "धुंधला",
            .backgroundStyleOptionGlass: "लिक्विड ग्लास",
            .hiddenAppsAddButton: "ऐप छिपाएँ",
            .hiddenAppsEmptyTitle: "अभी कोई ऐप छिपा नहीं है",
            .hiddenAppsEmptySubtitle: "LaunchOne से हटाने के लिए किसी ऐप का चयन करें।",
            .hiddenAppsHint:
                "छिपाए गए ऐप्स ग्रिड से गायब हो जाते हैं। उन्हें वापस लाने के लिए यहाँ से हटाएँ।",
            .hiddenAppsRemoveButton: "वापस दिखाएँ",
            .hiddenAppsSearchPlaceholder: "छिपे हुए ऐप खोजें",
            .performancePlaceholderTitle: "प्रदर्शन डैशबोर्ड",
            .performancePlaceholderSubtitle: "जल्द ही मेट्रिक्स यहाँ दिखेंगे।",
        ]) { _, new in new }

        builder[.hindi] = hindiDictionary

        translations = builder
    }

    func localized(_ key: LocalizationKey, language: AppLanguage) -> String {
        let lang =
            language == .system ? AppLanguage.resolveSystemDefault() : language
        if let value = translations[lang]?[key] {
            return value
        }
        return translations[.english]?[key] ?? key.rawValue
    }

    func languageDisplayName(
        for language: AppLanguage,
        displayLanguage: AppLanguage
    ) -> String {
        let resolvedDisplay =
            displayLanguage == .system
            ? AppLanguage.resolveSystemDefault() : displayLanguage
        switch language {
        case .system:
            return localized(.languageNameSystem, language: resolvedDisplay)
        case .english:
            return "English"
        case .simplifiedChinese:
            return "中文"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        case .vietnamese:
            return "Tiếng Việt"
        case .french:
            return "Français"
        case .spanish:
            return "Español"
        case .german:
            return "Deutsch"
        case .russian:
            return "Русский"
        case .hindi:
            return "हिन्दी"
        }
    }
}
