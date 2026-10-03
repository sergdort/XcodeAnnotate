import AnnotateDomain
import AnnotateFeature
import AnnotateHandoff
import AppKit

extension CaptureSession.Dependencies {
    static let live = Self(
        resolve: { url in
            await MainActor.run {
                do {
                    let request = try CaptureTransport.consume(url)
                    // Resolve before any UI activates so focus still points at the source editor.
                    let file = try XcodeDocumentResolver.resolve(request)
                    return .success(ResolvedCapture(
                        reference: CodeReference(file: file, selection: request.selection),
                        sourceProcessID: request.xcodeProcessID
                    ))
                } catch let error as CaptureError {
                    return .failure(error)
                } catch {
                    return .failure(.invalidRequest)
                }
            }
        },
        copy: { text in
            await MainActor.run {
                NSPasteboard.general.clearContents()
                return NSPasteboard.general.setString(text, forType: .string)
            }
        }
    )
}
