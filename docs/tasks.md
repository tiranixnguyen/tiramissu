# Tasks — Tiramissu

Cách dùng (cho agent): lấy task `[ ]` **đầu tiên** không có nhãn 👤 mà mọi task ở mục **Phụ thuộc** đã
`[x]`. Làm đúng phạm vi → chạy **Xong khi** → tick `[x]` → commit `T<mã>: <tiêu đề>`.
👤 = việc bạn tự làm (tài khoản, Xcode, thiết bị thật). Agent gặp task 👤 chưa xong mà task sau phụ thuộc
→ dừng và báo.

Ký hiệu đường dẫn: `HC/` = `apple/Packages/HanCore/`, `DS/` = `apple/Packages/DesignSystem/`,
`BE/` = `backend/`, `REF/` = `reference/flutter/`.

---

## G0 · Prototype

- [x] **T0.1 · Prototype v1** (màn iPhone + Mac, design system đầu tiên)
- [x] **T0.2 · Prototype v2**: Mac-first, Liquid Glass, 6 theme, ⌘K, cắt clip âm thanh
  — https://claude.ai/artifact/VoCymBbC7z1bQRoSRwkvVq · bản offline: `design/prototype/`
- [x] **T0.3 · Khởi tạo monorepo**: docs, CLAUDE.md, khung Swift, backend chép từ `flashcard-app`
- [x] **T0.3b · Prototype offline** → `design/prototype/` (ảnh chụp mọi màn sáng/tối + 6 theme, mã nguồn)
  để agent không đăng nhập claude.ai vẫn đọc được. Màn Mac/iOS: đọc ảnh `design/prototype/screens/<màn>-*.png`
  + nguồn `src/<màn>.dc.html` trước khi làm.
- [ ] **T0.4 · 👤 Chốt góp ý prototype** → ghi thay đổi (nếu có) vào `docs/design-system.md`

---

## G1 · Backend lên cloud + quy trình Drive

- [x] **T1.01 · Chạy baseline backend trong monorepo**
  - File: `docker-compose.yml`, `BE/.env.example`
  - Làm: `docker compose up -d` → `cd backend && cp .env.example .env && npm ci && npx prisma generate && npx prisma migrate dev`.
    Sửa mọi chỗ gãy do đổi đường dẫn (DB `tiramissu_dev`, `exportContent` ghi `reference/content.sample.json`).
  - Xong khi: `npx tsc --noEmit && npm run lint && npx vitest run` đều sạch.
  - Ghi chú: cần Docker. Môi trường không có Docker → chỉ chạy `tsc` + lint, ghi rõ vitest chưa chạy.

- [x] **T1.02 · Xác thực bằng token**
  - File: `BE/src/modules/common/auth.ts` (mới), `BE/src/app.ts`, `BE/.env.example`, `BE/vitest.setup.ts`,
    `BE/src/testing/testServer.ts`, `BE/src/modules/common/auth.integration.test.ts` (mới)
  - Làm: middleware đọc `Authorization: Bearer <token>`, so với `process.env.API_TOKEN` bằng
    `crypto.timingSafeEqual`; sai/thiếu → 401 `{ error: "Thiếu hoặc sai mã truy cập." }`. `/health` không cần
    token. `API_TOKEN` rỗng → server **từ chối khởi động** khi `NODE_ENV=production`, còn dev thì bỏ qua
    kiểm tra (log cảnh báo). Test server gửi token test tự động.
  - Xong khi: test mới (thiếu token 401, sai token 401, đúng token 200, `/health` 200 không token) + toàn bộ
    vitest cũ pass; `.env.example` có `API_TOKEN` kèm chú thích.
  - Phụ thuộc: T1.01

