# apple/

App SwiftUI cho macOS 26 + iOS 26. Cần **Xcode 26** trên Mac.

## Lần đầu

```bash
brew install xcodegen
cd apple
xcodegen                 # sinh Tiramissu.xcodeproj từ project.yml
open Tiramissu.xcodeproj
```

Trong Xcode: chọn target `Tiramissu-macOS` → Signing & Capabilities → Team = Apple ID cá nhân
(miễn phí). Chạy ⌘R. iPhone: chọn `Tiramissu-iOS` + thiết bị thật; bản ký miễn phí hết hạn sau 7 ngày,
cài lại bằng ⌘R.

Sau khi đổi `project.yml` hoặc thêm/xoá file trong `App/`: chạy lại `xcodegen`.

## Test logic

```bash
cd Packages/HanCore && swift test
cd Packages/DesignSystem && swift test
```

Chạy được trên Linux có Swift 6.2 (phần SwiftUI của DesignSystem bọc `#if canImport(SwiftUI)`).
