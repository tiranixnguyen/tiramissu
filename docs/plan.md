# Kế hoạch — Tiramissu

> Bản kế hoạch cho người đọc. Việc cụ thể từng bước: [`tasks.md`](tasks.md).
> Prototype giao diện (đã duyệt v2): https://claude.ai/artifact/VoCymBbC7z1bQRoSRwkvVq

## 1. Bối cảnh & mục tiêu

Mình học tiếng Hàn online, tài liệu và bài tập nằm trên Google Docs. Trước đây có app Flutter
`flashcard-app` (Flutter + backend Express/Prisma/Postgres): học từ Hàn → Việt, Leitner trong lượt, lịch
ôn 1 → 3 → 7 → 14 → 30 → 60 ngày, cờ ⭐/漢/📖, nhập bộ bằng JSON dán từ AI. App chạy được nhưng UI chưa
chỉn chu, không có design system; điện thoại phải cùng Wi-Fi với Mac mới đồng bộ.

**Mục tiêu:** một quy trình khép kín

1. **Google Drive** có cấu trúc chuẩn → mỗi bài học là một Doc theo template.
2. **AI (Gemini / NotebookLM)**, copy/paste với prompt soạn sẵn → JSON thẻ học.
3. **App Mac** (dùng chính): học bằng bàn phím, nhập JSON, sửa thẻ, **cắt đoạn âm thanh** khó nghe
   từ file mình tự có (thường lấy từ YouTube), luyện nghe chép chính tả.
4. **App iPhone** (ưu tiên thấp): chỉ học và ôn khi ra ngoài.
5. Quay lại Doc, tick "Đã đưa vào app ☐" → khép vòng.

## 2. Kiến trúc tổng

```
┌─────────────── Google Drive ────────────────┐
│ 01_Giáo trình/<Khoá>/Bài 07 – Plastic (Doc) │──┐ copy nội dung / dùng làm source
│ 04_Sổ lỗi sai · 05_Prompt                   │  │
└─────────────────────────────────────────────┘  ▼
                                  Gemini / NotebookLM + prompt (docs/prompts/)
                                                 │ JSON {name, words[]}
                                                 ▼
┌──────────── App Mac (SwiftUI, macOS 26) ─────────────┐        ┌── iPhone (iOS 26) ──┐
│ Hôm nay · Học · Thư viện · Nhập từ AI · Cắt clip     │        │ Hôm nay · Học · Nghe│
│ HanCore (engine, lịch ôn, import, sync)              │        │ (cùng HanCore +     │
│ DesignSystem (6 theme JSON, Liquid Glass)            │        │  DesignSystem)      │
│ SwiftData cache — học offline                        │        │                     │
└───────────────┬──────────────────────────────────────┘        └──────────┬──────────┘
                │ HTTPS + Bearer token (offline-first, hàng đợi)            │
                ▼                                                           ▼
        ┌──────────── Backend (Render/Fly.io free) ── Postgres (Neon/Supabase free) ───┐
        │ /content /groups /decks /cards /cards/flags /sessions /audio /clips           │
        └──────────────────────────────────────────────────────────────────────────────┘
```

Chi tiết module, dữ liệu, API: [`architecture.md`](architecture.md).

## 3. Quyết định chính

| Vấn đề | Quyết định | Lý do |
|---|---|---|
| Nền tảng app | SwiftUI native, một codebase Mac + iOS | Liquid Glass, phím tắt, trải nghiệm Mac thật |
| Ưu tiên | Mac trước, iPhone sau | Phần lớn thời gian học trên Mac |
| Đồng bộ | **Giữ backend cũ**, đưa lên cloud miễn phí + token | Không có Apple Developer trả phí → không CloudKit; backend đã offline-first, có test |
| Repo | Monorepo `tiramissu` (apple/ + backend/ + docs/) | Một CLAUDE.md, agent thấy đủ ngữ cảnh |
| AI | Copy/paste, prompt soạn sẵn | Đơn giản, miễn phí; NotebookLM không có API |
| Âm thanh | Mình tự có file, app chỉ cắt + lưu đoạn (M4A) | Không tải từ YouTube trong app (điều khoản YouTube) |
| Giao diện | Liquid Glass cho lớp điều khiển, nền đặc cho nội dung | Đúng hướng dẫn Apple, chữ Hàn dễ đọc |
| Theme | 6 theme × sáng/tối, file JSON, nhập/xuất được | "Đổi theme như VS Code" |
| Target | macOS 26 / iOS 26, Xcode 26 | Liquid Glass chỉ có từ bản 26 |

