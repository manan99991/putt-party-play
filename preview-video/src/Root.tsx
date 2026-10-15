import React from "react";
import { AbsoluteFill, Composition, Sequence } from "remotion";
import { CANVAS, FPS } from "./brand";
import {
  SceneAlarm,
  SceneClipboard,
  SceneHome,
  SceneIcon,
  SceneMetadata,
  SceneOcr,
} from "./scenes";

// 20 seconds at 30fps = 600 frames. Sequences are contiguous, hard cuts.
const SCENES = [
  { id: "icon", from: 0, duration: 60, Component: SceneIcon },
  { id: "alarm", from: 60, duration: 120, Component: SceneAlarm },
  { id: "clipboard", from: 180, duration: 120, Component: SceneClipboard },
  { id: "ocr", from: 300, duration: 120, Component: SceneOcr },
  { id: "metadata", from: 420, duration: 120, Component: SceneMetadata },
  { id: "home", from: 540, duration: 60, Component: SceneHome },
];

export const HandyToolsPreview: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: "#0E0E12" }}>
    {SCENES.map(({ id, from, duration, Component }) => (
      <Sequence key={id} from={from} durationInFrames={duration}>
        <Component />
      </Sequence>
    ))}
  </AbsoluteFill>
);

export const Root: React.FC = () => (
  <Composition
    id="HandyToolsPreview"
    component={HandyToolsPreview}
    width={CANVAS.width}
    height={CANVAS.height}
    fps={FPS}
    durationInFrames={600}
  />
);
