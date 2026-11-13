# Ghi chú backend

## `src/config/db.ts` — ba lỗi tiềm ẩn đã vá, đừng gỡ

1. Import `PrismaClient` từ `../../prisma/generated/prisma/client`, **không
   phải** thư mục `.../generated/prisma` (không có `index.ts`/`package.json`
   nên không resolve được).
2. Prisma 7 bắt buộc driver adapter (`@prisma/adapter-pg`) — thiếu thì throw ở
   query đầu tiên, không phải lúc construct.
3. Tự gọi `dotenv.config()` trong `db.ts` — `src/index.ts` không load `.env`,
   chỉ `prisma.config.ts` (cho CLI) có. Thiếu thì `DATABASE_URL` là
   `undefined` lúc `npm run dev` dù CLI Prisma chạy bình thường. Dùng
   `import dotenv from "dotenv"; dotenv.config();` — `import "dotenv/config"`
   thiếu khai báo kiểu dưới resolver của project.

## Cấu trúc

- `src/modules/common/` — `defaultUser` (user cố định, chưa có auth),
  `httpError` (`HttpError(status, message)`), `handle` (bọc route: lấy user,
  đổi `HttpError` → mã HTTP, lỗi khác → 500 có log). Lỗi ném trước khi vào
  `handle()` (body-parser: body quá lớn, JSON hỏng) do middleware cuối
  `app.ts` đổi thành `{ error }` — mặc định Express trả HTML, app không đọc được.
- `src/modules/content/` — `/content`, `/groups`, `/decks`, `/cards`,
  `/cards/flags`. `wordInput.ts` kiểm tra + dọn JSON nhập bộ.
- `src/modules/audio/` — `POST /audio`, `GET /audio/:id` (file nghe, xem
  "File nghe" bên dưới).
- `src/modules/clips/` — `/clips` (GET/POST/PATCH/DELETE): đoạn cắt từ file nghe M4A.
  `start < end`, ≤ 60 s, `transcript` bắt buộc ≤ 500 ký tự, audio/bộ phải của user.
  `audioId` FK `Restrict` (không xoá được audio còn clip); xoá bộ → `deckId = null`.
  `GET /content` trả thêm `clips`; `prune-audio` giữ audio còn clip.
- `src/modules/common/auth.ts` — `Authorization: Bearer <API_TOKEN>` cho mọi route
  trừ `/health`; production thiếu `API_TOKEN` thì server không khởi động.
- `src/modules/sessions/` — `/sessions` (chỉ thêm, id do client sinh).
- `src/scripts/` — `importContent` (một lần, DB mới), `exportContent` (DB →
  `reference/content.sample.json`, chỉ đọc), `pruneAudio` (dọn file nghe mồ
  côi).

## Dữ liệu

Nguồn đúng là DB (`Group`/`Deck`/`Card`/`StudySession`). File JSON chỉ là điểm
khởi đầu / bản sao:

- `Card` có `front` (mặt trước, câu hỏi), `back` (mặt sau, đáp án) và
  `typeAnswer` (gõ đáp án / tự chấm, mặc định tự chấm). Trước đây là `kr`/`vi`
  — migration `card_front_back_type_answer` đổi tên cột (giữ dữ liệu) và bật
  `typeAnswer` cho thẻ có `back` ≤ 3 từ. JSON nhập bộ (`POST /decks`,
  `/decks/:id/cards`) dùng `front`/`back`, `typeAnswer` không bắt buộc (thiếu
  thì theo `defaultTypeAnswer` trong `wordInput.ts`). `PATCH /cards/:id` không
  gửi `typeAnswer` thì giữ nguyên. `note` (giải thích đáp án, Markdown, không
  bắt buộc): lưu nguyên văn, chỉ bỏ dòng trống đầu + khoảng trắng cuối và đổi
  CRLF (`cleanNote`); PATCH thiếu `note` thì giữ nguyên, `null`/rỗng là xoá. App vẫn đọc được cache cũ `kr`/`vi` trên
  máy (coi là thẻ gõ đáp án) tới lần đồng bộ sau.
