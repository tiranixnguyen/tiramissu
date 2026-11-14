# Prototype giao diện (bản offline trong repo)

Bản xem tương tác (cần đăng nhập claude.ai, chỉ chủ repo mở được):
https://claude.ai/artifact/VoCymBbC7z1bQRoSRwkvVq

Agent (Zed, Sonnet…) **không mở được link trên** → dùng thư mục này. Ảnh chụp là nguồn sự thật về
**bố cục**; mã nguồn để đọc khoảng cách, cỡ chữ, bo góc, nội dung chữ. Màu lấy từ
`apple/Packages/DesignSystem/Sources/DesignSystem/Resources/Themes/*.json` (cùng giá trị với `this.TH`
trong file nguồn). Lớp CSS `.glass` / `.tglass` chỉ mô phỏng `.glassEffect()` / `.glassProminent`.

## Màn → ảnh → nguồn → SwiftUI

| Màn | Ảnh (`screens/`) | Nguồn (`src/`) | Task |
|---|---|---|---|
| Design system (token, component) | `Main-light.png` | `Main.dc.html` | T2.20–T2.22 |
| Mac · Hôm nay | `Mac-Today-{light,dark}.png` | `Mac-Today.dc.html` | T2.37 |
| Mac · Hôm nay — cửa sổ 1000 / 820 pt | `Mac-Today-{1000,820}-{light,dark}.png`, `Mac-Today-820-sidebar-light.png` | `Mac-Today-{1000,820}.dc.html` | T2.37 |
| Mac · Học (+ ⌘K) | `Mac-Study-{light,dark}.png` | `Mac-Study.dc.html` | T2.32–T2.36, T2.41 |
| Mac · Học — cửa sổ 1000 / 820 pt | `Mac-Study-{1000,820}-{light,dark}.png`, `Mac-Study-820-sidebar-light.png` | `Mac-Study-{1000,820}.dc.html` | T2.32, T2.34 |
| Mac · Thư viện | `Mac-Library-{light,dark}.png` | `Mac-Library.dc.html` | T2.38 |
| Mac · Nhập từ AI | `Mac-Import-{light,dark}.png` | `Mac-Import.dc.html` | T2.39 |
| Mac · Cắt clip âm thanh | `Mac-Audio-{light,dark}.png` | `Mac-Audio.dc.html` | T3.01–T3.04 |
| iPhone · Hôm nay / Học / Nghe | `Phone-{Today,Study,Listen}-light.png` | `Phone-*.dc.html` | G4 |
| 6 theme × sáng/tối (màn Học) | `screens/themes/Mac-Study-<theme>-<mode>.png` | — | T2.21 |

Ảnh Mac 1280×800 pt (bản hẹp 1000×700 và 820×640; chụp @2x), iPhone 390×844 pt (@2x), ảnh theme @1x.

## Đọc file nguồn `.dc.html`

- Phần `<x-dc>`: HTML + style inline; `{{tên}}` là giá trị tính trong `renderVals()` ở `<script>` cuối file.
- `<sc-for list="{{x}}" as="i">` = vòng lặp (`ForEach`), `<sc-if>` = điều kiện.
- `this.state` = trạng thái mẫu; `this.TH` = bảng màu 6 theme.
- Chỉ để đọc — không sửa tay. Thay đổi giao diện: sửa trên claude.ai rồi chạy lại bước xuất dưới.

## Cập nhật khi prototype đổi (👤 / phiên có quyền claude.ai)

Tải `project/*.dc.html` + `canvas.json` của artifact vào `src/`, dùng `artifact-type/dc-runtime.js` làm
`support.js`, phục vụ thư mục bằng server tĩnh và chụp bằng Playwright (viewport theo `canvas.json`,
deviceScaleFactor 2; bấm nút `aria-label="Sáng / tối"` cho bản tối).
