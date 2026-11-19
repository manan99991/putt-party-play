import SwiftUI
import Photos

/// Before → after on one picture: drag the handle (or tap either side) to see how much changed. Used by every
/// photo result so the change is always visible before anything is saved.
struct CompareSlider: View {
    let before: UIImage
    let after: UIImage
    var height: CGFloat = 300
    var circle = false                 // preview as the round crop apps show for profile pictures
    @State private var split: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                pic(after, w: w)
                pic(before, w: w)
                    .mask(alignment: .leading) { Rectangle().frame(width: max(0, w * split)) }
                Rectangle().fill(.white).frame(width: 2).shadow(radius: 2).offset(x: w * split - 1)
                Circle().fill(.white).frame(width: 30, height: 30).shadow(radius: 3)
                    .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 12, weight: .bold)).foregroundStyle(.black))
                    .offset(x: w * split - 15)
                HStack {
                    tag(L("Before")); Spacer(); tag(L("After"))
                }.padding(8).frame(maxHeight: .infinity, alignment: .top)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in split = min(1, max(0, v.location.x / max(1, w))) })
            .clipShape(circle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous)))
        }
        .frame(height: height)
        .frame(maxWidth: circle ? height : .infinity)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Before and after"))
        .accessibilityValue("\(Int(split * 100))% \(L("before"))")
        .accessibilityAdjustableAction { d in split = min(1, max(0, split + (d == .increment ? 0.1 : -0.1))) }
    }

    private func pic(_ img: UIImage, w: CGFloat) -> some View {
        ZStack { Checkerboard(); Image(uiImage: img).resizable().scaledToFit() }
            .frame(width: w, height: height)
    }
    private func tag(_ t: String) -> some View {
        Text(t).font(HandyFont.micro.weight(.semibold)).padding(.horizontal, 7).padding(.vertical, 3)
            .background(.black.opacity(0.55), in: Capsule()).foregroundStyle(.white)
    }
}

/// Save straight into Photos (add-only access) — the landing place for a finished picture.
enum PhotoSaver {
    static func save(_ data: Data) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil) }
            return true
        } catch { return false }
    }
    static func saveVideo(_ url: URL) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil) }
            return true
        } catch { return false }
    }
}
