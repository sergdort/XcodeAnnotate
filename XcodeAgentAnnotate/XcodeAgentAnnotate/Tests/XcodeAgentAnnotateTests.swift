import AppKit
import Testing

struct XcodeAgentAnnotateTests {
    @Test func extractsSelectionAndCurrentLine() throws {
        let cases: [(lines: [String], start: SourcePosition, end: SourcePosition, expected: CodeCapture)] = [
            (["let x = 1\n"], .init(line: 0, column: 4), .init(line: 0, column: 5),
             .init(start: .init(line: 0, column: 4), end: .init(line: 0, column: 5), snippet: "x")),
            (["first\n", "second\n"], .init(line: 0, column: 2), .init(line: 1, column: 3),
             .init(start: .init(line: 0, column: 2), end: .init(line: 1, column: 3), snippet: "rst\nsec")),
            (["\t😀e\u{301} = 1\r\n"], .init(line: 0, column: 1), .init(line: 0, column: 5),
             .init(start: .init(line: 0, column: 1), end: .init(line: 0, column: 5), snippet: "😀e\u{301}")),
            (["hello\r\n"], .init(line: 0, column: 3), .init(line: 0, column: 3),
             .init(start: .init(line: 0, column: 0), end: .init(line: 0, column: 5), snippet: "hello")),
            (["\r\n"], .init(line: 0, column: 0), .init(line: 0, column: 0),
             .init(start: .init(line: 0, column: 0), end: .init(line: 0, column: 0), snippet: "")),
            (["last"], .init(line: 0, column: 4), .init(line: 0, column: 4),
             .init(start: .init(line: 0, column: 0), end: .init(line: 0, column: 4), snippet: "last")),
            (["abc\n", "def\n"], .init(line: 1, column: 2), .init(line: 0, column: 1),
             .init(start: .init(line: 0, column: 1), end: .init(line: 1, column: 2), snippet: "bc\nde")),
            (["abc\n"], .init(line: 0, column: 0), .init(line: 1, column: 0),
             .init(start: .init(line: 0, column: 0), end: .init(line: 1, column: 0), snippet: "abc\n")),
        ]
        for item in cases {
            let capture = try CodeCapture.capture(lines: item.lines, start: item.start, end: item.end)
            #expect(capture == item.expected)
        }
        #expect(throws: CaptureError.self) {
            try CodeCapture.capture(lines: ["abc"], start: .init(line: 0, column: 0),
                                    end: .init(line: 0, column: 10))
        }
    }

    @Test func formatsTheSameClipboardContractAsVSCode() {
        let capture = CodeCapture(start: .init(line: 4, column: 2), end: .init(line: 5, column: 0),
                                  snippet: "let fence = \"````\"\n")
        #expect(capture.annotation(path: "/Users/me/Some File.swift", message: "\u{FEFF} Fix this \n") ==
            "File: /Users/me/Some File.swift\nSelection: 5:3-6:1 (1-based, end exclusive)\n\n`````\nlet fence = \"````\"\n\n`````\n\nMessage: Fix this")
        #expect(CodeCapture.trimMessage(" \t\n\u{FEFF}").isEmpty)
        #expect(CodeCapture.trimMessage("\u{001C}hello\u{001F}") == "\u{001C}hello\u{001F}")
        let plain = CodeCapture(start: .init(line: 0, column: 0), end: .init(line: 0, column: 1), snippet: "x")
        #expect(plain.annotation(path: "/a.swift", message: "explain") ==
            "File: /a.swift\nSelection: 1:1-1:2 (1-based, end exclusive)\n\n```\nx\n```\n\nMessage: explain")
    }

    @Test @MainActor func handoffIsSingleUseAndDoesNotTouchGeneralClipboard() throws {
        let clipboardVersion = NSPasteboard.general.changeCount
        let capture = CodeCapture(start: .init(line: 0, column: 0), end: .init(line: 0, column: 6), snippet: "secret")
        let request = CaptureRequest(capture: capture, xcodeProcessID: 123,
                                     bufferDigest: CaptureRequest.digest("secret"), createdAt: Date())
        let handoff = try CaptureTransport.publish(request)
        defer { CaptureTransport.discard(handoff.token) }
        #expect(!handoff.url.absoluteString.contains("secret"))
        let received = try CaptureTransport.consume(handoff.url)
        #expect(received.capture == capture)
        #expect(received.bufferDigest == request.bufferDigest)
        #expect(received.xcodeProcessID == 123)
        #expect(throws: CaptureError.self) { try CaptureTransport.consume(handoff.url) }
        #expect(NSPasteboard.general.changeCount == clipboardVersion)
    }

    @Test @MainActor func rejectsExpiredAndUnrelatedHandoffs() throws {
        let capture = CodeCapture(start: .init(line: 0, column: 0), end: .init(line: 0, column: 1), snippet: "x")
        let request = CaptureRequest(capture: capture, xcodeProcessID: 123, bufferDigest: "digest",
                                     createdAt: Date().addingTimeInterval(-120))
        let handoff = try CaptureTransport.publish(request)
        defer { CaptureTransport.discard(handoff.token) }
        #expect(throws: CaptureError.self) { try CaptureTransport.consume(handoff.url) }
        #expect(throws: CaptureError.self) {
            try CaptureTransport.consume(#require(URL(string: "xcode-agent-annotate://capture/general")))
        }
    }
}
