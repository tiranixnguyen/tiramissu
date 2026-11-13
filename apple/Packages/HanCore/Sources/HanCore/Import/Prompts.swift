import Foundation

// Sinh từ docs/prompts/*.md — nguyên văn hai khối ```text (Gemini, NotebookLM). Sửa prompt ở docs rồi sinh lại.

/// Loại prompt: tương ứng một file trong `docs/prompts/`.
public enum PromptKind: String, Sendable, Hashable, CaseIterable {
    case vocab, grammar, fix, listen
}

/// Công cụ AI sẽ nhận prompt.
public enum AITool: String, Sendable, Hashable, CaseIterable {
    case gemini, notebookLM
}

public enum Prompts {
    public static func text(kind: PromptKind, tool: AITool) -> String {
        switch (kind, tool) {
        case (.vocab, .gemini): vocabGemini
        case (.vocab, .notebookLM): vocabNotebookLM
        case (.grammar, .gemini): grammarGemini
        case (.grammar, .notebookLM): grammarNotebookLM
        case (.fix, .gemini): fixGemini
        case (.fix, .notebookLM): fixNotebookLM
        case (.listen, .gemini): listenGemini
        case (.listen, .notebookLM): listenNotebookLM
        }
    }

    private static let vocabGemini = #"""
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
"""#

    private static let vocabNotebookLM = #"""
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
"""#

    private static let grammarGemini = #"""
Bạn là giáo viên tiếng Hàn. Với MỖI cấu trúc ngữ pháp trong phần dưới, tạo 2 thẻ học:
1) "front": "<cấu trúc> — nghĩa là gì, dùng khi nào?", "back": "<ý nghĩa tiếng Việt ngắn gọn>"
2) "front": "<một câu ví dụ tiếng Hàn, thay cấu trúc bằng ___> (<nghĩa tiếng Việt của câu>)", "back": "<câu đầy đủ>"
Mỗi thẻ có "typeAnswer": false và "note": giải thích cách dùng bằng Markdown (cách chia với danh từ/động từ,
lưu ý dễ nhầm, 2 ví dụ ngắn có dịch).

Chỉ trả về MỘT khối JSON, không giải thích gì thêm:
{"name": "Ngữ pháp · <chủ đề>", "words": [{"front": "...", "back": "...", "note": "...", "typeAnswer": false}]}

Phần ngữ pháp:
<DÁN PHẦN "Ngữ pháp" CỦA DOC VÀO ĐÂY>
"""#

    private static let grammarNotebookLM = #"""
Dựa trên source "<TÊN DOC>", phần "Ngữ pháp". Bạn là giáo viên tiếng Hàn. Với MỖI cấu trúc, tạo 2 thẻ:
1) "front": "<cấu trúc> — nghĩa là gì, dùng khi nào?", "back": "<ý nghĩa tiếng Việt ngắn gọn>"
2) "front": "<câu ví dụ tiếng Hàn, thay cấu trúc bằng ___> (<nghĩa tiếng Việt>)", "back": "<câu đầy đủ>"
Mỗi thẻ có "typeAnswer": false và "note": cách dùng bằng Markdown (cách chia, lưu ý dễ nhầm, 2 ví dụ có dịch).
Chỉ trả về MỘT khối JSON, không giải thích gì thêm:
{"name": "Ngữ pháp · <chủ đề>", "words": [{"front": "...", "back": "...", "note": "...", "typeAnswer": false}]}
"""#

    private static let fixGemini = #"""
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
"""#

    private static let fixNotebookLM = #"""
Dựa trên source "<TÊN DOC BÀI TẬP>" (gồm bài làm của mình và phần chữa của giáo viên).
Tìm MỌI lỗi đã được chữa. Với mỗi lỗi tạo một thẻ:
"front": "Sửa câu: <câu sai nguyên văn>", "back": "<câu đúng>", "note": "<vì sao sai, quy tắc, 1 ví dụ> (Markdown)", "typeAnswer": false.
Trả về: 1) MỘT khối ```json {"name": "Lỗi sai · <tên bài>", "words": [...]} ``` rồi 2) bảng | Sai | Đúng | Lý do |.
"""#

    private static let listenGemini = #"""
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
"""#

    private static let listenNotebookLM = #"""
Dựa trên source "<TÊN DOC NGHE>", phần chép lời. Chọn những câu đáng học (bỏ câu chào hỏi, câu quá ngắn).
Mỗi câu một thẻ: "front": "<nghĩa Việt>", "back": "<câu Hàn nguyên văn>", "hint": "<2 âm tiết đầu>…",
"note": "<từ/cấu trúc đáng chú ý> (Markdown)", "typeAnswer": false.
Chỉ trả về MỘT khối JSON: {"name": "Nghe · <tên nguồn>", "words": [...]}
"""#

}
