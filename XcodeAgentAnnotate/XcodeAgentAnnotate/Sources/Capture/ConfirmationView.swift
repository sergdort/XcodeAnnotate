import AnnotateDomain
import SwiftUI

/// The brief "Copied" HUD shown after the clipboard write succeeds.
struct ConfirmationView: View {
    let annotation: Annotation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.surface)
                .frame(width: 28, height: 28)
                .background(Palette.ink, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Copied for your agent").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(detail).font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 18)
        .padding(.vertical, 10)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.hairline))
        .padding(1)
    }

    private var detail: String {
        let range = annotation.reference.selection.range
        // An end at column 0 of the next line does not include that line.
        let last = range.end.column == 0 && range.end.line > range.start.line ? range.end.line : range.end.line + 1
        let first = range.start.line + 1
        let lines = first == last ? "line \(first)" : "lines \(first)–\(last)"
        return "\(annotation.reference.file.lastPathComponent) · \(lines)"
    }
}
