---
status: implemented
area: transcription
platforms:
  - ios-26
  - ios-27
---

# Live Transcription

## Purpose

Showcase on-device speech transcription from the microphone.

## User Story

As a user, I want to see my speech as text while speaking and keep the transcript after stopping.

## Acceptance Criteria

- “Start Listening” requests microphone permission and prepares the speech analyzer.
- The initial screen remains visible during preparation, with “Start Listening” disabled and no loading indicator.
- Recognition uses a supported equivalent of the device's current locale and installs required speech assets when needed.
- Recognized text updates while the microphone is active.
- Provisional text is replaced by its final result, so each spoken phrase appears once.
- “Stop” ends recording and allows final recognition results to arrive.
- “Reset” clears the transcript and returns to the initial screen.
- Leaving the screen or making the app inactive stops recording, including pending preparation.
- Permission, preparation, and recognition errors display a message and allow another attempt.