- [x] **T1.03 · `Deck.source` thành chuỗi tự do**
  - File: `BE/prisma/schema.prisma`, migration mới, `BE/src/modules/content/*` (+ test), `docs/backend.md`
  - Làm: đổi cột `source` từ enum `DeckSource` sang `String?` (giữ dữ liệu: `snu4a` → `"SNU 4A"`… theo
    nhãn cũ, viết trong SQL migration), validate ≤ 40 ký tự, rỗng → `null`. Xoá enum.
  - Xong khi: vitest pass, test mới cho source tự do + quá dài → 400; `docs/backend.md` cập nhật.
  - Phụ thuộc: T1.01

- [x] **T1.04 · File nghe M4A**
  - File: `BE/src/modules/audio/audioService.ts`, `audioRoutes.ts`, test tương ứng, `docs/backend.md`
  - Làm: bảng `Audio` đã có cột `mime` → nhận thêm `audio/mp4` khi bytes có `ftyp` ở offset 4 (`looksLikeM4a`); trả đúng
    `Content-Type` theo `mime` khi GET. Vẫn từ chối file khác (415).
  - Xong khi: test thuần `looksLikeM4a` + test tích hợp upload/GET M4A (có Range 206) pass.
  - Phụ thuộc: T1.01

- [x] **T1.05 · Model `Clip` + `/clips`**
  - File: `schema.prisma` + migration, `BE/src/modules/clips/{clipService,clipRoutes}.ts` + `clips.integration.test.ts`,
    `BE/src/modules/content/contentService.ts` (`getContent` trả `clips`), `BE/src/app.ts`, `docs/architecture.md` §4
  - Làm: bảng `Clip` theo `docs/architecture.md` §3 (`audioId` FK → `Audio` onDelete Restrict, `deckId` FK
    onDelete SetNull, `userId`). Route: `GET /clips`, `POST /clips` (validate start < end, ≤ 60 s,
    transcript bắt buộc ≤ 500 ký tự, audio thuộc user), `PATCH /clips/:id`, `DELETE /clips/:id`.
    `prune-audio` không xoá audio còn clip trỏ tới.
  - Xong khi: test CRUD + validate + `/content` có `clips` + prune không xoá audio của clip; vitest sạch.
  - Phụ thuộc: T1.04

- [x] **T1.06 · Dockerfile + cấu hình deploy**
  - File: `BE/Dockerfile`, `BE/.dockerignore`, `render.yaml` (gốc repo), `docs/backend.md` mục "Deploy"
  - Làm: Dockerfile nhiều tầng (Node 22, `npm ci`, `prisma generate`, `tsc`, chạy
    `npx prisma migrate deploy && node dist/src/index.js`), lắng nghe `PORT`. `render.yaml` cho web service
    free, env `DATABASE_URL`, `API_TOKEN` (sync: false), `NODE_ENV=production`. Viết hướng dẫn deploy
    Neon + Render từng bước, cách `pg_dump` local → `pg_restore` lên Neon.
  - Xong khi: `docker build backend` thành công (nếu có Docker); doc đủ bước cho T1.07–T1.08.
  - Phụ thuộc: T1.02

- [x] **T1.07 · 👤 Tạo Postgres (Neon) + web service (Render)** _(xong: Neon + Render `https://tiramissu-api.onrender.com`)_ theo `docs/backend.md` › Deploy;
  sinh `API_TOKEN` (`openssl rand -hex 32`), lưu vào trình quản lý mật khẩu.
- [x] **T1.08 · ~~Chuyển dữ liệu cũ~~ — BỎ** (quyết định: không chuyển `pg_dump` lên Neon). Dữ liệu cũ chỉ dùng làm
  dữ liệu mẫu: `reference/content.sample.json`, app đóng gói sẵn và nạp khi chưa có cache. DB Neon bắt đầu trống.
- [ ] **T1.09 · 👤 Dựng Google Drive** theo `docs/drive-setup.md`; chép 4 prompt vào `05_Prompt/`;
  tạo notebook NotebookLM cho khoá đang học.

---

## G2 · HanCore (Swift thuần, TDD — port test Dart trước, rồi code)

> Random trong Dart và Swift khác nhau → test dựa vào thứ tự ngẫu nhiên cụ thể phải viết lại theo
> **tính chất** (vd "thẻ sai quay lại đúng sau 2 thẻ"), dùng `SeededGenerator` cố định.

