# HandyTools — handoff notes for a second session

You are on the live code: GitHub `manan99991/putt-party-play`, branch `handytools`.
Work ON TOP of this. Don't use any earlier local scaffold.

## First thing after cloning
    git rev-parse HEAD > SYNC-BASE.txt
That commit is the base your patch is measured from.

## What's already here (don't redo)
- Design system tokens + components on both platforms (android/.../ui/Theme.kt, ios/HandyTools/Theme.swift)
- Home grid, all 10 tool screens re-skinned, paywall sheet, ad strip with "Remove ads"
- Onboarding (3 pages), Setup (one-time permissions), Settings, Privacy pages
- App icon (direction A, the grid) wired in both projects; the six illustrations in drawable-nodpi / Assets.xcassets
- CI: .github/workflows/{android,ios}.yml build both apps and capture light+dark screenshots of every route

## Division of labor
- Your side: code for prompts 1–3 (motion/perf, heroes, alarm ring screen), the store-screenshot framing pipeline (5), the Remotion project (6).
- The CI side: merge, build, real emulator/simulator screenshots, measured cold-start and frame times, the ship audit (4) against real captures.
So don't invent profiler numbers or screenshots — leave a comment where a measurement goes and CI fills it.

## Screenshot routes
Android: `--es route <name>` extra on MainActivity. iOS: `-route <name>` launch arg (with `-screenshots`).
Add a route for any new screen (alarm ring screen = `ring`) and append it to the `for r in …` lists in both workflow files.

## How to send work back
Commit as you go (any author). When done:
    git format-patch --binary $(cat SYNC-BASE.txt) --stdout > handytools-changes.patch
Hand `handytools-changes.patch` back. It gets applied to the branch, built on CI, and screenshotted.
(A zip of the whole folder also works; the patch is smaller and merges cleanly.)

## Don't
- Don't change Theme.kt / Theme.swift token values (add a token if you need one).
- Don't touch the AdMob / billing / StoreKit code paths beyond deferring their init (prompt 1).
- Don't change copy; the strings were audited.
