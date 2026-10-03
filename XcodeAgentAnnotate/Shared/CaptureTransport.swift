import AppKit

enum CaptureTransport {
    static let scheme = "xcode-agent-annotate"
    static let lifetime: TimeInterval = 60
    private static let maximumPayloadSize = 16 * 1024 * 1024
    private static let type = NSPasteboard.PasteboardType("dev.tuist.XcodeAgentAnnotate.capture")

    private static func pasteboard(_ token: UUID) -> NSPasteboard {
        NSPasteboard(name: .init("dev.tuist.XcodeAgentAnnotate.capture.\(token.uuidString)"))
    }

    static func publish(_ request: CaptureRequest) throws -> (url: URL, token: UUID) {
        let data = try JSONEncoder().encode(request)
        guard data.count <= maximumPayloadSize else { throw CaptureError.payloadTooLarge }
        let token = UUID()
        let board = pasteboard(token)
        board.clearContents()
        guard board.setData(data, forType: type) else {
            board.releaseGlobally()
            throw CaptureError.handoffFailed
        }
        // Only an opaque token is put in the URL; the general clipboard is never touched.
        let url = URL(string: "\(scheme)://capture/\(token.uuidString)")!
        DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) { discard(token) }
        return (url, token)
    }

    static func consume(_ url: URL) throws -> CaptureRequest {
        guard url.scheme == scheme, url.host == "capture", url.query == nil, url.fragment == nil,
              url.pathComponents.count == 2, let token = UUID(uuidString: url.lastPathComponent)
        else {
            throw CaptureError.invalidRequest
        }
        let board = pasteboard(token)
        defer { board.releaseGlobally() }
        guard let data = board.data(forType: type), data.count <= maximumPayloadSize else {
            throw CaptureError.invalidRequest
        }
        let request = try JSONDecoder().decode(CaptureRequest.self, from: data)
        let age = Date().timeIntervalSince(request.createdAt)
        guard age >= -5, age <= lifetime else { throw CaptureError.invalidRequest }
        return request
    }

    static func discard(_ token: UUID) {
        pasteboard(token).releaseGlobally()
    }
}
