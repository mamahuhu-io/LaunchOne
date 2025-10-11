# LaunchOne

**Ngôn ngữ**: [English](../../README.md) | [中文](../../README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [Tiếng Việt](README.vi.md)

## 📥 Tải xuống

**[Tải tại đây](https://github.com/mamahuhu-io/LaunchOne/releases/latest)** - Nhận phiên bản mới nhất

⭐ Hãy cân nhắc gắn sao cho [LaunchOne](https://github.com/mamahuhu-io/LaunchOne) và đặc biệt là dự án gốc [LaunchNext](https://github.com/RoversX/LaunchNext)!

| | |
|:---:|:---:|
| ![](../assets/main.webp) | ![](../assets/setting-general.webp) |
| ![](../assets/setting-appearance.webp) | ![](../assets/setting-apptitle.webp) |

macOS Tahoe đã loại bỏ Launchpad, giao diện mới khó sử dụng và không tận dụng hết Bio GPU của bạn. Apple nên cung cấp tùy chọn quay lại. Trong khi chờ đợi, đây là LaunchOne.

*Dựa trên [LaunchNext](https://github.com/RoversX/LaunchNext) của RoversX — xin cảm ơn dự án gốc!*

*LaunchNext chọn giấy phép GPL 3, LaunchOne tuân theo cùng điều khoản.*

### LaunchOne mang lại
- ✅ **Nhập Launchpad cũ chỉ với một cú nhấp** — đọc trực tiếp cơ sở dữ liệu SQLite Launchpad gốc (`/private$(getconf DARWIN_USER_DIR)com.apple.dock.launchpad/db/db`) để tái tạo hoàn hảo thư mục, vị trí ứng dụng và bố cục hiện có
- ✅ **Trải nghiệm Launchpad cổ điển** — hoạt động giống hệt giao diện nguyên bản quen thuộc
- ✅ **Hỗ trợ đa ngôn ngữ** — quốc tế hóa đầy đủ với tiếng Anh, Trung, Nhật, Pháp và Tây Ban Nha
- ✅ **Ẩn nhãn biểu tượng** — giao diện tối giản khi không cần tên ứng dụng
- ✅ **Kích thước biểu tượng tùy chỉnh** — điều chỉnh theo sở thích
- ✅ **Quản lý thư mục thông minh** — tạo và sắp xếp thư mục như trước đây
- ✅ **Tìm kiếm tức thì và điều hướng bằng bàn phím** — tìm ứng dụng nhanh

### Những gì đã mất trong macOS Tahoe
- ❌ Không thể tổ chức ứng dụng tùy chỉnh
- ❌ Không có thư mục do người dùng tạo
- ❌ Không tùy chỉnh kéo thả
- ❌ Không quản lý ứng dụng trực quan
- ❌ Ép nhóm theo danh mục

## Tính năng

### 🎯 **Khởi chạy ứng dụng tức thì**
- Nhấp đúp để khởi chạy trực tiếp
- Hỗ trợ điều hướng bằng bàn phím đầy đủ
- Tìm kiếm siêu nhanh với lọc theo thời gian thực

### 📁 **Hệ thống thư mục nâng cao**
- Tạo thư mục bằng cách kéo thả ứng dụng chồng lên nhau
- Đổi tên thư mục bằng chỉnh sửa trực tiếp
- Tùy chỉnh biểu tượng thư mục và sắp xếp
- Kéo thả ứng dụng liền mạch vào/ra

### 🔍 **Tìm kiếm thông minh**
- Khớp mờ theo thời gian thực
- Tìm trong tất cả ứng dụng đã cài đặt
- Phím tắt truy cập nhanh

### 🎨 **Thiết kế giao diện hiện đại**
- **Hiệu ứng kính lỏng**: regularMaterial với đổ bóng tinh tế
- Chế độ toàn màn hình và cửa sổ
- Hiệu ứng chuyển động mượt mà
- Bố cục gọn gàng, phản hồi tốt

### 🔄 **Di chuyển dữ liệu liền mạch**
- **Nhập Launchpad một cú nhấp** từ cơ sở dữ liệu gốc macOS
- Tự động phát hiện và quét ứng dụng
- Lưu trữ bố cục bền vững với SwiftData
- Không mất dữ liệu trong quá trình cập nhật hệ thống

### ⚙️ **Tích hợp hệ thống**
- Ứng dụng macOS gốc
- Định vị thông minh trên nhiều màn hình
- Hoạt động với Dock và ứng dụng hệ thống khác
- Phát hiện click nền (đóng thông minh)

## Kiến trúc kỹ thuật

### Xây dựng bằng công nghệ hiện đại
- **SwiftUI**: Framework UI khai báo, hiệu năng cao
- **SwiftData**: Lớp lưu trữ dữ liệu mạnh mẽ
- **AppKit**: Tích hợp sâu với macOS
- **SQLite3**: Đọc trực tiếp DB Launchpad

### Lưu trữ dữ liệu
Dữ liệu ứng dụng được lưu an toàn tại:
```
~/Library/Application Support/LaunchOne/Data.store
```

### Tích hợp Launchpad gốc
Đọc trực tiếp từ cơ sở dữ liệu hệ thống Launchpad:
```bash
/private$(getconf DARWIN_USER_DIR)com.apple.dock.launchpad/db/db
```

## Cài đặt

### Yêu cầu hệ thống
- macOS 26 (Tahoe) trở lên
- Apple Silicon hoặc Intel
- Xcode 26 (để build từ mã nguồn)

### Build từ mã nguồn

1. **Clone repo**
   ```bash
   clone git@github.com:mamahuhu-io/LaunchOne.git
   cd LaunchOne
   ```

2. **Mở bằng Xcode**
   ```bash
   open LaunchOne.xcodeproj
   ```

3. **Build & Run**
   - Chọn thiết bị đích
   - Nhấn `⌘+R` để build và chạy
   - Hoặc `⌘+B` để chỉ build

### Build qua dòng lệnh
```bash
xcodebuild -project LaunchOne.xcodeproj -scheme LaunchOne -configuration Release
```

## Sử dụng

### Bắt đầu nhanh
1. **Lần chạy đầu**: LaunchOne tự động quét tất cả ứng dụng đã cài
2. **Chọn**: Bấm để chọn, nhấp đúp để chạy
3. **Tìm kiếm**: Gõ để lọc ngay lập tức
4. **Sắp xếp**: Kéo thả ứng dụng để tạo thư mục/bố cục

### Nhập Launchpad
1. Mở Cài đặt (biểu tượng bánh răng)
2. Nhấp **"Import Launchpad"**
3. Bố cục và thư mục hiện tại của bạn sẽ được nhập tự động

### Quản lý thư mục
- **Tạo thư mục**: Kéo một ứng dụng lên ứng dụng khác
- **Đổi tên thư mục**: Bấm vào tên
- **Thêm ứng dụng**: Kéo ứng dụng vào thư mục
- **Xóa ứng dụng**: Kéo ứng dụng ra khỏi thư mục

### Chế độ hiển thị
- **Cửa sổ**: Cửa sổ nổi bo góc
- **Toàn màn hình**: Hiển thị tối đa
- Chuyển đổi trong Cài đặt

## Vấn đề đã biết

> **Trạng thái phát triển hiện tại**
> - 🔄 **Hành vi cuộn**: Có thể không ổn định trong một số trường hợp, đặc biệt khi thao tác nhanh
> - 🎯 **Tạo thư mục**: Phát hiện thả có lúc chưa ổn định
> - 🛠️ **Đang phát triển tích cực**: Sẽ được cải thiện trong các bản phát hành tới

## Khắc phục sự cố

### Câu hỏi thường gặp

**H: Ứng dụng không khởi động?**
Đ: Đảm bảo macOS 26+ và kiểm tra quyền hệ thống.

**H: Thiếu nút nhập?**
Đ: Kiểm tra SettingsView.swift có tính năng nhập hay không.

**H: Tìm kiếm không hoạt động?**
Đ: Thử quét lại ứng dụng hoặc đặt lại dữ liệu trong Cài đặt.

**H: Vấn đề hiệu năng?**
Đ: Kiểm tra thiết lập bộ nhớ đệm biểu tượng và khởi động lại ứng dụng.

## Tại sao chọn LaunchOne?

### So với giao diện "Applications" của Apple
| Tính năng | Applications (Tahoe) | LaunchOne |
|---------|---------------------|------------|
| Tổ chức tùy chỉnh | ❌ | ✅ |
| Thư mục người dùng | ❌ | ✅ |
| Kéo thả | ❌ | ✅ |
| Quản lý trực quan | ❌ | ✅ |
| Nhập dữ liệu hiện có | ❌ | ✅ |
| Hiệu năng | Chậm | Nhanh |

### So với các lựa chọn thay thế Launchpad khác
- **Tích hợp gốc**: Đọc trực tiếp DB Launchpad
- **Kiến trúc hiện đại**: SwiftUI/SwiftData
- **Không phụ thuộc**: Swift thuần, không thư viện ngoài
- **Phát triển tích cực**: Cập nhật thường xuyên
- **Thiết kế kính lỏng**: Hiệu ứng thị giác cao cấp

## Đóng góp

Chúng tôi hoan nghênh đóng góp! Vui lòng:

1. Fork repo
2. Tạo nhánh tính năng (`git checkout -b feature/amazing-feature`)
3. Commit thay đổi (`git commit -m 'Add amazing feature'`)
4. Push nhánh (`git push origin feature/amazing-feature`)
5. Mở Pull Request

### Hướng dẫn phát triển
- Tuân theo quy ước kiểu Swift
- Thêm chú thích ý nghĩa cho logic phức tạp
- Kiểm tra trên nhiều phiên bản macOS
- Duy trì tương thích ngược

## Tương lai của quản lý ứng dụng

Khi Apple dần rời xa giao diện tùy biến, LaunchOne đại diện cho cam kết của cộng đồng đối với quyền kiểm soát và cá nhân hóa của người dùng. Chúng tôi tin rằng người dùng nên quyết định cách tổ chức không gian làm việc số của họ.

**LaunchOne** không chỉ là thay thế Launchpad — đó là tuyên bố rằng sự lựa chọn của người dùng là quan trọng.


---

**LaunchOne** — Giành lại quyền kiểm soát trình khởi chạy ứng dụng của bạn 🚀

*Xây dựng cho người dùng macOS không chấp nhận thỏa hiệp về cá nhân hóa.*

## Công cụ phát triển

Dự án này được phát triển với sự hỗ trợ của:
- Claude Code - Trợ lý phát triển dùng AI
- Cursor
- Cursor Cli - Sinh và tối ưu mã