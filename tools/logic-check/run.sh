#!/bin/bash
# Free logic check for the builder: see README.md.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../.."
WORK="${TMPDIR:-/tmp}/tenzy-logic-check"; mkdir -p "$WORK"
which="${1:-both}"; [ $# -gt 0 ] && shift
status=0
if [ "$which" = android ] || [ "$which" = both ]; then
  K="${KOTLINC:-kotlinc}"; A="$ROOT/android/app/src"; D="$A/main/java/com/handytools/app/tools/builder"
  rm -f "$WORK/android.jar"
  JAVA_TOOL_OPTIONS= "$K" "$HERE"/android_stubs/*.kt "$D/Chain.kt" "$D/TextTidy.kt" "$D/PriceDeal.kt" "$D/PixelArt.kt" \
    "$A/test/java/com/handytools/app/tools/builder/BuilderLogicTest.kt" -include-runtime -d "$WORK/android.jar" 2>&1 | grep -v "^warning\|JAVA_TOOL" | head -40
  out=$(JAVA_TOOL_OPTIONS= java -cp "$WORK/android.jar" RunKt 2>&1 | grep -v JAVA_TOOL); echo "android: $out"
  echo "$out" | grep -q "failed 0" || status=1
fi
if [ "$which" = ios ] || [ "$which" = both ]; then
  S="${SWIFTC:-swiftc}"; rm -rf "$WORK/ios"; python3 "$HERE/ios_gen.py" "$WORK/ios" "$@" || exit 1
  rm -f "$WORK/ios-run"      # never report an old build's result when this one fails to compile
  "$S" "$WORK"/ios/*.swift -o "$WORK/ios-run" 2>&1 | grep -E "error:" -A3 | head -60
  out=$("$WORK/ios-run" 2>&1 | tail -25); echo "ios: $out"
  echo "$out" | grep -q "failed 0" || status=1
fi
exit $status
