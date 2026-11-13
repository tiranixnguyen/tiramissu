import Foundation
import Testing

@testable import HanCore

@Suite("Prompts")
struct PromptsTests {
    @Test func tamToHopKhongRong() {
        for kind in PromptKind.allCases {
            for tool in AITool.allCases {
                #expect(!Prompts.text(kind: kind, tool: tool).isEmpty)
            }
        }
        #expect(PromptKind.allCases.count * AITool.allCases.count == 8)
    }

    @Test func banGeminiCoPlaceholder() {
        for kind in PromptKind.allCases {
            #expect(Prompts.text(kind: kind, tool: .gemini).contains("<DÁN"))
        }
    }

    @Test func banNotebookLMCoSource() {
        for kind in PromptKind.allCases {
            let t = Prompts.text(kind: kind, tool: .notebookLM)
            #expect(t.contains("source"))
            #expect(!t.contains("<DÁN"))
        }
    }

    @Test func nguyenVanKhopDoc() throws {
        // vocab/Gemini bắt đầu đúng như trong docs/prompts/vocab.md.
        let t = Prompts.text(kind: .vocab, tool: .gemini)
        #expect(t.hasPrefix("Tách đoạn tiếng Hàn bên dưới"))
        #expect(t.contains("\"front\""))
    }
}
