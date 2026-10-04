import AnnotateDomain
import AnnotateHandoff
import AppKit
import Testing

struct HandoffTests {
    @Test @MainActor func handoffIsSingleUseAndDoesNotTouchGeneralClipboard() throws {
        let clipboardVersion = NSPasteboard.general.changeCount
        let selection = CodeSelection(range: SourceRange(.init(line: 0, column: 0), .init(line: 0, column: 6)),
                                      text: "secret")
        let request = CaptureRequest(selection: selection, excerpt: SourceExcerpt(firstLine: 0, lines: [selection.text]),
                                     isCurrentLine: false, xcodeProcessID: 123,
                                     bufferDigest: CaptureRequest.digest("secret"), createdAt: Date())
        let handoff = try CaptureTransport.publish(request)
        defer { CaptureTransport.discard(handoff.token) }
        #expect(!handoff.url.absoluteString.contains("secret"))
        let received = try CaptureTransport.consume(handoff.url)
        #expect(received.selection == selection)
        #expect(received.bufferDigest == request.bufferDigest)
        #expect(received.xcodeProcessID == 123)
        #expect(throws: CaptureError.self) { try CaptureTransport.consume(handoff.url) }
        #expect(NSPasteboard.general.changeCount == clipboardVersion)
    }

    @Test @MainActor func rejectsExpiredAndUnrelatedHandoffs() throws {
        let selection = CodeSelection(range: SourceRange(.init(line: 0, column: 0), .init(line: 0, column: 1)),
                                      text: "x")
        let request = CaptureRequest(selection: selection, excerpt: SourceExcerpt(firstLine: 0, lines: [selection.text]),
                                     isCurrentLine: false, xcodeProcessID: 123, bufferDigest: "digest",
                                     createdAt: Date().addingTimeInterval(-120))
        let handoff = try CaptureTransport.publish(request)
        defer { CaptureTransport.discard(handoff.token) }
        #expect(throws: CaptureError.self) { try CaptureTransport.consume(handoff.url) }
        #expect(throws: CaptureError.self) {
            try CaptureTransport.consume(#require(URL(string: "xcode-agent-annotate://capture/general")))
        }
    }
}