## 4. Google Drive

```
📁 Korean/
├── 00_Inbox/                 ← tài liệu mới nhận, chưa xử lý
├── 01_Giáo trình/<Khoá>/     ← "Bài 01 – <chủ đề>" + "Bài 01 – Bài tập"
├── 02_Ngữ pháp/              ← 1 Doc / cấu trúc, cùng template
├── 03_Nghe/                  ← 1 Doc / nguồn nghe: link, ghi chú, câu khó
├── 04_Sổ lỗi sai             ← 1 Doc, bảng | Sai | Đúng | Lý do |
├── 05_Prompt/                ← bản sao docs/prompts/
└── 99_Archive/
```

Hướng dẫn từng bước + template Doc: [`drive-setup.md`](drive-setup.md). File âm thanh gốc để trên Mac
(`~/Korean Audio/`), không đưa lên Drive.

## 5. Thư viện prompt

Mọi prompt trả về **một khối JSON** đúng định dạng nhập của app:
`{"name": "...", "words": [{"front", "back", "hint?", "note?", "altAnswers?", "typeAnswer?"}]}`.

| Prompt | File | Đầu vào | Thẻ tạo ra |
|---|---|---|---|
| Từ vựng | `prompts/vocab.md` | đoạn tiếng Hàn | nghĩa Việt → từ/cụm Hàn (gõ đáp án) |
| Ngữ pháp | `prompts/grammar.md` | phần Ngữ pháp | cấu trúc → ý nghĩa; câu đục lỗ → câu đầy đủ (tự chấm) |
| Chữa bài | `prompts/fix.md` | bài làm + chữa của GV | câu sai → câu đúng, `note` = lý do; kèm bảng cho Sổ lỗi sai |
| Câu nghe | `prompts/listen.md` | chép lời / phụ đề | nghĩa Việt → câu Hàn |

Mỗi prompt có bản Gemini (dán kèm nội dung) và bản NotebookLM ("dựa trên source …"). App có nút
"Chép prompt" ở màn Nhập.

## 6. App

### Mac (giai đoạn 2–3)

| Màn | Nội dung |
|---|---|
| Hôm nay | bộ đến hạn (theo lịch ôn), clip cần nghe, chuỗi ngày, heatmap 14 ngày |
| Học | thẻ gõ đáp án / tự chấm, thanh nút kính nổi, cột "Lượt học"; toàn bộ bằng phím tắt; TTS tiếng Hàn; cửa sổ học gọn nổi trên cùng (⌥⌘L) |
| Thư viện | nhóm → bộ → bảng thẻ, sửa tại chỗ, cờ ⭐/漢/📖 |
| Nhập từ AI | chọn loại prompt + công cụ → chép; dán JSON → kiểm tra → xem trước, báo trùng → tạo bộ |
| Cắt clip | kéo thả file âm thanh → dạng sóng → A/B → nhập câu + nghĩa → lưu M4A + Clip |
| Cài đặt | server + token, theme (nhập/xuất JSON), giọng TTS |
| ⌘K | Command Palette: đổi theme, mở bộ, đi tới màn |

### iPhone (giai đoạn 4)

Hôm nay · Học · Nghe clip. Không soạn/nhập. Cài bằng Apple ID miễn phí (hết hạn sau 7 ngày, cài lại
từ Xcode — dữ liệu vẫn còn vì cùng bundle id + server giữ dữ liệu).

## 7. Liquid Glass & theme

Xem [`design-system.md`](design-system.md). Tóm tắt:

