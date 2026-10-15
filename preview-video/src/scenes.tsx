import React from "react";
import {
  AbsoluteFill,
  Img,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { BRAND, FONT_STACK } from "./brand";
import { CaptionBand, FadeIn, FingerTap, PhoneSlot } from "./components";

const pad = { fontFamily: FONT_STACK };

/** 0–2s (frames 0–59): icon on blue, wordmark fades in. */
export const SceneIcon: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: BRAND.accent, alignItems: "center", justifyContent: "center" }}>
    <FadeIn>
      <Img src={staticFile("icon.png")} style={{ width: 420, height: 420, borderRadius: 96 }} />
    </FadeIn>
    <FadeIn delay={20}>
      <div style={{ ...pad, color: "#fff", fontSize: 92, fontWeight: 800, marginTop: 60, letterSpacing: -2 }}>
        <span style={{ color: "#FFFFFF" }}>Handy</span>
        <span style={{ color: "#0E0E12" }}>Tools</span>
      </div>
    </FadeIn>
  </AbsoluteFill>
);

/** 2–6s (60–179): finger drags the snooze slider from 9 to 3 min. */
export const SceneAlarm: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const t = interpolate(frame, [10, 110], [0, 1], { extrapolateRight: "clamp" });
  const mins = Math.round(interpolate(t, [0, 1], [9, 3]));
  const knobX = interpolate(t, [0, 1], [80, 420]);
  return (
    <AbsoluteFill style={{ backgroundColor: BRAND.bgDark }}>
      <PhoneSlot label="alarm-editor.mov">
        <AbsoluteFill style={{ backgroundColor: BRAND.bgLight, padding: 40 }}>
          <div style={{ ...pad, color: BRAND.textPrimary, fontSize: 44, fontWeight: 700, marginTop: 180 }}>
            Snooze length
          </div>
          <div style={{ ...pad, color: BRAND.accent, fontSize: 110, fontWeight: 700, marginTop: 24 }}>
            {mins} min
          </div>
          <div style={{ position: "absolute", left: 40, right: 40, top: 640, height: 8, backgroundColor: "#D9DCE6", borderRadius: 4 }}>
            <div style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: knobX, backgroundColor: BRAND.accent, borderRadius: 4 }} />
            <div style={{ position: "absolute", left: knobX - 20, top: -16, width: 40, height: 40, borderRadius: 20, backgroundColor: BRAND.accent }} />
          </div>
          <FingerTap x={160 + knobX} y={640 - 260} press={interpolate(t, [0, 0.15, 0.85, 1], [0, 0.5, 0.5, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })} />
        </AbsoluteFill>
      </PhoneSlot>
      <CaptionBand text="Your snooze. Your rules." />
    </AbsoluteFill>
  );
};

/** 6–10s (180–299): Share Sheet "Save to Clips" in Safari, then paste in Messages. */
export const SceneClipboard: React.FC = () => {
  const frame = useCurrentFrame();
  const t = interpolate(frame, [15, 100], [0, 1], { extrapolateRight: "clamp" });
  return (
    <AbsoluteFill style={{ backgroundColor: BRAND.bgDark }}>
      <PhoneSlot label="clips-flow.mov">
        <AbsoluteFill style={{ backgroundColor: "#fff", padding: 40 }}>
          {t < 0.5 ? (
            <>
              <div style={{ ...pad, fontSize: 40, fontWeight: 700, marginTop: 200 }}>Share</div>
              {["Save to Clips", "Copy", "Print"].map((s, i) => (
                <div key={s} style={{ ...pad, fontSize: 36, marginTop: 36, padding: "28px 24px", backgroundColor: i === 0 ? "#E8EEFF" : "#F6F7FB", borderRadius: 16, color: i === 0 ? BRAND.accent : BRAND.textPrimary, fontWeight: i === 0 ? 700 : 400 }}>
                  {s}
                </div>
              ))}
              <FingerTap x={160} y={430} press={interpolate(t, [0.1, 0.25, 0.4, 0.5], [0, 0.5, 0.5, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })} />
            </>
          ) : (
            <>
              <div style={{ ...pad, fontSize: 40, fontWeight: 700, marginTop: 200 }}>Messages</div>
              <div style={{ ...pad, fontSize: 34, marginTop: 40, padding: 32, backgroundColor: "#E8EEFF", borderRadius: 24 }}>
                Pasted from Clips: “10 tools. One app.”
              </div>
              <div style={{ ...pad, fontSize: 34, marginTop: 32, padding: 32, backgroundColor: "#F0F2F5", borderRadius: 24, alignSelf: "flex-end" }}>
                keyboard paste ✓
              </div>
            </>
          )}
        </AbsoluteFill>
      </PhoneSlot>
      <CaptionBand text="Copy five. Paste any." />
    </AbsoluteFill>
  );
};