- `Deck.type` (enum `DeckType`, không bắt buộc): `listening`/`speaking`/
  `reading`/`writing`/`grammar` — client hiển thị 듣기/말하기/읽기/쓰기/문법.
  Lưu khoá ASCII để đổi nhãn không cần migration; app gặp giá trị lạ thì coi
  như chưa phân loại.
- `Deck.source` (`String?`, không bắt buộc) — "Tài liệu": chuỗi tự do ≤ 40 ký tự
  (vd `SNU 4A`), bỏ khoảng trắng hai đầu, rỗng → `null`, quá dài / không phải
  chữ → 400 (`parseDeckSource`). Trước đây là enum `DeckSource`; migration
  `deck_source_free_text` đổi `snu3a` → `SNU 3A` … `thth4` → `THTH 4`.
- `Deck.description` (không bắt buộc): chữ thuần ≤ 500 ký tự, bỏ khoảng trắng
  hai đầu + đổi CRLF, rỗng → `null` (`parseDescription`). App tự biến link
  `http(s)://` thành link bấm được (chỉ Mac/web).
- `POST /decks` nhận thêm `type`, `source`, `description`. `PATCH /decks/:id`
  `{ name?, type?, source?, description? }`: thiếu trường = giữ, `null` = xoá (`name`
  không xoá được: rỗng/`null`/quá 120 ký tự → 400), giá trị sai hoặc body không
  có trường nào → 400.
- `prisma/seed-data/decks.json` — 28 bộ gốc (574 mục, 3 nhóm), **định dạng cũ
  `kr`/`vi`** (`importContent.ts` tự chuyển sang `back`/`front`). Chỉ `npm run
  import-content` đọc, cùng chỉnh sửa/⭐/漢 thật từ bảng `SyncState` cũ (không có
  thì `seed-data/vocab-state.json`). Chỉ chạy khi user **chưa có nhóm nào**.
- `reference/content.sample.json` — bản xuất từ DB, định dạng `GET /content`.
  **Xuất lại** (`npm run export-content`) trước khi build bản phát hành; không
  sửa tay.
- Id: bộ gốc cố định (`g1..g3`, `ds1..ds30`, thẻ `<deckId>-<vị trí lúc
  import>`) để bản đóng gói khớp server; nhóm/bộ mới dùng cuid; thẻ mới dùng
  uuid (ghi cả lô bằng một lệnh `createMany`).
- Schema cũ SM-2 (`UserCardProgress`, `LanguagePair`…) đã bỏ. `SyncState` chỉ
  còn cho `import-content`; xoá được khi chắc không cần import lại. `pg_dump`
  trước khi đổi schema nằm ở `backups/`.

## File nghe

- Bảng `Audio`: bytes MP3 nằm thẳng trong Postgres (bytea) — `pg_dump` sao lưu
  luôn, không phải đồng bộ thêm thư mục nào. Clip ~20–30 giây ~400 KB; lên cỡ
  chục nghìn clip thì nên chuyển sang lưu file trên đĩa (chỉ đổi
  `audioService.ts`, API giữ nguyên).
- `POST /audio`: thân request là **bytes thô** `Content-Type: audio/mpeg`
  (không multipart → không cần `multer`). Nhận MP3 (đoán theo byte đầu:
  thẻ `ID3` hoặc khung MPEG) và M4A (`ftyp` ở byte 4, lưu `mime = audio/mp4`; `GET` trả
  đúng `Content-Type` theo `mime`); file khác → 415, tối đa `AUDIO_MAX_BYTES` (mặc định 2 MB). Trùng
  sha256 (theo user) thì trả lại id cũ.
- `GET /audio/:id`: nội dung của id không bao giờ đổi → `Cache-Control:
  immutable` + `ETag`. **Phải hỗ trợ `Range`/206** — AVPlayer (just_audio trên
  macOS/iOS) không chịu phát file HTTP nếu server không trả theo byte range.
