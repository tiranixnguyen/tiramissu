# Prompt — Chữa bài tập

Từ bài làm + phần chữa của giáo viên: mỗi lỗi một thẻ **câu sai → câu đúng**, kèm bảng cho
`04_Sổ lỗi sai`. App chỉ đọc khối JSON đầu tiên (bỏ qua bảng phía sau).

## Bản Gemini

```text
Dưới đây là bài viết tiếng Hàn của mình và phần chữa của giáo viên.
Tìm MỌI lỗi đã được chữa. Với mỗi lỗi tạo một thẻ:
- "front": "Sửa câu: <câu mình viết sai, nguyên văn>"
- "back": "<câu đúng theo giáo viên>"
- "note": "<vì sao sai, quy tắc liên quan, 1 ví dụ đúng khác> (Markdown, tiếng Việt)"
- "typeAnswer": false

Trả về theo đúng thứ tự:
1. MỘT khối ```json {"name": "Lỗi sai · <tên bài>", "words": [...]} ```
2. Sau đó một bảng Markdown | Sai | Đúng | Lý do | (mỗi lỗi một dòng) để mình dán vào Sổ lỗi sai.

Bài làm:
<DÁN BÀI LÀM>

Phần chữa của giáo viên:
<DÁN PHẦN CHỮA>
```

## Bản NotebookLM

```text
Dựa trên source "<TÊN DOC BÀI TẬP>" (gồm bài làm của mình và phần chữa của giáo viên).
Tìm MỌI lỗi đã được chữa. Với mỗi lỗi tạo một thẻ:
"front": "Sửa câu: <câu sai nguyên văn>", "back": "<câu đúng>", "note": "<vì sao sai, quy tắc, 1 ví dụ> (Markdown)", "typeAnswer": false.
Trả về: 1) MỘT khối ```json {"name": "Lỗi sai · <tên bài>", "words": [...]} ``` rồi 2) bảng | Sai | Đúng | Lý do |.
```
