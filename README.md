# Tiramissu 🍰

App học tiếng Hàn cá nhân, khép kín:

```
Google Docs (bài học, bài tập) ──► Gemini / NotebookLM (prompt soạn sẵn) ──► JSON
        ▲                                                                     │
        │ tick "Đã đưa vào app"                                               ▼
        └──────────────────────────────── App Mac (học · soạn · nhập · cắt clip âm thanh)
                                                    │  đồng bộ qua backend
                                                    ▼
                                             App iPhone (học · ôn)
```

- **Mac là chính**: học bằng bàn phím, nhập bộ thẻ từ JSON của AI, cắt đoạn âm thanh khó nghe.
- **iPhone**: chỉ học và ôn (làm sau).
- Liquid Glass (macOS 26 / iOS 26), 6 theme đổi được như VS Code (⌘K › Theme).
- Ôn theo Leitner trong lượt + lịch ôn 1 → 3 → 7 → 14 → 30 → 60 ngày.

Prototype giao diện: `design/prototype/` (ảnh chụp + nguồn) · bản tương tác: https://claude.ai/artifact/VoCymBbC7z1bQRoSRwkvVq

## Cấu trúc

```
apple/        SwiftUI: Packages/HanCore (logic), Packages/DesignSystem (theme + glass), App/Mac, App/iOS
backend/      Express 5 + Prisma 7 + Postgres — nội dung, lịch sử học, file âm thanh, clip
docs/         plan · tasks · architecture · design-system · study-algorithm · backend · testing · drive · prompts
reference/    mã Dart của app Flutter cũ (chỉ đọc, để port) + content.sample.json
```

## Chạy nhanh

```bash
docker compose up -d
cd backend && npm ci && npx prisma generate && npx prisma migrate dev && npm run dev
```

```bash
cd apple && brew install xcodegen && xcodegen && open Tiramissu.xcodeproj
```

Tiến độ và việc tiếp theo: [`docs/tasks.md`](docs/tasks.md). Kế hoạch: [`docs/plan.md`](docs/plan.md).