- [ ] **T2.01 · 👤 Chạy `swift test` lần đầu** ở `HC/` và `DS/` trên Mac (Xcode 26) — khung phải pass
  (`AnswerMatcherTests`, `ThemeTests`). Báo lỗi nếu `platforms: .v26` chưa nhận.

- [x] **T2.02 · Mô hình dữ liệu + giải mã `/content`**
  - File: `HC/Sources/HanCore/Models/{Content,StudyWord,DeckType,StudySessionRecord,FlagChange}.swift`,
    `HC/Tests/HanCoreTests/ContentDecodingTests.swift`, test resource: chép `reference/content.sample.json`
    vào `HC/Tests/HanCoreTests/Resources/` (khai báo `resources` trong `Package.swift`)
  - Đọc trước: `REF/models/content.dart`, `deck.dart`, `study_word.dart`, `study_session_record.dart`, `card_audio.dart`
  - Làm: struct `Codable, Sendable, Hashable` theo `docs/architecture.md` §3 (chưa có `Clip` — T3.01).
    Decode mềm như Dart: thiếu trường → mặc định, `kr`/`vi` → `back`/`front` + `typeAnswer = true`,
    `type` lạ → `nil`, `parentId` bỏ qua. Ngày ISO-8601 có mili giây.
  - Xong khi: decode `content.sample.json` không lỗi, đúng số nhóm/bộ/thẻ; test cache cũ `kr`/`vi`;
    encode → decode giữ nguyên (round-trip).

- [x] **T2.03 · Tiện ích: `SeededGenerator`, `Clock`**
  - File: `HC/Sources/HanCore/Util/{SeededGenerator,Clock}.swift` + test
  - Làm: `SeededGenerator: RandomNumberGenerator` (SplitMix64); `Clock` = `@Sendable () -> Date` +
    `Calendar` tiêm được.
  - Xong khi: cùng seed → cùng dãy; test pass.

