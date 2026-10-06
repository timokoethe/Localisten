---
status: implemented
area: transcription
platforms:
  - ios-26
  - ios-27
---

# Audio File Transcription

## Purpose

Showcase on-device speech transcription from an imported audio file.

## User Story

As a user, I want to transcribe an audio file so that I can read and select its recognized text.

## Acceptance Criteria

- “Add Audio File” opens the system picker for a single audio file.
- During transcription, the screen displays the selected file name and a progress indicator instead of the file-selection action.
- Recognition uses a supported equivalent of the device's current locale and installs required speech assets when needed.
- Successful transcription displays the file name and a scrollable, selectable transcript.
- “Reset” clears the result and returns to file selection.
- Import or transcription failures display an error and offer “Choose Another File”; empty audio, no detected speech, and unsupported locales have specific messages.
