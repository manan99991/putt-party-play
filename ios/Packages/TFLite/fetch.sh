#!/bin/bash
# The TensorFlow Lite C runtime for the Video Studio's face engine (Apache 2.0; the same build the TensorFlowLiteC
# 2.17.0 CocoaPod uses). Fetched at project generation (XcodeGen preGenCommand), checked against a pinned checksum,
# never committed. It contains no network code (checked in .github/workflows/fetch-models.yml).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
dest="$here/TensorFlowLiteC.xcframework"
url="https://dl.google.com/tflite-release/ios/prod/tensorflow/lite/release/ios/release/32/20240729-115310/TensorFlowLiteC/2.17.0/0c10b3543e01f547/TensorFlowLiteC-2.17.0.tar.gz"
sum="9667b476015f136e5b332ce040e12822c4ac6d5c58947882ddc809cdff0fb99e"
[ -f "$dest/.sha256" ] && [ "$(cat "$dest/.sha256")" = "$sum" ] && exit 0
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
curl -fsSL --retry 3 -o "$tmp/tflc.tgz" "$url"
got="$(shasum -a 256 "$tmp/tflc.tgz" | cut -d' ' -f1)"
[ "$got" = "$sum" ] || { echo "TensorFlowLiteC checksum mismatch: $got" >&2; exit 1; }
tar -xzf "$tmp/tflc.tgz" -C "$tmp"
rm -rf "${dest:?}"
# The pod ships static frameworks without an Info.plist, which Xcode refuses to embed. Repackage each slice as a
# static library (with its headers and a module map) so it's linked into the app, never embedded.
src="$tmp/TensorFlowLiteC-2.17.0/Frameworks/TensorFlowLiteC.xcframework"
args=()
for slice in "$src"/*/; do
  fw="$slice/TensorFlowLiteC.framework"
  [ -d "$fw" ] || continue
  name="$(basename "$slice")"
  out="$tmp/lib/$name"; mkdir -p "$out/Headers/TensorFlowLiteC"
  cp "$fw/TensorFlowLiteC" "$out/libTensorFlowLiteC.a"
  # The headers include each other framework-style ("TensorFlowLiteC/common.h"), so they keep that folder.
  cp -R "$fw/Headers/." "$out/Headers/TensorFlowLiteC/"
  rm -f "$out/Headers/TensorFlowLiteC/module.modulemap"
  printf 'module TensorFlowLiteC {\n  umbrella header "TensorFlowLiteC/TensorFlowLiteC.h"\n  export *\n}\n' > "$out/Headers/module.modulemap"
  echo "slice $name: $(ls "$out/Headers/TensorFlowLiteC" | tr '\n' ' ')"
  args+=(-library "$out/libTensorFlowLiteC.a" -headers "$out/Headers")
done
xcodebuild -create-xcframework "${args[@]}" -output "$dest" >/dev/null
echo "$sum" > "$dest/.sha256"
echo "TensorFlowLiteC ready"
