# CLAUDE.md

**Tiramissu** — app học tiếng Hàn (Hàn ↔ Việt) cá nhân, khép kín với Google Drive + Gemini/NotebookLM.
App SwiftUI **ưu tiên Mac** (học + soạn + nhập + cắt clip âm thanh), iPhone chỉ học/ôn (làm sau).
Liquid Glass (macOS 26 / iOS 26), 6 theme JSON kiểu VS Code. Backend Express 5 + Prisma 7 + Postgres
để đồng bộ Mac ↔ iPhone (không có Apple Developer trả phí → không CloudKit).
Giao diện + comment: **tiếng Việt**. Agent khác: xem `AGENTS.md`.

## Bắt đầu mỗi phiên

1. Đọc `docs/tasks.md` → lấy task `[ ]` đầu tiên **không có nhãn 👤** và đã đủ phụ thuộc.
2. Đọc các file trong mục **File** / **Đọc trước** của task đó (bảng dưới).
3. Làm → chạy lệnh trong **Xong khi** → tick `[x]` trong `docs/tasks.md` → commit (một task / commit,
   message tiếng Việt, bắt đầu bằng mã task, vd `T2.07: StudyEngine — trả lời sai`).
4. Không làm gộp nhiều task; không tự mở rộng phạm vi. Thấy việc ngoài task → ghi vào cuối
   `docs/tasks.md` mục "Phát sinh".

## Tài liệu — đọc khi đụng vùng đó

| File | Nội dung |
|---|---|
| `docs/plan.md` | bối cảnh, kiến trúc tổng, các giai đoạn, rủi ro |
| `docs/tasks.md` | checklist việc cần làm (nguồn sự thật về tiến độ) |
| `docs/architecture.md` | module Swift, mô hình dữ liệu, API, đồng bộ offline-first |
| `docs/design-system.md` | token, 6 theme, quy tắc Liquid Glass, component |
| `design/prototype/` | **prototype offline**: ảnh từng màn + nguồn HTML — đọc trước khi làm màn nào |
| `docs/study-algorithm.md` | thuật toán ôn trong lượt, deck ảo, gợi ý ôn lại — **đặc tả để port** |
| `docs/backend.md` | 3 fix trong `db.ts`, cấu trúc module, dữ liệu, file nghe |
| `docs/testing.md` | test Swift + backend, bẫy |
| `docs/drive-setup.md`, `docs/prompts/` | quy trình Drive → AI → JSON |
| `reference/flutter/` | mã Dart gốc + test — **chỉ đọc**, nguồn để port sang `HanCore` |

## Lệnh

```bash
# Swift (logic thuần, chạy được cả trên Linux có Swift 6 toolchain)
cd apple/Packages/HanCore && swift test
cd apple/Packages/DesignSystem && swift test
# App (trên Mac, Xcode 26): sinh project từ apple/project.yml
cd apple && xcodegen && open Tiramissu.xcodeproj

# Backend (cần `docker compose up -d` ở gốc repo)
cd backend && npm ci && npx prisma generate   # generate bắt buộc sau clone/đổi schema
npx prisma migrate dev
npm run dev                                    # http://localhost:3000
npx tsc --noEmit && npm run lint && npx vitest run
```

## Quy tắc bắt buộc

- `HanCore` là Swift thuần: **không** import SwiftUI/AppKit/UIKit. Random + đồng hồ phải tiêm được.
  UI chỉ thấy snapshot bất biến (`StudySessionState`), không cầm `StudyEngine`.
- Port giữ **đúng hành vi** trong `docs/study-algorithm.md` và test Dart gốc. Sửa engine → thêm test.
- Màu/chữ/bo góc chỉ lấy từ `Theme` (`DesignSystem`) — không hardcode `Color(...)` trong màn hình.
- Liquid Glass (`.glassEffect`, `.buttonStyle(.glass)`) **chỉ** cho lớp điều khiển (sidebar, toolbar,
  thanh nút nổi, popover, ⌘K). Mặt thẻ, ô trả lời, bảng thẻ: nền đặc `theme.surface`.
- Mọi hành động học trên Mac có phím tắt (xem `docs/design-system.md` › Phím tắt).
- So đáp án tiếng Hàn: chuẩn hoá NFC + gộp khoảng trắng (`AnswerMatcher`), không so chuỗi thô.
- `APIClient` chỉ ném `APIError` (kể cả lỗi decode). Token API lưu Keychain, không UserDefaults.
- Backend: giữ 3 fix trong `backend/src/config/db.ts`. Lỗi nghiệp vụ ném `HttpError`, route bọc
  `handle()`. Thêm biến env → cập nhật `backend/.env.example`.
- **Không tự curl route ghi (POST/PATCH/DELETE) vào server thật/dev** — từng mất dữ liệu. GET thoải mái.
- Không đổi `DEFAULT_USER_EMAIL` mặc định (`local@vocab-app.local`) — dữ liệu thật gắn với email này.
- Không sửa tay `reference/`, `design/prototype/` (chỉ để đọc) và `reference/content.sample.json` (xuất bằng `npm run export-content`).
- Không ghi tên/ID model AI vào commit, PR, comment code.
- Trước khi báo xong: `swift test` sạch ở package đã đụng; đụng backend thì `tsc`, lint, vitest sạch.
  Không chạy được (thiếu toolchain/Postgres) → nói rõ, không giả vờ đã chạy.
- File này nạp vào mọi phiên — giữ ngắn. Chi tiết/lý do → `docs/`, ở đây tối đa một dòng quy tắc.