- [x] **T2.04 · `DeckImport`**
  - File: `HC/Sources/HanCore/Import/DeckImport.swift`, `HC/Tests/HanCoreTests/DeckImportTests.swift`
  - Đọc trước: `REF/domain/deck_import.dart`, `REF/test/deck_import_test.dart` (12 test)
  - Làm: port `parseDeckImport`, `defaultTypeAnswer`, `duplicatesOf`; bóc khối ```json; giới hạn 500;
    từ chối `followUp(s)`; `note` giữ nguyên thụt lề.
  - Xong khi: 12 test port 1-1 pass (+ test JSON có bảng Markdown phía sau khối json — prompt "Chữa bài").

- [x] **T2.05 · Prompt nhúng trong app**
  - File: `HC/Sources/HanCore/Import/Prompts.swift` + test
  - Làm: `enum PromptKind { vocab, grammar, fix, listen }`, `enum AITool { gemini, notebookLM }`,
    `Prompts.text(kind:tool:)` trả **nguyên văn** khối trong `docs/prompts/<kind>.md`.
  - Xong khi: test: 8 tổ hợp không rỗng, bản Gemini có placeholder `<DÁN`, bản NotebookLM có `source`.

- [x] **T2.06 · Dựng catalog + fixture**
  - File: `HC/Sources/HanCore/Study/StudyCatalog.swift`, `HC/Tests/HanCoreTests/Support/Fixtures.swift`,
    `StudyEngineTests.swift` (bắt đầu)
  - Đọc trước: `REF/models/content.dart` (`buildStudyCatalog`), `REF/test/fixtures.dart`
  - Xong khi: test nhóm "dựng dữ liệu (buildStudyCatalog)" (2 test) pass.
  - Phụ thuộc: T2.02, T2.03

- [x] **T2.07 · `StudyEngine` — hàng đợi, chấm bài, Leitner**
  - File: `HC/Sources/HanCore/Study/{StudyEngine,CardProgress,StudySessionState}.swift`, `StudyEngineTests.swift`
  - Đọc trước: `docs/study-algorithm.md` (Mô hình, Hàng đợi), `REF/domain/study_engine.dart` dòng 1–330
  - Làm: `final class StudyEngine` (không `ObservableObject`), hằng `masteryStreak = 3`, `wrongOffset = 2`,
    `boxOffsets = [3, 5, 9, 15]`; `bootstrap`, `loadCard`, `nextCard`, `checkAnswer` (dùng
    `AnswerMatcher.normalize` + `altAnswers`), `cardSerial`, `snapshot() -> StudySessionState`.
  - Xong khi: test nhóm "chấm bài" (3) + "lịch Leitner" (4) pass.
  - Phụ thuộc: T2.06

- [x] **T2.08 · `StudyEngine` — xem đáp án, "Đã trả lời đúng?", đã thuộc**
  - Làm: `revealAnswer`, `overrideAsCorrect` (hoàn tác nhánh sai, khôi phục snapshot box/streak), `markKnown`.
  - Xong khi: nhóm "tự xác nhận đúng" (2) pass.
  - Phụ thuộc: T2.07

- [x] **T2.09 · `StudyEngine` — thẻ tự chấm**
  - Làm: `flipCard`, `gradeSelf(remembered:)`, cờ `flipped`; thẻ gõ/tự chấm từ chối API của nhau.
  - Xong khi: nhóm "thẻ tự chấm" (9) pass — 7 test ở đây; 2 test cần `replaceContent`/`switchDeck` port ở T2.10 và T2.12.
  - Phụ thuộc: T2.08

- [x] **T2.10 · `StudyEngine` — cờ ⭐/漢/📖 + deck ảo**
  - Làm: `toggleMark/Hanja/Passage`, deck ảo `marked`, `hanja`, `passage`, `random20` (theo
    `SeededGenerator`), phạm vi nhóm đang mở, `pruneUnflagged` khi nạp thẻ mới.
  - Xong khi: nhóm "đánh dấu và deck ảo" (11) + "mỗi thẻ độc lập" (2) pass.
  - Phụ thuộc: T2.09

- [x] **T2.11 · `StudyEngine` — đổi bộ/nhóm, học lại**
  - Làm: `switchDeck`, `switchGroup`, `restartCurrentDeck`, `reshuffleRandomDeck`, trả thẻ chưa trả lời
    về hàng đợi khi rời bộ.
  - Xong khi: nhóm "mỗi lần vào bộ là một lượt mới" (2) pass.
  - Phụ thuộc: T2.10

- [x] **T2.12 · `StudyEngine` — `replaceContent`**
  - Làm: mang tiến trình theo id thẻ khi nội dung đổi giữa lượt.
  - Xong khi: nhóm "nội dung thay đổi giữa lượt" (7) pass → **toàn bộ** test engine port xong.
  - Phụ thuộc: T2.11

- [x] **T2.13 · Ghi lần học (`SessionRecorder`)**
  - File: `HC/Sources/HanCore/Study/SessionRecorder.swift` + test
  - Đọc trước: `docs/study-algorithm.md` › Gợi ý ôn lại (đoạn về `StudySessionRecord`), `REF/models/study_session_record.dart`
  - Làm: bắt đầu ở câu trả lời đầu tiên; kết thúc khi thuộc hết (completed) hoặc đổi bộ/nhóm/học lại
    (bỏ dở); nháp sau mỗi câu; `finalizeDraft(lastAnswerAt:)`. Bộ ảo không ghi. id 128 bit ngẫu nhiên (hex).
  - Xong khi: test: mở bộ rồi đổi ngay → không ghi; học hết → completed; bỏ dở → không completed; nháp chốt đúng giờ.
  - Phụ thuộc: T2.12

- [x] **T2.14 · `ReviewSchedule`**
  - File: `HC/Sources/HanCore/Review/ReviewSchedule.swift`, `ReviewScheduleTests.swift`
  - Đọc trước: `REF/domain/review_schedule.dart`, `REF/test/review_schedule_test.dart` (13 test)
  - Xong khi: 13 test port pass (Calendar cố định `Asia/Ho_Chi_Minh`).
  - Phụ thuộc: T2.02, T2.03

- [x] **T2.15 · `APIClient`**
  - File: `HC/Sources/HanCore/Sync/{APIClient,APIError,Endpoints}.swift` + `APIClientTests.swift`
  - Làm: `protocol ContentAPI` (cho fake trong test) + `URLSessionContentAPI` (async/await, Bearer token,
    base URL). Mọi route ở `docs/architecture.md` §4 trừ `/clips` (T3.01). Chỉ ném
    `APIError { offline, unauthorized, server(message), decoding }`; đọc `{ error }` từ body. Upload audio
    gửi bytes thô kèm `Content-Type`. Dùng `FoundationNetworking` khi `canImport` (Linux).
  - Xong khi: test với `URLProtocol` stub: parse `/content`, 401 → `.unauthorized`, body HTML → `.decoding`,
    mất mạng → `.offline`, header Authorization đúng.
  - Phụ thuộc: T2.02

- [x] **T2.16 · `SyncEngine` + hàng đợi offline**
  - File: `HC/Sources/HanCore/Sync/{SyncEngine,PendingQueue,LocalStore}.swift` + test
  - Đọc trước: `docs/study-algorithm.md` › Đồng bộ với backend
  - Làm: `protocol LocalStore` (app cài bằng SwiftData; test dùng bản trong bộ nhớ). `syncNow()`: gửi
    `FlagChange` + `StudySessionRecord` chờ → `GET /content` (áp lại cờ còn chờ) → `GET /sessions`.
    Không chạy chồng (đang chạy mà có yêu cầu → chạy thêm 1 vòng). Không bao giờ ném; phát `SyncStatus`.
    `actor`.
  - Xong khi: test với fake API: offline giữ hàng đợi, có mạng gửi hết, cờ chờ đè nội dung vừa tải, 2 lần
    gọi chồng → đúng 2 vòng.
  - Phụ thuộc: T2.13, T2.15

### G2 · DesignSystem

- [x] **T2.20 · `Color(hex:)` + `ThemeStore`**
  - File: `DS/Sources/DesignSystem/Theme/{Color+Hex,ThemeStore,ResolvedTheme}.swift` (bọc `#if canImport(SwiftUI)`),
    test độ tương phản trong `DS/Tests/DesignSystemTests/ContrastTests.swift` (Foundation thuần)
  - Làm: `ThemeStore` `@Observable`: `themeID`, `appearance` (.system/.light/.dark), lưu UserDefaults,
    `resolved(colorScheme:) -> ResolvedTheme` (Color đã dựng; `useSystemAccent` → `Color.accentColor`);
    environment key `\.theme`.
  - Xong khi: test tương phản ≥ 4.5:1 cho 6 theme × 2 chế độ (các cặp ở `docs/design-system.md` §2) pass.
  - Phụ thuộc: T2.01

