# Dựng Google Drive để học

## 1. Cây thư mục

Tạo trong "Drive của tôi":

```
📁 Korean/
├── 00_Inbox/                 ← tài liệu GV vừa gửi / mới tải, chưa xử lý
├── 01_Giáo trình/
│   └── SNU 4A/               ← mỗi khoá một thư mục
│       ├── Bài 07 – Plastic           (Doc ghi chú bài học, theo template §2)
│       └── Bài 07 – Bài tập           (Doc bài làm + phần chữa của GV)
├── 02_Ngữ pháp/              ← mỗi cấu trúc một Doc: "-(으)ㄹ 뿐만 아니라"
├── 03_Nghe/                  ← mỗi nguồn nghe một Doc: link YouTube, ghi chú, câu khó, tên file âm thanh
├── 04_Sổ lỗi sai             ← MỘT Doc, một bảng | Ngày | Sai | Đúng | Lý do |
├── 05_Prompt/                ← chép 4 file trong docs/prompts/ thành 4 Doc
└── 99_Archive/               ← khoá đã học xong
```

Quy ước tên: bắt đầu bằng số bài có 2 chữ số (`Bài 07 – …`) để Drive sắp đúng thứ tự.
Tài liệu GV chia sẻ (chỉ xem): "Tạo bản sao" vào thư mục khoá rồi mới ghi chú lên bản sao.

## 2. Template Doc bài học

Tạo một Doc `Template – Bài học` trong `01_Giáo trình/`, mỗi bài mới: Tệp › Tạo bản sao.
Giữ **nguyên tên heading** (AI và prompt dựa vào chúng):

```
# Bài 07 – Plastic                                    (Heading 1)
Khoá: SNU 4A · Ngày: 13/11 · Nguồn: <link>

## Từ vựng                                            (Heading 2)
<dán đoạn văn / danh sách từ trong bài>

## Ngữ pháp
<mỗi cấu trúc: tên, ý nghĩa, ví dụ của GV>

## Câu mẫu
<câu hay muốn nhớ>

## Bài tập
<link Doc bài tập hoặc dán bài làm>

## Đã đưa vào app ☐
<tick ☑ khi đã nhập thẻ vào Tiramissu; ghi tên bộ trong app>
```

## 3. Quy trình mỗi bài (≈ 10 phút)

1. Học xong buổi → hoàn thiện Doc theo template.
2. Mở Tiramissu (Mac) › **Nhập từ AI** → chọn loại (Từ vựng / Ngữ pháp / Chữa bài / Câu nghe) và công
   cụ (Gemini / NotebookLM) → **Chép prompt** (`⌘⇧C`).
3. **Gemini**: dán prompt + dán phần tương ứng của Doc. **NotebookLM**: notebook của khoá đã có các Doc
   làm source → dán prompt (bản NotebookLM nhắc tên Doc).
4. Chép khối JSON trả về → dán vào app → xem trước (cảnh báo "Trùng") → **Tạo bộ** (`⌘↵`).
5. Prompt "Chữa bài" còn in bảng lỗi → dán vào `04_Sổ lỗi sai`.
6. Quay lại Doc → tick **Đã đưa vào app ☑** + ghi tên bộ.

## 4. NotebookLM

- Mỗi khoá một notebook: `SNU 4A`. Source = các Doc trong thư mục khoá (thêm từ Drive; Doc sửa thì bấm
  đồng bộ lại source).
- Dùng để: hỏi đáp về bài, tạo Audio Overview nghe ôn, chạy prompt bản NotebookLM.

## 5. Âm thanh luyện nghe

- File âm thanh (tự lấy từ YouTube/nguồn khác) để trên Mac: `~/Korean Audio/<Khoá hoặc kênh>/…`
  (m4a/mp3/wav). Không đưa lên Drive — app chỉ đồng bộ **đoạn đã cắt** (vài chục KB).
- Doc trong `03_Nghe/` ghi link gốc + tên file để tìm lại.
