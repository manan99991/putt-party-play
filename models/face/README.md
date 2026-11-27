# Face models (Video Studio)

Google's open MediaPipe models, run directly on the phone with TensorFlow Lite / LiteRT — never through MediaPipe Tasks
(which reports usage to Google). Nothing about a video leaves the phone.

| File | What it finds | Source | Licence |
|---|---|---|---|
| face_detector.tflite | faces (BlazeFace short range) | face_landmarker.task (float16, v1) | Apache 2.0 (model card) |
| face_landmarks_detector.tflite | 478-point face mesh | face_landmarker.task (float16, v1) | Apache 2.0 (model card "MediaPipe Face Mesh V2") |
| selfie_multiclass_256x256.tflite | background, hair, body skin, face skin, clothes, other | image_segmenter/selfie_multiclass_256x256 (float32) | Apache 2.0 (model card "Multiclass Segmentation") |

Downloaded by `.github/workflows/fetch-models.yml`; checksums in SHA256SUMS.