- [x] **T2.21 · Component + kính**
  - File: `DS/Sources/DesignSystem/{Glass,Components}/*.swift`, `DS/Sources/DesignSystem/Gallery/ComponentGallery.swift`
  - Làm: `CardSurface`, `AnswerField`, `GlassActionBar`, `Kbd`, `DeckRow`, `FlagChip`, `ProgressRing`,
    `ThemePreviewTile` theo `docs/design-system.md` §4–5. Mỗi component có `#Preview`; `ComponentGallery`
    xếp tất cả + picker theme để soát.
  - Xong khi: 👤 mở `ComponentGallery` trong Xcode Preview, đổi 6 theme × sáng/tối, khớp prototype
    artboard "Design system".
  - Phụ thuộc: T2.20

- [x] **T2.22 · Nhập/xuất theme JSON**
  - File: `DS/Sources/DesignSystem/Theme/ThemeLibrary.swift` + test
  - Làm: đọc theme người dùng ở Application Support/Themes, validate (thiếu khoá → lỗi tiếng Việt nêu
    khoá), id trùng built-in → thêm hậu tố; xuất theme ra `Data`.
  - Xong khi: test: file hỏng → lỗi rõ; id trùng → đổi; round-trip.
  - Phụ thuộc: T2.20

### G2 · App Mac

