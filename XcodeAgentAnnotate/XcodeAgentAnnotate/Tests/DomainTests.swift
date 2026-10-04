import AnnotateDomain
import Foundation
import Testing

struct DomainTests {
    @Test func extractsSelectionAndCurrentLine() {
        typealias Position = SourcePosition
        let cases: [(lines: [String], anchor: Position, head: Position, start: Position, end: Position, text: String)] = [
            (["let x = 1\n"], .init(line: 0, column: 4), .init(line: 0, column: 5),
             .init(line: 0, column: 4), .init(line: 0, column: 5), "x"),
            (["first\n", "second\n"], .init(line: 0, column: 2), .init(line: 1, column: 3),
             .init(line: 0, column: 2), .init(line: 1, column: 3), "rst\nsec"),
            (["\t😀e\u{301} = 1\r\n"], .init(line: 0, column: 1), .init(line: 0, column: 5),
             .init(line: 0, column: 1), .init(line: 0, column: 5), "😀e\u{301}"),
            (["hello\r\n"], .init(line: 0, column: 3), .init(line: 0, column: 3),
             .init(line: 0, column: 0), .init(line: 0, column: 5), "hello"),
            (["\r\n"], .init(line: 0, column: 0), .init(line: 0, column: 0),
             .init(line: 0, column: 0), .init(line: 0, column: 0), ""),
            (["last"], .init(line: 0, column: 4), .init(line: 0, column: 4),
             .init(line: 0, column: 0), .init(line: 0, column: 4), "last"),
            (["abc\n", "def\n"], .init(line: 1, column: 2), .init(line: 0, column: 1),
             .init(line: 0, column: 1), .init(line: 1, column: 2), "bc\nde"),
            (["abc\n"], .init(line: 0, column: 0), .init(line: 1, column: 0),
             .init(line: 0, column: 0), .init(line: 1, column: 0), "abc\n"),
        ]
        for item in cases {
            let selection = CodeSelection.extract(from: item.lines, between: item.anchor, and: item.head)
            #expect(selection == CodeSelection(range: SourceRange(item.start, item.end), text: item.text))
        }
        #expect(CodeSelection.extract(from: ["abc"], between: .init(line: 0, column: 0),
                                      and: .init(line: 0, column: 10)) == nil)
    }

    @Test func rendersTheSameClipboardContractAsVSCode() throws {
        let fenced = CodeSelection(range: SourceRange(.init(line: 4, column: 2), .init(line: 5, column: 0)),
                                   text: "let fence = \"````\"\n")
        let annotation = try Annotation(
            reference: CodeReference(file: URL(fileURLWithPath: "/Users/me/Some File.swift"), selection: fenced),
            message: #require(AnnotationMessage("\u{FEFF} Fix this \n"))
        )
        #expect(AgentPrompt.render(annotation) ==
            "File: /Users/me/Some File.swift\nSelection: 5:3-6:1 (1-based, end exclusive)\n\n`````\nlet fence = \"````\"\n\n`````\n\nMessage: Fix this")

        let plain = CodeSelection(range: SourceRange(.init(line: 0, column: 0), .init(line: 0, column: 1)), text: "x")
        let plainAnnotation = try Annotation(
            reference: CodeReference(file: URL(fileURLWithPath: "/a.swift"), selection: plain),
            message: #require(AnnotationMessage("explain"))
        )
        #expect(AgentPrompt.render(plainAnnotation) ==
            "File: /a.swift\nSelection: 1:1-1:2 (1-based, end exclusive)\n\n```\nx\n```\n\nMessage: explain")
    }

    @Test func messagesUseJavaScriptTrimSemantics() {
        #expect(AnnotationMessage(" \t\n\u{FEFF}") == nil)
        #expect(AnnotationMessage("\u{001C}hello\u{001F}")?.text == "\u{001C}hello\u{001F}")
    }

    @Test func excerptShowsWholeDedentedLinesWithTheSelectedColumns() throws {
        let buffer = ["func f() {\n", "        let a = 1\r\n", "\n", "    return a\n", "}\n"]
        let range = SourceRange(.init(line: 1, column: 12), .init(line: 3, column: 6))
        let excerpt = try #require(SourceExcerpt.covering(range, in: buffer))
        #expect(excerpt == SourceExcerpt(firstLine: 1, lines: ["        let a = 1", "", "    return a"]))
        #expect(excerpt.layout(selecting: range) == [
            ExcerptLine(number: 2, text: "    let a = 1", selected: 8 ..< 13),
            ExcerptLine(number: 3, text: "", selected: 0 ..< 0),
            ExcerptLine(number: 4, text: "return a", selected: 0 ..< 2),
        ])
    }

    @Test func excerptOmitsTheLineASelectionEndsBefore() {
        let range = SourceRange(.init(line: 0, column: 0), .init(line: 1, column: 0))
        #expect(SourceExcerpt.covering(range, in: ["abc\n", "def\n"]) == SourceExcerpt(firstLine: 0, lines: ["abc"]))
        #expect(SourceExcerpt.covering(SourceRange(.init(line: 5, column: 0), .init(line: 5, column: 1)),
                                       in: ["abc\n"]) == nil)
    }
}