- Glass: sidebar, toolbar, thanh nút nổi, ⌘K, popover — dùng `glassEffect`, `GlassEffectContainer`,
  `.buttonStyle(.glass)`; nút chính tô màu nhấn `.glassEffect(.regular.tint(accent))`.
- Nội dung (mặt thẻ, ô trả lời, bảng) luôn trên nền đặc `surface`.
- Theme = file JSON (`apple/Packages/DesignSystem/Sources/DesignSystem/Resources/Themes/*.json`):
  Giấy (mặc định), Mực đêm, Rừng thông, Hoàng hôn, Tương phản cao, Hệ thống — mỗi theme có sáng/tối.

## 8. Cắt clip âm thanh

- File gốc ở yên trên Mac (security-scoped bookmark). Dạng sóng từ `AVAudioFile`.
- `Space` phát/dừng · `[` đặt A · `]` đặt B · `⌥←/⌥→` ±0.1 s · `L` lặp A-B · tốc độ 0.5/0.75/1×
  (`AVAudioUnitTimePitch`, không đổi cao độ).
- Lưu: xuất A–B thành M4A/AAC (~50 KB / 5 s) → `POST /audio` → `POST /clips`.
- Luyện clip: nghe lặp, chép chính tả, chấm theo từ; kết quả đi vào Leitner + lịch ôn như thẻ.

## 9. Backend — thay đổi

1. Middleware `Authorization: Bearer <API_TOKEN>` (trừ `/health`).
2. `Dockerfile` + deploy: Postgres (Neon/Supabase free) + web service (Render/Fly.io free). Chuyển
   dữ liệu cũ bằng `pg_dump`/`pg_restore`.
3. Module `audio` nhận thêm M4A (`audio/mp4`, header `ftyp`).
4. Model `Clip` + route `/clips`; `GET /content` trả kèm `clips`.
5. `Deck.source`: enum → chuỗi tự do (≤ 40 ký tự).
6. Dọn: bỏ bảng `SyncState` + script `import-content` (khi chắc không cần).

## 10. Các giai đoạn

| GĐ | Nội dung | Kết quả dùng được |
|---|---|---|
| 0 | Prototype v1 → v2 | ✅ Đã xong — còn chốt góp ý |
| 1 | Backend lên cloud + token, docs Drive + prompt | Quy trình Drive → AI → JSON chạy với dữ liệu thật |
| 2 | HanCore + DesignSystem + app Mac (Học, Hôm nay, Thư viện, Nhập, Cài đặt, ⌘K) | Học hằng ngày trên Mac bằng app mới |
| 3 | Clip âm thanh (backend + màn cắt + luyện) | Luyện nghe trên Mac |
| 4 | App iPhone | Ôn khi ra ngoài |
| 5 | Dọn dẹp, README, archive repo cũ | |

## 11. Kiểm thử

- Backend: `tsc`, lint, `vitest` (Postgres thật trong docker, user test riêng). Sau deploy chỉ `GET`.
- HanCore: `swift test` — bản port 1-1 test Dart gốc (`reference/flutter/test/`).
- DesignSystem: test giải mã 6 theme + độ tương phản.
- UI: checklist tay trong từng task ("Xong khi"), chạy trên Mac bằng Xcode 26.

## 12. Rủi ro & giới hạn

| Rủi ro | Ứng phó |
|---|---|
| App iPhone ký miễn phí hết hạn 7 ngày | Cài lại từ Xcode; iPhone là ưu tiên thấp. Có thể mua Developer sau |
| Gói cloud miễn phí "ngủ" (khởi động chậm vài chục giây) / đổi chính sách | App offline-first nên vẫn học được; đồng bộ nền khi server dậy. Kiểm lại gói lúc deploy |
| Liquid Glass chỉ macOS/iOS 26 | Đã chốt target 26 |
| Môi trường agent (Linux) không có Xcode | Logic dồn vào Swift package chạy `swift test` được; UI kiểm tra tay trên Mac |
| Port engine sai hành vi | Port test Dart 1-1 trước, rồi mới viết engine (TDD) |
| Mất dữ liệu khi deploy/migrate | `pg_dump` trước mỗi lần đổi schema; không curl route ghi vào server thật |