/** 10–14s (300–419): screenshot picked, highlight boxes animate on, Copy all tapped. */
export const SceneOcr: React.FC = () => {
  const frame = useCurrentFrame();
  const t = interpolate(frame, [10, 70], [0, 1], { extrapolateRight: "clamp" });
  const boxes = [
    { top: 300, left: 80, width: 480, height: 46 },
    { top: 360, left: 80, width: 430, height: 46 },
    { top: 420, left: 80, width: 460, height: 46 },
  ];
  return (
    <AbsoluteFill style={{ backgroundColor: BRAND.bgDark }}>
      <PhoneSlot label="text-from-image.mov">
        <AbsoluteFill style={{ backgroundColor: "#0E0E12" }}>
          <div style={{ ...pad, color: "#fff", fontSize: 36, margin: "200px 40px 0" }}>Receipt.jpg — scanned</div>
          {boxes.map((b, i) => (
            <div key={i} style={{
              position: "absolute", ...b,
              backgroundColor: `rgba(31,94,255,${0.35 * Math.min(1, t * 3 - i * 0.6)})`,
              borderRadius: 8,
            }} />
          ))}
          <div style={{ position: "absolute", left: 40, right: 40, bottom: 120, height: 104, backgroundColor: BRAND.accent, borderRadius: 52, display: "flex", alignItems: "center", justifyContent: "center", ...pad, color: "#fff", fontSize: 38, fontWeight: 700 }}>
            Copy all
          </div>
          <FingerTap x={160 + 280} y={1080} press={interpolate(t, [0.7, 0.8, 0.9, 1], [0, 0.5, 0.5, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })} />
        </AbsoluteFill>
      </PhoneSlot>
      <CaptionBand text="Grab the words." />
    </AbsoluteFill>
  );
};

/** 14–18s (420–539): map appears under a photo, "Make a clean copy" tapped, map disappears. */
export const SceneMetadata: React.FC = () => {
  const frame = useCurrentFrame();
  const mapIn = interpolate(frame, [8, 40], [0, 1], { extrapolateRight: "clamp" });
  const tapT = interpolate(frame, [70, 90], [0, 1], { extrapolateRight: "clamp" });
  const mapOut = interpolate(frame, [90, 115], [0, 1], { extrapolateRight: "clamp" });
  const mapVisible = Math.min(mapIn, 1 - mapOut);
  return (
    <AbsoluteFill style={{ backgroundColor: BRAND.bgDark }}>
      <PhoneSlot label="photo-metadata.mov">
        <AbsoluteFill style={{ backgroundColor: BRAND.bgLight, padding: 40 }}>
          <div style={{ ...pad, fontSize: 40, fontWeight: 700, marginTop: 180 }}>Photo Metadata</div>
          <div style={{ ...pad, fontSize: 32, color: BRAND.textSecondary, marginTop: 24 }}>Location</div>
          <div style={{ marginTop: 16, height: 300, borderRadius: 24, overflow: "hidden", opacity: mapVisible, backgroundColor: "#D8E2F5", position: "relative" }}>
            <div style={{ position: "absolute", left: "45%", top: "38%", width: 36, height: 36, borderRadius: 18, backgroundColor: BRAND.accent }} />
            <div style={{ ...pad, position: "absolute", left: 24, bottom: 16, fontSize: 28, color: BRAND.textSecondary }}>41.87° N, 87.62° W</div>
          </div>
          <div style={{ marginTop: 32, height: 104, backgroundColor: mapVisible > 0.5 ? BRAND.accent : "#D9DCE6", borderRadius: 52, display: "flex", alignItems: "center", justifyContent: "center", ...pad, color: mapVisible > 0.5 ? "#fff" : BRAND.textSecondary, fontSize: 38, fontWeight: 700 }}>
            Make a clean copy
          </div>
          {mapVisible < 0.5 && mapOut >= 1 && (
            <div style={{ ...pad, marginTop: 24, fontSize: 32, color: "#2E7D32", fontWeight: 600 }}>
              Location stripped ✓
            </div>
          )}
          <FingerTap x={160 + 280} y={1050} press={interpolate(tapT, [0, 0.3, 0.7, 1], [0, 0.5, 0.5, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })} />
        </AbsoluteFill>
      </PhoneSlot>
      <CaptionBand text="Strip what's hidden." />
    </AbsoluteFill>
  );
};

/** 18–20s (540–599): Home grid, "10 tools. One app." End on icon. */
export const SceneHome: React.FC = () => {
  const tools = ["Alarm Pro", "Multi-Clipboard", "Flashlight", "Web → Home", "Sticky Note", "Text from Image"];
  return (
    <AbsoluteFill style={{ backgroundColor: BRAND.bgLight, padding: 60 }}>
      <div style={{ ...pad, fontSize: 72, fontWeight: 800, marginTop: 60, color: BRAND.textPrimary }}>HandyTools</div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 32, marginTop: 60 }}>
        {tools.map((t, i) => (
          <div key={t} style={{ backgroundColor: "#fff", borderRadius: 32, padding: 40, ...pad }}>
            <div style={{ width: 72, height: 72, borderRadius: 36, backgroundColor: "#E8EEFF" }} />
            <div style={{ fontSize: 34, fontWeight: 700, marginTop: 24, color: BRAND.textPrimary }}>{t}</div>
          </div>
        ))}
      </div>
      <CaptionBand text="10 tools. One app." />
    </AbsoluteFill>
  );
};