- `Card.frontAudioId`/`backAudioId`/`hintAudioId`/`noteAudioId`
  (`onDelete: SetNull`). `PATCH /cards/:id`: thiếu trường = giữ, `null` = gỡ, id
  lạ/của user khác = 400.
- Gỡ file, xoá thẻ, hay tải lên rồi huỷ dialog đều để lại file mồ côi — không
  route nào tự xoá. `npm run prune-audio -- --dry-run` để xem, bỏ `--dry-run`
  để xoá (chỉ file > 1 ngày, tránh xoá file vừa tải lên mà dialog còn mở).
- Dự kiến sau này: nghe chép chính tả từng câu của đoạn hội thoại ngắn — nên là
  mô hình riêng (vd `Dialogue` → `Line { text, audioId }`) dùng lại bảng
  `Audio`, không nhét vào `Card`.

## ⚠ Route ghi trên server dev

Smoke test ghi bằng tay trên server dev từng **ghi đè mất dữ liệu thật** của
`DEFAULT_USER_EMAIL` (server dev dùng đúng email thật). Muốn tự curl
POST/PATCH/DELETE: `pg_dump` trước (xem `backups/`) hoặc chạy server với
`DEFAULT_USER_EMAIL` khác. GET thì thoải mái. `npx vitest run` luôn an toàn.

## Deploy

Chạy miễn phí: Postgres trên **Neon**, API trên **Render** (Docker). Render free ngủ sau
~15 phút không có request → request đầu mất ~30–60 s; app phải chịu được (đã offline-first).

### 1. Neon (Postgres)

1. Tạo project tại neon.tech (region gần nhất, Postgres 16).
2. Lấy **connection string** (dạng `postgresql://user:pass@ep-xxx.neon.tech/neondb?sslmode=require`).
   Dùng bản *pooled* hoặc *direct* đều được; `prisma migrate deploy` chạy ổn với direct — nếu
   migrate treo, đổi sang direct.

### 2. Sinh token

```bash
openssl rand -hex 32
```

Lưu vào trình quản lý mật khẩu — đây là `API_TOKEN` (server) và token nhập trong Cài đặt app.

### 3. Render (web service)

1. Đẩy repo lên GitHub → Render › New › **Blueprint** → chọn repo (đọc `render.yaml` ở gốc).
2. Điền hai biến `sync: false`: `DATABASE_URL` (Neon) và `API_TOKEN`.
3. Deploy. Khi khởi động container chạy `npx prisma migrate deploy` rồi `node dist/src/index.js`
   (nghe `PORT` do Render đặt). Health check: `GET /health`.
4. Thử:

```bash
curl https://<app>.onrender.com/health
curl -H "Authorization: Bearer <API_TOKEN>" https://<app>.onrender.com/content
```

`NODE_ENV=production` mà thiếu `API_TOKEN` → server từ chối khởi động (cố ý).

### 4. Chuyển dữ liệu local → Neon

Dump từ Postgres local (tên DB `tiramissu_dev` hoặc DB cũ của `flashcard-app`):

```bash
pg_dump --format=custom --no-owner --no-acl \
  "postgresql://postgres:postgres@localhost:5432/tiramissu_dev" -f tiramissu.dump
```

Restore lên Neon (DB trống — **chưa** để server chạy migrate trước, hoặc thêm `--clean --if-exists`):

```bash
pg_restore --no-owner --no-acl --clean --if-exists \
  -d "<chuỗi kết nối Neon>" tiramissu.dump
```

Nếu dump từ DB `flashcard-app` cũ (schema chưa có `Clip`, `Deck.source` còn là enum), cứ restore
rồi để Render chạy `migrate deploy` lần đầu — nó áp các migration còn thiếu. Kiểm tra bằng
`curl` ở bước 3 thấy đủ nhóm/bộ.

### Chạy local bằng Docker (thử image)

```bash
docker build -t tiramissu-api backend
docker run --rm -p 3000:3000 -e DATABASE_URL=... -e API_TOKEN=... tiramissu-api
```
