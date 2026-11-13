# Kiến trúc

## 1. Cây thư mục `apple/`

```
apple/
├── project.yml                         XcodeGen → Tiramissu.xcodeproj (không commit .xcodeproj)
├── Packages/
│   ├── HanCore/                        Swift thuần — KHÔNG import SwiftUI/AppKit/UIKit
│   │   └── Sources/HanCore/
│   │       ├── Models/                 Content (Group/Deck/Card/Clip), StudyWord, CardProgress,
│   │       │                           StudySessionRecord, FlagChange, DeckType
│   │       ├── Study/                  StudyEngine, StudySessionState, VirtualDecks, AnswerMatcher
│   │       ├── Review/                 ReviewSchedule (computeReviewStatus)
│   │       ├── Import/                 DeckImport (parseDeckImport), Prompts (văn bản prompt)
│   │       ├── Sync/                   APIClient, APIError, SyncEngine, PendingQueue
│   │       └── Util/                   SeededGenerator, Clock
│   └── DesignSystem/                   SwiftUI — phụ thuộc HanCore? KHÔNG (độc lập)
│       └── Sources/DesignSystem/
│           ├── Theme/                  Theme (Codable), ThemePalette, ThemeStore (@Observable), Color+Hex
│           ├── Glass/                  GlassBar, GlassSidebarStyle, view modifiers bọc .glassEffect
│           ├── Components/             CardSurface, AnswerField, PrimaryGlassButton, DeckRow,
│           │                           FlagChip, ProgressRing, Kbd (nhãn phím tắt)
│           └── Resources/Themes/       paper.json, ink.json, pine.json, dusk.json, contrast.json, system.json
└── App/
    ├── Shared/                         AppModel (@Observable, cầm StudyEngine + SyncEngine), Persistence
    │                                   (SwiftData), TTS (AVSpeechSynthesizer), CommandPalette
    ├── Mac/                            TiramissuMacApp, MainWindow (NavigationSplitView), Screens/
    │                                   (Today, Study, Library, Import, AudioClip, Settings), AudioEditor/
    └── iOS/                            TiramissuiOSApp, TabView (Today, Study, Listen)
```

Phụ thuộc: `App` → `HanCore` + `DesignSystem`. `HanCore` và `DesignSystem` không phụ thuộc nhau.

## 2. Luồng dữ liệu trong app

```
SwiftData cache ──load──► AppModel ──build──► StudyEngine (HanCore, thuần)
      ▲                      │  ▲                     │
      │ save                 │  │ snapshot()          │ mutating API (checkAnswer, flipCard…)
      │                      ▼  │                     ▼
 SyncEngine ◄──── hàng đợi ── View (SwiftUI) ◄── StudySessionState (struct bất biến)
      │  (FlagChange, StudySessionRecord, thao tác soạn)
      ▼
 APIClient ──HTTPS + Bearer──► backend
```

- View **không** cầm `StudyEngine`; chỉ đọc `StudySessionState` do `AppModel` phát ra sau mỗi hành động
  (giống `_snapshot()` của bản Dart).
- Offline-first giống app cũ (`docs/study-algorithm.md` › Đồng bộ):
  1. Mở app: cache SwiftData → không có thì `content.sample.json` đóng gói → học ngay.
  2. Chốt nháp lần học còn sót thành "học dở".
  3. `syncNow()` chạy nền: gửi hàng đợi → `GET /content` (áp lại ⭐/漢/📖 còn chờ) → `GET /sessions`.
  4. Chạy lại khi có mạng (`NWPathMonitor`), sau mỗi lần học xong, mỗi lần bấm cờ. Không chạy chồng.
- Soạn nội dung (tạo/sửa/xoá nhóm, bộ, thẻ, clip): **cần mạng**, gọi server trước, thành công mới áp
  vào cache.

## 3. Mô hình dữ liệu (Swift ↔ JSON server)

Định dạng JSON giữ nguyên như `GET /content` hiện tại (xem `reference/flutter/models/content.dart`,
`reference/content.sample.json`), thêm `clips`.

