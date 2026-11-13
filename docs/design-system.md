# Design system

Prototype (nguồn sự thật về giao diện): https://claude.ai/artifact/VoCymBbC7z1bQRoSRwkvVq
— artboard "Design system", "Mac · Học (+ ⌘K)", "Mac · Hôm nay", "Mac · Thư viện", "Mac · Nhập từ AI",
"Mac · Cắt clip âm thanh", "iPhone · …". Bấm Play trên artboard để thử tương tác.

## 1. Nguyên tắc

1. **Kính cho điều khiển, nền đặc cho nội dung.** Liquid Glass chỉ ở sidebar, toolbar, thanh nút nổi
   phía dưới màn Học/Cắt clip, ⌘K, popover/menu. Mặt thẻ, ô trả lời, bảng thẻ, ghi chú: `surface`.
2. **Bàn phím trước.** Mọi hành động trong màn Học và Cắt clip có phím tắt, hiện bằng nhãn `Kbd` cạnh nút.
3. **Mọi màu từ theme.** Không `Color.blue`, không hex trong view. Màu nhạt dẫn xuất bằng trộn:
   `accent` 18% trên nền trong suốt (mục sidebar đang chọn), `ok/bad/flag` 12–15% trên `surface` (nền ô
   đúng/sai/cờ).
4. **Chữ Hàn rõ.** Mặt thẻ dùng Noto Serif KR (theme có thể đổi sang sans), cỡ lớn; giao diện dùng font hệ
   thống (SF Pro + Apple SD Gothic Neo). Hỗ trợ phóng chữ thẻ `⌘=`/`⌘−`/`⌘0`.

## 2. Token

| Token | Dùng cho |
|---|---|
| `bg` | nền cửa sổ phía sau nội dung |
| `surface` | thẻ, ô nhập, bảng, card |
| `ink` / `ink2` | chữ chính / chữ phụ, nhãn |
| `accent` / `onAccent` | nút chính, tiến độ, mục đang chọn / chữ trên nền accent |
| `line` | viền, kẻ bảng |
| `ok` / `bad` / `flag` | đúng / sai / cờ ⭐ và cảnh báo "Trùng" |

Mọi cặp chữ/nền trong 6 theme đã kiểm ≥ 4.5:1 (ink/bg, ink2/surface, onAccent/accent, ok/bad/flag trên
surface) ở cả sáng và tối — `DesignSystemTests` phải giữ điều này.

Khoảng cách: 4 · 8 · 12 · 16 · 24 · 32 · 48. Bo góc: 8 (nhỏ) · 14 (vừa) · 22 (lớn: mặt thẻ, panel) · pill.
Chạm/bấm tối thiểu 44 pt trên iOS, 28 pt trên Mac.

## 3. Theme JSON

File: `apple/Packages/DesignSystem/Sources/DesignSystem/Resources/Themes/<id>.json`.

```json
{
  "schemaVersion": 1,
  "id": "paper",
  "name": "Giấy",
  "description": "Mặc định · trắng ngà, mực xanh",
  "useSystemAccent": false,
  "typography": { "cardKoreanFont": "serif", "uiFont": "system", "cardScale": 1.0 },
  "light": { "bg": "#F5F4F0", "surface": "#FFFFFF", "ink": "#191C24", "ink2": "#4C5260",
             "accent": "#2B54C9", "line": "#DDDBD3", "onAccent": "#FFFFFF",
             "ok": "#1C7146", "bad": "#B23A2E", "flag": "#9A5B00" },
  "dark":  { "...": "cùng khoá" }
}
```

| id | Tên | Tính cách |
|---|---|---|
| `paper` | Giấy | mặc định · trắng ngà, mực xanh |
| `ink` | Mực đêm | tím chàm, dịu mắt buổi tối |
| `pine` | Rừng thông | xanh lá trầm, tập trung |
| `dusk` | Hoàng hôn | cam đất ấm |
| `contrast` | Tương phản cao | đen trắng, accent vàng ở bản tối |
| `system` | Hệ thống | `useSystemAccent: true` — accent theo màu nhấn macOS |

Hành vi:
- `ThemeStore` (@Observable) giữ `themeID` + `appearance` (`.system` / `.light` / `.dark`) trong
  `UserDefaults`; `appearance = .system` theo chế độ sáng/tối của máy.
- Đổi qua ⌘K › "Theme: <tên>", Cài đặt › Giao diện (lưới thẻ xem trước như artboard Design system),
  hoặc nút theme trên toolbar (xoay vòng).
- **Nhập theme**: Cài đặt › Giao diện › "Nhập file .json…" — giải mã `Theme`, lỗi thì báo rõ khoá nào
  thiếu; lưu vào Application Support/Themes; id trùng theme có sẵn thì đổi id. **Xuất**: lưu theme
  đang dùng ra `.json` để sửa tay.

## 4. Liquid Glass (SwiftUI, macOS/iOS 26)

| Thành phần | API |
|---|---|
| Sidebar | `NavigationSplitView` mặc định đã là kính trên macOS 26 — không tự vẽ thêm nền |
| Toolbar | `.toolbar { … }` + `ToolbarSpacer`; nút trong toolbar tự là kính |
| Thanh nút nổi (Học, Cắt clip) | `GlassEffectContainer { HStack { … } }` + mỗi nút `.buttonStyle(.glass)`; nút chính `.buttonStyle(.glassProminent)` + `.tint(theme.accent)` |
| ⌘K palette | `.sheet`/overlay với `.glassEffect(.regular, in: .rect(cornerRadius: 20))` |
| Chip, popover | `.glassEffect(.regular.interactive(), in: .capsule)` |

Quy tắc: không đặt kính lên kính; không dùng kính cho mặt thẻ; độ trong do hệ thống quyết định (người
dùng bật "Giảm độ trong suốt" thì hệ thống tự xử lý — không tự giả lập bằng blur).

## 5. Component (DesignSystem)

| Component | Mô tả | Artboard tham chiếu |
|---|---|---|
| `CardSurface` | khung mặt thẻ: nền `surface`, viền `line`, bo 22 | Mac · Học |
| `AnswerField` | ô gõ tiếng Hàn 3 trạng thái (`idle/correct/wrong/revealed`), nhãn trạng thái phía trên | Design system › Ô trả lời |
| `GlassActionBar` | thanh nút kính nổi + nhãn `Kbd` | Mac · Học, Cắt clip |
| `Kbd` | nhãn phím tắt (`⌘K`, `↵`) | toolbar |
| `DeckRow` | hàng bộ từ: badge kỹ năng (읽기/듣기/문법/쓰기), tên, meta, hạn ôn | Mac · Hôm nay |
| `FlagChip` | ⭐ khó nhớ · 漢 Hán Hàn · 📖 đoạn văn · 🎧 clip | Design system |
| `ProgressRing` | vòng tiến độ | Mac · Hôm nay |
| `WaveformView` | dạng sóng + vùng A–B + đầu phát (trong App, không ở DesignSystem — cần AVFoundation) | Mac · Cắt clip |
| `ThemePreviewTile` | thẻ xem trước theme (4 dải màu + tên + mô tả) | Design system |

## 6. Màn hình (Mac)

Bố cục chung: sidebar kính (Hôm nay · Học · Thư viện · Nhập từ AI · Cắt clip âm thanh + nhóm/bộ ảo),
toolbar kính (tiêu đề, ⌘K, nút theme, nút sáng/tối), nội dung nền `bg`.
Chi tiết từng màn: xem artboard tương ứng + mục "Xong khi" trong `docs/tasks.md`.
