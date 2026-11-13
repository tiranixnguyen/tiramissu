# Prompt — Từ vựng

Tạo thẻ **nghĩa Việt → từ/cụm Hàn** (gõ đáp án). Phát triển từ `deckExtractionPrompt` của app cũ
(`reference/flutter/domain/deck_import.dart`). App nhúng nguyên văn hai khối dưới (`HanCore/Import/Prompts.swift`).

## Bản Gemini

```text
Tách đoạn tiếng Hàn bên dưới thành danh sách từ vựng để học (Hàn → Việt).
Chỉ trả về MỘT khối JSON, không giải thích gì thêm, đúng định dạng:
{"name": "<tên bộ ngắn gọn, tiếng Việt>", "words": [{"front": "<nghĩa tiếng Việt ngắn gọn>", "back": "<từ/biểu hiện tiếng Hàn>"}]}

Quy tắc:
- Ưu tiên các biểu hiện, collocation, cụm từ quan trọng, thường được sử dụng, rồi mới tới từ vựng đứng đơn lẻ.
- Bỏ số, tên riêng; không lặp từ.
- Động từ/tính từ đưa về dạng nguyên thể (-다).
- Từ Hán Hàn: thêm "note": "Hán Hàn: <chữ Hán>".
- Nếu có cách viết khác cũng đúng, thêm "altAnswers": ["..."].

Đoạn văn:
<DÁN PHẦN "Từ vựng" CỦA DOC VÀO ĐÂY>
```

## Bản NotebookLM

```text
Dựa trên source "<TÊN DOC, vd Bài 07 – Plastic>", phần "Từ vựng":
tách thành danh sách từ vựng để học (Hàn → Việt).
Chỉ trả về MỘT khối JSON, không giải thích gì thêm, đúng định dạng:
{"name": "<tên bộ ngắn gọn, tiếng Việt>", "words": [{"front": "<nghĩa tiếng Việt ngắn gọn>", "back": "<từ/biểu hiện tiếng Hàn>"}]}

Quy tắc:
- Ưu tiên các biểu hiện, collocation, cụm từ quan trọng, thường được sử dụng, rồi mới tới từ vựng đứng đơn lẻ.
- Bỏ số, tên riêng; không lặp từ.
- Động từ/tính từ đưa về dạng nguyên thể (-다).
- Từ Hán Hàn: thêm "note": "Hán Hàn: <chữ Hán>".
- Nếu có cách viết khác cũng đúng, thêm "altAnswers": ["..."].
```

## Ví dụ kết quả

```json
{"name": "Plastic · tái chế",
 "words": [
  {"front": "tái chế chai nhựa", "back": "플라스틱 병을 재활용하다"},
  {"front": "tái chế", "back": "재활용하다", "note": "Hán Hàn: 再活用"}
 ]}
```
