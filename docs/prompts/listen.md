# Prompt — Câu nghe

Từ phần chép lời / phụ đề của một đoạn nghe: mỗi câu khó một thẻ **nghĩa Việt → câu Hàn**.
(Clip âm thanh thì cắt trong app — màn Cắt clip; prompt này chỉ tạo thẻ chữ đi kèm.)

## Bản Gemini

```text
Dưới đây là phần chép lời (phụ đề) tiếng Hàn của một đoạn nghe mình thấy khó.
Chọn những câu đáng học (bỏ câu chào hỏi, câu quá ngắn). Với mỗi câu tạo một thẻ:
- "front": "<nghĩa tiếng Việt tự nhiên>"
- "back": "<câu tiếng Hàn nguyên văn, sửa lỗi chính tả của phụ đề tự động nếu có>"
- "hint": "<2 âm tiết đầu của câu>…"
- "note": "<từ/cấu trúc đáng chú ý trong câu> (Markdown)"
- "typeAnswer": false
Chỉ trả về MỘT khối JSON, không giải thích gì thêm:
{"name": "Nghe · <tên nguồn>", "words": [...]}

Phần chép lời:
<DÁN PHỤ ĐỀ / CHÉP LỜI>
```

## Bản NotebookLM

```text
Dựa trên source "<TÊN DOC NGHE>", phần chép lời. Chọn những câu đáng học (bỏ câu chào hỏi, câu quá ngắn).
Mỗi câu một thẻ: "front": "<nghĩa Việt>", "back": "<câu Hàn nguyên văn>", "hint": "<2 âm tiết đầu>…",
"note": "<từ/cấu trúc đáng chú ý> (Markdown)", "typeAnswer": false.
Chỉ trả về MỘT khối JSON: {"name": "Nghe · <tên nguồn>", "words": [...]}
```