- [x] **T2.30 · 👤 `xcodegen` + chạy khung app** trên macOS 26 (sidebar 5 mục, màn trống).
- [ ] **T2.31 · Lưu trữ + `AppModel`**
  - File: `apple/App/Shared/{AppModel,Persistence}.swift`
  - Làm: SwiftData `@Model` lưu `ContentSnapshot` (JSON blob), hàng đợi, lần học, nháp; cài `LocalStore`.
    `AppModel` (@Observable, @MainActor) cầm `StudyEngine`, `SyncEngine`, phát `StudySessionState`. Lần đầu
    không có cache → nạp `content.sample.json` đóng gói (thêm vào resources của target).
  - Trạng thái: code xong, 2 target build sạch (macOS + iOS Simulator); còn bước 👤 chạy thử (chưa tick).
  - Xong khi: 👤 mở app offline lần đầu thấy dữ liệu mẫu; tắt mở lại vẫn còn.
  - Phụ thuộc: T2.16, T2.30
- [x] **T2.32 · Khung cửa sổ: sidebar + toolbar**
  - Làm: `NavigationSplitView` (sidebar kính hệ thống: 5 màn + bộ ảo ⭐/漢/📖/🔀/🎧), toolbar: tiêu đề màn,
    nút ⌘K, nút theme (xoay vòng), nút sáng/tối; `⌘1…5`; trạng thái đồng bộ ở chân sidebar.
  - Trạng thái: code xong, build sạch; còn bước 👤 soát bố cục (chưa tick). ⌘K mới là nút giữ chỗ (bảng lệnh làm sau); 🎧 Clip nghe tắt tới GĐ3.
  - Xong khi: 👤 khớp bố cục artboard "Mac · Hôm nay"; đổi theme áp ngay toàn app.
  - Phụ thuộc: T2.21, T2.31
- [x] **T2.33 · Cài đặt**
  - Làm: `Settings` scene (`⌘,`): Server (URL + token lưu Keychain + nút "Kiểm tra" gọi `/health` và
    `/content`), Giao diện (lưới `ThemePreviewTile`, sáng/tối/theo hệ thống, nhập/xuất .json), Giọng đọc (TTS ko-KR).
  - Xong khi: 👤 nhập token thật → đồng bộ được với server cloud.
  - Phụ thuộc: T2.22, T2.32
- [ ] **T2.34 · Màn Học — thẻ gõ đáp án**
  - Làm: theo artboard "Mac · Học": thanh tiến độ trên toolbar, `CardSurface` mặt trước lớn, `AnswerField`,
    `GlassActionBar` đổi nút theo trạng thái (Chấm ↵ / Xem đáp án ⌘/ / Đã thuộc ⌘↵ / Đã trả lời đúng? ⌘Z /
    Thẻ tiếp ↵), ô nhập tự focus, bàn phím Hàn không tự đổi (macOS) — ghi chú dùng Input Source.
  - Trạng thái: code xong (`apple/App/Mac/StudyView.swift`), build macOS sạch; còn bước 👤 thử tay (chưa tick).
    Thẻ tự chấm mới có "Đã thuộc"; lật/chấm tay làm ở T2.35.
  - Xong khi: 👤 học trọn một bộ chỉ bằng bàn phím; lần học xuất hiện ở server.
  - Phụ thuộc: T2.32
