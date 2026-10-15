import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { BRAND, FONT_STACK } from "./brand";

/** White brand text on a blue bottom band — silent-safe caption. */
export const CaptionBand: React.FC<{ text: string }> = ({ text }) => (
  <div
    style={{
      position: "absolute",
      left: 0,
      right: 0,
      bottom: 0,
      height: 220,
      backgroundColor: BRAND.accent,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      padding: "0 60px",
    }}
  >
    <span
      style={{
        color: "#FFFFFF",
        fontFamily: FONT_STACK,
        fontSize: 56,
        fontWeight: 700,
        letterSpacing: -1,
        textAlign: "center",
      }}
    >
      {text}
    </span>
  </div>
);

/** 48pt translucent circle with a press pulse. Drive `press` 0->1 over the tap. */
export const FingerTap: React.FC<{
  x: number;
  y: number;
  press: number; // 0..1 local progress
}> = ({ x, y, press }) => {
  const { fps } = useVideoConfig();
  const scale = interpolate(press, [0, 0.5, 1], [1, 0.82, 1]);
  const ring = interpolate(press, [0, 1], [0, 42]);
  return (
    <div
      style={{
        position: "absolute",
        left: x - 24,
        top: y - 24,
        width: 48,
        height: 48,
        borderRadius: 24,
        backgroundColor: "rgba(255,255,255,0.45)",
        border: "3px solid rgba(255,255,255,0.85)",
        transform: `scale(${scale})`,
      }}
    >
      <div
        style={{
          position: "absolute",
          left: -21,
          top: -21,
          width: 90,
          height: 90,
          borderRadius: 45,
          border: "3px solid rgba(255,255,255,0.6)",
          opacity: press > 0 && press < 1 ? 1 : 0,
          transform: `scale(${1 + ring / 90})`,
        }}
      />
    </div>
  );
};

/**
 * Labeled placeholder for a simulator screen recording.
 * To swap in real footage, replace the PhoneSlot contents with:
 *   <OffthreadVideo src={staticFile("placeholders/<name>.mp4")} ... />
 * (see public/placeholders/README.md) — keep it inside the phone bounds.
 */
export const PhoneSlot: React.FC<{
  label: string;
  children?: React.ReactNode;
  phoneX?: number;
  phoneY?: number;
  phoneW?: number;
  phoneH?: number;
}> = ({ label, children, phoneX = 120, phoneY = 260, phoneW = 646, phoneH = 1180 }) => (
  <div
    style={{
      position: "absolute",
      left: phoneX,
      top: phoneY,
      width: phoneW,
      height: phoneH,
      borderRadius: 64,
      backgroundColor: "#0A0A0C",
      border: "10px solid #2A2A30",
      overflow: "hidden",
    }}
  >
    {children ?? (
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: BRAND.bgDark,
        }}
      >
        <div
          style={{
            color: "#A3A6B5",
            fontFamily: FONT_STACK,
            fontSize: 34,
            fontWeight: 600,
            textAlign: "center",
            padding: 40,
          }}
        >
          SIM RECORDING: {label}
        </div>
      </AbsoluteFill>
    )}
  </div>
);

/** Fade-in wrapper using a spring (enter = ease-out feel). */
export const FadeIn: React.FC<{ children: React.ReactNode; delay?: number }> = ({
  children,
  delay = 0,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const progress = spring({
    frame: Math.max(0, frame - delay),
    fps,
    config: { damping: 100, stiffness: 200, mass: 0.5 },
  });
  return (
    <div style={{ opacity: progress, transform: `translateY(${(1 - progress) * 24}px)` }}>
      {children}
    </div>
  );
};
