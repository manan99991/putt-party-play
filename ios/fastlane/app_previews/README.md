# App Store preview video

`en-US/Tenzy_App_Preview_iPhone_6.9.mp4` — filmed from the real app by `.github/workflows/ios-preview.yml`
(touch `ios/.preview` to film a new take). 886×1920, 30 fps, H.264 + AAC stereo (silent), 15–30 s, which is Apple's
6.9-inch iPhone preview spec. Shows Home, the 10-second demo, the tool shelves and "say it, Tenzy builds it".

fastlane deliver does not upload previews; it goes up with the launch (App Store Connect API, or the media manager
for the 6.9-inch iPhone display). Re-film after any change to the screens it shows (rulebook §3: match the shipped build).