- [ ] **T2.35 · Màn Học — tự chấm, cờ, cột "Lượt học", TTS**
  - Làm: `Space` lật, `1`/`2` chấm; nút ⭐/漢 (`⇧⌘8`/`⇧⌘H`); cột phải: đã thuộc/đúng/sai + "Sắp hỏi";
    nút ▶︎ đọc mặt sau bằng `AVSpeechSynthesizer` (`⌘.`); ghi chú Markdown dưới đáp án.
  - Xong khi: 👤 thẻ tự chấm + bộ ảo ⭐ hoạt động; cờ bấm offline được gửi khi có mạng.
  - Trạng thái: code xong (Space/1/2, ⭐/漢, cột phải, ▶︎ ⌘.) — còn bước 👤 thử tay (chưa tick).
  - Phụ thuộc: T2.34
- [ ] **T2.36 · Cửa sổ học gọn (`⌥⌘L`)** — `Window` nhỏ, `.windowLevel(.floating)`, chỉ thẻ + ô trả lời.
  - Trạng thái: code xong (⌥⌘L, menu Màn hình) — còn thử tay (chưa tick).
  - Phụ thuộc: T2.35
- [ ] **T2.37 · Màn Hôm nay** — theo artboard: vòng tiến độ, danh sách bộ đến hạn (`ReviewSchedule`), clip
  hôm nay (rỗng tới G3), heatmap 14 ngày, nút "Bắt đầu ôn ↵" mở bộ đến hạn đầu tiên.
  - Trạng thái: code xong (logic `computeTodayPlan` có test; `TodayView`) — còn thử tay (chưa tick). Bỏ ô "Hộp thư Drive" (thuộc T1.09).
  - Phụ thuộc: T2.35
- [ ] **T2.38 · Màn Thư viện** — nhóm → bộ → `Table` thẻ; sửa tại chỗ (PATCH), thêm thẻ `⌘N`, xoá, đổi
  tên/loại/nguồn/mô tả bộ; cần mạng, offline báo lỗi không mất chữ đang sửa.
  - Trạng thái: code xong (`LibraryView` + `AppModel.updateCard/addCard/deleteCard/updateDeck`, ghi qua `ContentAPI` đã có test) — còn thử tay (chưa tick). Server chưa có route xoá bộ nên chỉ xoá được thẻ.
  - Phụ thuộc: T2.32
- [ ] **T2.39 · Màn Nhập từ AI** — theo artboard: chọn loại + công cụ → `⌘⇧C` chép `Prompts.text`; dán JSON
  → `DeckImport` báo lỗi trực tiếp; xem trước + "Trùng"; chọn nhóm; `⌘↵` tạo bộ (`POST /decks`).
  - Xong khi: 👤 chạy trọn quy trình `docs/drive-setup.md` §3 với một bài thật.
  - Trạng thái: code xong (`ImportView`, `AppModel.createDeck`; parse/prompt dùng HanCore đã có test) — còn bước 👤 (chưa tick).
  - Phụ thuộc: T2.38
- [ ] **T2.40 · Command Palette `⌘K`** — overlay kính, tìm không dấu; lệnh: Theme: <6 theme>, bật/tắt tối,
  nhập theme, Học: <bộ>, Đi tới: <màn>; ↑↓ chọn, ↵ chạy, esc đóng.
  - Trạng thái: code xong (`CommandPalette`, `filterBySearch` có test) — còn thử tay (chưa tick).
  - Phụ thuộc: T2.33, T2.37
- [ ] **T2.41 · 👤 Dùng thật 1 tuần** trên Mac thay app Flutter; ghi lỗi/ý vào mục "Phát sinh".

---

## G3 · Clip âm thanh

- [x] **T3.01 · `Clip` trong HanCore**
  - Làm: model `Clip` + decode `clips` trong `/content`; `APIClient` cho `/clips` + upload M4A;
    `StudyWord.kind = .card | .clip(audioId:)`; deck ảo `clips` (🎧); `AnswerMatcher.wordDiff(answer:target:)`
    trả từng từ đúng/sai.
  - Xong khi: test decode, wordDiff (thiếu từ, thừa từ, sai một từ), deck 🎧 dựng đúng.
  - Phụ thuộc: T1.05, T2.16
