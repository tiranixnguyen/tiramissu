# Test

## Apple — `swift test` (trong `apple/Packages/HanCore`, `apple/Packages/DesignSystem`)

- Test Swift viết bằng **Swift Testing** (`import Testing`, `@Test`, `#expect`).
- Test của `HanCore` là bản port 1-1 của test Dart gốc trong `reference/flutter/test/`:
  - `study_engine_test.dart` → `Tests/HanCoreTests/StudyEngineTests.swift`
  - `review_schedule_test.dart` → `ReviewScheduleTests.swift`
  - `deck_import_test.dart` → `DeckImportTests.swift`
  - `support/fixtures.dart` → `Tests/HanCoreTests/Support/Fixtures.swift`
  Giữ nguyên tên ca kiểm thử (dịch sang tên hàm Swift) để đối chiếu được.
- Random luôn tiêm vào (`SeededGenerator`), không dùng `SystemRandomNumberGenerator` trong test.
- Đồng hồ tiêm vào (`now: () -> Date`, `Calendar` cố định múi giờ `Asia/Ho_Chi_Minh`) — gợi ý ôn
  lại so theo **ngày lịch** địa phương.
- `DesignSystem`: test giải mã cả 6 file theme trong `Resources/Themes/`, đủ khoá, mã màu hợp lệ,
  độ tương phản `ink`/`bg` ≥ 4.5:1 ở cả sáng và tối.
- UI (SwiftUI) không có snapshot test ở giai đoạn đầu — kiểm tra tay theo checklist trong
  `docs/tasks.md` (mục "Xong khi" của từng màn).

Nhánh dễ hỏng nhất của engine (đều có test gốc, đừng làm gãy khi port): tự xác nhận đúng (hoàn tác
nhánh sai), mang tiến trình theo id khi nội dung đổi giữa lượt, ⭐/漢 trong hàng đợi áp lại lên nội
dung vừa tải, bỏ cờ ngay trong deck ⭐/漢 (thẻ ở lại tới khi sang thẻ tiếp rồi rơi hẳn —
`pruneUnflagged`), bộ rỗng hiện màn "chưa có thẻ".

## Backend — `npx vitest run` (cần `docker compose up -d`)

- `wordInput.test.ts`, `importContent.test.ts` — thuần (import chạy trên
  `seed-data/` thật).
- `audioService.test.ts` — thuần: nhận diện MP3, tách header `Range`.
- `content.integration.test.ts`, `sessions.integration.test.ts`,
  `audio.integration.test.ts` — Express app
  thật + Postgres dev thật (`useTestServer()` + `fetch`, không mock Prisma).
  An toàn vì `vitest.setup.ts` đổi `DEFAULT_USER_EMAIL` sang email test trước
  khi module nào nạp; `useTestServer()` từ chối chạy nếu email không chứa
  "test". `fileParallelism: false` vì các file cùng dọn/ghi một user test.
