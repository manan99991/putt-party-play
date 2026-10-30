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

/// Shown over a camera/sensor tool's preview when access was denied, so the user gets a clear reason
/// and a one-tap route to Settings instead of a blank black box or a silently-dead control.
/// `sub` can name the on-device fallback the tool still offers (e.g. "…or pick a photo below").
struct PermissionOffCard: View {
    var icon: String = "video.slash.fill"
    var line: String
    var sub: String? = nil
    var body: some View {
        VStack(spacing: HandySpacing.s8) {
            Image(systemName: icon).font(.system(size: 28)).foregroundStyle(HandyColor.textSecondary)
            Text(line).font(HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary).multilineTextAlignment(.center)
            if let sub { Text(sub).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center) }
            Button { Permission.openSettings() } label: {
                Label("Open Settings", systemImage: "gearshape").frame(maxWidth: .infinity)
            }.secondaryButton()
        }
        .padding(HandySpacing.s16)
    }
}
