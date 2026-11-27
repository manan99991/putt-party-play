// swift-tools-version:5.9
// The TensorFlow Lite C runtime (fetched by fetch.sh, Apache 2.0) and a small Swift wrapper, for the Video Studio's
// on-device face engine: Google's open face-mesh and segmentation models run directly — nothing leaves the phone.
import PackageDescription

let package = Package(
    name: "TFLite",
    platforms: [.iOS(.v16)],
    products: [.library(name: "TFLite", targets: ["TFLite"])],
    targets: [
        .binaryTarget(name: "TensorFlowLiteC", path: "TensorFlowLiteC.xcframework"),
        .target(name: "TFLite", dependencies: ["TensorFlowLiteC"], linkerSettings: [.linkedLibrary("c++")]),
    ]
)
