// swift-tools-version:5.5
// stb_vorbis v1.22 (public domain, github.com/nothings/stb commit 46614470): decodes Ogg Vorbis audio, which
// iPhone's own frameworks can't play. Used by File Opener to turn an .ogg into a playable .m4a.
import PackageDescription

let package = Package(
    name: "StbVorbis",
    platforms: [.iOS(.v15)],
    products: [.library(name: "StbVorbis", targets: ["StbVorbis"])],
    targets: [
        .target(name: "StbVorbis", path: "Sources/StbVorbis",
                cSettings: [.define("STB_VORBIS_NO_STDIO"), .define("STB_VORBIS_NO_PUSHDATA_API")]),
    ]
)
