# Logic check (free, no CI minutes)

Runs the builder's plain logic and its unit tests on Linux, without Xcode, Gradle or a phone. It catches wrong
rules, wrong test names and broken wording before a paid Mac build does. It does not compile screens, camera,
Vision, PDF or video code: those still need the real build.

    tools/logic-check/run.sh            # both platforms
    tools/logic-check/run.sh ios -v     # also list the tests that need a phone

Needs two compilers, both downloadable from GitHub releases (set the paths if they live elsewhere):

- `KOTLINC` (default `kotlinc` on PATH): github.com/JetBrains/kotlin, `kotlin-compiler-2.0.21.zip`
- `SWIFTC` (default `swiftc` on PATH): any Swift 5.10+ for Linux, e.g. github.com/swiftwasm/swift
  `swift-wasm-5.10.0-RELEASE-ubuntu22.04_x86_64.tar.gz`

What it does:

- Android: compiles `Chain.kt`, `TextTidy.kt`, `PriceDeal.kt` and `BuilderLogicTest.kt` against small stand-ins for
  `org.json` and JUnit (`android_stubs/`), then runs every `@Test`.
- iOS: `ios_gen.py` lifts the Foundation-only declarations out of the engine and builder files (models, starters,
  text rules, planner), adds stand-ins (`ios_stubs.swift`, `ios_shim.swift`), keeps the test methods that touch only
  those, and runs them. Dates, phone numbers and addresses found through Apple's data detector come back empty here.
