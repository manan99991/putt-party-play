import SwiftUI

/// A determinate progress bar with a short status line, for any tool doing work the user is waiting
/// on. Prefer this over a bare spinner so people can see how far a job has got and that it's moving.
///
/// - `value`: 0…1 progress. Pass `nil` for work whose length genuinely can't be measured — it shows
///   an animated indeterminate *bar* (not a dead spinner) with the label, so the UI still reads as
///   "working," not "stuck."
/// - `label`: a short human status, e.g. "Fitting photo 2 of 5…".
struct ToolProgressBar: View {
    let value: Double?
    let label: String
    init(value: Double? = nil, label: String = "") { self.value = value; self.label = label }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let value {
                ProgressView(value: min(max(value, 0), 1)).tint(HandyColor.accent)
            } else {
                ProgressView().progressViewStyle(.linear).tint(HandyColor.accent)
            }
            if !label.isEmpty {
                Text(label).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.25), value: value)
    }
}