- [ ] **T3.02 · Mở file + dạng sóng**
  - File: `apple/App/Mac/AudioEditor/{AudioDocument,WaveformExtractor,WaveformView}.swift`
  - Làm: kéo thả / mở file (mp3, m4a, wav), lưu security-scoped bookmark + danh sách "File gần đây"; tách
    biên độ (RMS theo cột) trên luồng nền; `WaveformView` vẽ bằng `Canvas`, zoom `⌘+/⌘−`.
  - Xong khi: 👤 file 15 phút hiện dạng sóng < 2 s.
  - Trạng thái: code xong, build sạch — còn 👤 thử file 15 phút (chưa tick). Cần `cd apple && xcodegen` (thêm
    file entitlements cho bookmark).
  - Phụ thuộc: T2.32
- [ ] **T3.03 · Phát A–B, lặp, tốc độ, phím tắt** — `AVAudioEngine` + `AVAudioUnitTimePitch`; `Space`,
  `[`, `]`, `⌥←/⌥→`, `L`, 0.5/0.75/1×; `GlassActionBar` như artboard.
  - Phụ thuộc: T3.02
  - Trạng thái: code xong, build sạch — chưa thử nghe thật (chưa tick). Phím: Space, `[` `]`, ⌥←/⌥→, L, 5/7/1 (0.5/0.75/1×), ⌘←/⌘→ = ∓2s.
- [ ] **T3.04 · Lưu clip** — form câu Hàn/nghĩa/bộ; `⌘S`: xuất A–B ra M4A (`AVAssetExportSession`,
  `timeRange`) → `POST /audio` (`audio/mp4`) → `POST /clips`; danh sách clip bên phải.
  - Xong khi: 👤 clip mới xuất hiện ở cột phải và trong `/content`.
  - Phụ thuộc: T3.01, T3.03
  - Trạng thái: code xong, build sạch — còn 👤 thử cắt + lưu clip thật lên server (chưa tick).
- [ ] **T3.05 · Luyện clip trong màn Học** — thẻ `.clip`: nút phát/lặp/tốc độ thay mặt trước, ô chép chính
  tả, kết quả tô theo `wordDiff`; Hôm nay hiện "Clip nghe hôm nay".
  - Phụ thuộc: T3.04, T2.37
  - Trạng thái: code xong, build sạch — chưa thử tay (chưa tick). Âm thanh tải từ server, cache ở Caches/Tiramissu/audio.

---

## G4 · iPhone (ưu tiên thấp)

- [ ] **T4.01 · Khung iOS** — `TabView` (Hôm nay · Học · Nghe) dùng chung `AppModel`, `ThemeStore`; tab bar kính hệ thống.
- [ ] **T4.02 · Hôm nay (iOS)** — theo artboard "iPhone · Hôm nay".
- [ ] **T4.03 · Học (iOS)** — theo artboard "iPhone · Học"; bàn phím Hàn khi focus ô trả lời (`.keyboardType`
  không ép được ngôn ngữ — ghi chú cách thêm bàn phím Hàn).
- [ ] **T4.04 · Nghe (iOS)** — theo artboard "iPhone · Nghe": phát clip, lặp, tốc độ, chép chính tả.
- [ ] **T4.05 · 👤 Cài lên iPhone** bằng Apple ID miễn phí; đặt nhắc mỗi 7 ngày cài lại.

---

## G5 · Dọn dẹp

- [ ] **T5.01 · Bỏ `SyncState` + `import-content`** — migration xoá bảng, xoá script + test, cập nhật `docs/backend.md`.
- [ ] **T5.02 · Xuất lại `reference/content.sample.json`** (`npm run export-content` trỏ server cloud) và đóng gói vào app.
- [ ] **T5.03 · README + ảnh chụp màn hình** các màn Mac.
- [ ] **T5.04 · 👤 Archive repo `flashcard-app`** trên GitHub.

---

## Phát sinh

<!-- Agent/bạn ghi việc mới phát hiện ở đây: - [ ] mô tả — ngữ cảnh -->
