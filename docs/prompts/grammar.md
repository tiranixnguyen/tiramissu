# Prompt — Ngữ pháp

Tạo **thẻ tự chấm** (`typeAnswer: false`): cấu trúc → ý nghĩa, và câu đục lỗ → câu đầy đủ.

## Bản Gemini

```text
Bạn là giáo viên tiếng Hàn. Với MỖI cấu trúc ngữ pháp trong phần dưới, tạo 2 thẻ học:
1) "front": "<cấu trúc> — nghĩa là gì, dùng khi nào?", "back": "<ý nghĩa tiếng Việt ngắn gọn>"
2) "front": "<một câu ví dụ tiếng Hàn, thay cấu trúc bằng ___> (<nghĩa tiếng Việt của câu>)", "back": "<câu đầy đủ>"
Mỗi thẻ có "typeAnswer": false và "note": giải thích cách dùng bằng Markdown (cách chia với danh từ/động từ,
lưu ý dễ nhầm, 2 ví dụ ngắn có dịch).

Chỉ trả về MỘT khối JSON, không giải thích gì thêm:
{"name": "Ngữ pháp · <chủ đề>", "words": [{"front": "...", "back": "...", "note": "...", "typeAnswer": false}]}

Phần ngữ pháp:
<DÁN PHẦN "Ngữ pháp" CỦA DOC VÀO ĐÂY>
```

## Bản NotebookLM

```text
Dựa trên source "<TÊN DOC>", phần "Ngữ pháp". Bạn là giáo viên tiếng Hàn. Với MỖI cấu trúc, tạo 2 thẻ:
1) "front": "<cấu trúc> — nghĩa là gì, dùng khi nào?", "back": "<ý nghĩa tiếng Việt ngắn gọn>"
2) "front": "<câu ví dụ tiếng Hàn, thay cấu trúc bằng ___> (<nghĩa tiếng Việt>)", "back": "<câu đầy đủ>"
Mỗi thẻ có "typeAnswer": false và "note": cách dùng bằng Markdown (cách chia, lưu ý dễ nhầm, 2 ví dụ có dịch).
Chỉ trả về MỘT khối JSON, không giải thích gì thêm:
{"name": "Ngữ pháp · <chủ đề>", "words": [{"front": "...", "back": "...", "note": "...", "typeAnswer": false}]}
```