```swift
struct ContentSnapshot: Codable { var groups: [ContentGroup]; var decks: [ContentDeck]; var clips: [Clip] = [] }
struct ContentGroup: Codable, Identifiable { let id: String; var name: String; var position: Int }
struct ContentDeck: Codable, Identifiable {
  let id: String; var groupId: String; var name: String; var position: Int
  var type: DeckType?        // listening/speaking/reading/writing/grammar — giá trị lạ → nil
  var source: String?        // GĐ1: enum → chuỗi tự do
  var description: String?; var cards: [ContentCard]
}
struct ContentCard: Codable, Identifiable {
  let id: String; var position: Int; var front: String; var back: String
  var hint: String?; var note: String?; var altAnswers: [String] = []
  var typeAnswer: Bool = false; var marked = false; var hanja = false; var passage = false
  var frontAudioId: String?; var backAudioId: String?; var hintAudioId: String?; var noteAudioId: String?
}
struct Clip: Codable, Identifiable {          // mới (GĐ3)
  let id: String; var audioId: String; var sourceName: String
  var startMs: Int; var endMs: Int; var transcript: String
  var translation: String?; var note: String?; var deckId: String?; var marked = false
  var createdAt: Date
}
struct StudySessionRecord: Codable { let id: String; let deckId: String; let device: String
  let startedAt: Date; let endedAt: Date; let attempted, correct, masteredCount, totalCards: Int; let completed: Bool }
struct FlagChange: Codable { let cardId: String; let changedAt: Date; var marked, hanja, passage: Bool? }
```

Quy ước decode giống bản Dart: thiếu trường → mặc định; `kr`/`vi` cũ → `back`/`front`
(+ `typeAnswer = true`); `parentId` cũ bị bỏ qua. Ngày giờ: ISO-8601 có mili giây.

### Clip trong lượt học

Clip được học như một "thẻ nghe": `StudyWord` thêm `kind: .card | .clip(audioId:)`. Thẻ clip luôn là
gõ đáp án (chép chính tả `transcript`), chấm theo từ (`AnswerMatcher.wordDiff`) nhưng **đúng/sai của
lượt** vẫn so cả câu đã chuẩn hoá → đi chung `StudyEngine`, không cần engine riêng. Deck ảo mới
`clips` (🎧) gom mọi clip; clip có `deckId` cũng xuất hiện trong bộ đó.

## 4. API backend

Base URL cấu hình trong Cài đặt. Mọi route (trừ `/health`) cần `Authorization: Bearer <API_TOKEN>`
(GĐ1). Lỗi luôn là `{ "error": "<thông báo tiếng Việt>" }`.

| Method | Path | Ghi chú |
|---|---|---|
| GET | `/health` | không cần token |
| GET | `/content` | `{ groups, decks (kèm cards), clips }` |
| POST | `/groups` · PATCH `/groups/:id` | tạo / đổi tên nhóm |
| POST | `/decks` · PATCH `/decks/:id` | tạo bộ (kèm `words[]` như JSON nhập) / sửa tên, loại, nguồn, mô tả |
| POST | `/decks/:id/cards` | thêm thẻ vào bộ |
| PATCH · DELETE | `/cards/:id` | sửa / xoá thẻ |
| POST | `/cards/flags` | gửi lô `FlagChange` (last-write-wins theo `changedAt` từng cờ) |
| POST · GET | `/sessions` | lần học — chỉ thêm, id do client sinh (idempotent) |
| POST | `/audio` | bytes thô, `Content-Type: audio/mpeg` hoặc `audio/mp4` (GĐ3), ≤ 2 MB, trùng sha256 → id cũ |
| GET | `/audio/:id` | hỗ trợ `Range`/206, `Cache-Control: immutable` |
| GET · POST · PATCH · DELETE | `/clips`, `/clips/:id` | GĐ3 |

Chi tiết từng route: đọc `backend/src/modules/*/…Routes.ts` và test `*.integration.test.ts`.

## 5. Phím tắt (Mac)

| Màn | Phím |
|---|---|
| Toàn app | `⌘K` Command Palette · `⌘1…5` đổi màn · `⌥⌘D` sáng/tối · `⌥⌘L` cửa sổ học gọn · `⌘,` Cài đặt |
| Học — thẻ gõ | `↵` chấm / thẻ tiếp · `⌘/` xem đáp án · `⌘↵` đã thuộc · `⌘Z` "Đã trả lời đúng?" (sau khi sai) · `⌘.` nghe |
| Học — tự chấm | `Space` lật · `1` chưa nhớ · `2` nhớ · `⌘↵` đã thuộc |
| Học — cờ | `⇧⌘8` ⭐ · `⇧⌘H` 漢 · `⇧⌘P` 📖 |
| Cắt clip | `Space` phát/dừng · `[` A · `]` B · `⌥←/⌥→` ±0.1 s · `L` lặp · `⌘S` lưu · `⌘+/⌘−` zoom |
| Nhập | `⌘⇧C` chép prompt · `⌘↵` tạo bộ |

Bắt phím bằng `.onKeyPress` / `.keyboardShortcut` của SwiftUI ở cấp màn hình; ô nhập tiếng Hàn giữ
`↵` cho chấm bài.
