# Localisten for iOS

[![License: MIT](https://img.shields.io/badge/license-MIT-orange)](https://opensource.org/license/mit)
![Framework](https://img.shields.io/badge/SwiftUI-orange)
![Platform](https://img.shields.io/badge/Platforms-iOS-orange)
![Xcode](https://img.shields.io/badge/Xcode-26-orange)
![iOS](https://img.shields.io/badge/iOS-26-orange)
![Apple](https://img.shields.io/badge/Apple-000000?style=flat&logo=apple)

**Localisten** is a small SwiftUI showcase app for on-device live and audio-file transcription using Apple's Speech framework. It demonstrates `SpeechAnalyzer` and `SpeechTranscriber` in a minimal native interface, without a backend or API key.

## Screenshots

| Live transcription | Audio-file transcription |
| --- | --- |
| <img src="docs/assets/LiveTranscriptionView.png" alt="Live transcription screen with the Ready to Listen state" width="280"> | <img src="docs/assets/AudioTranscriptionView.png" alt="Audio-file screen with the Add Audio File action" width="280"> |

## Features

- **[Live transcription](docs/features/live-transcription.md)**: Capture microphone audio and display recognized speech as it arrives. Stop recording to keep the transcript, or reset to start again.
- **[Audio-file transcription](docs/features/audio-file-transcription.md)**: Import an audio file and transcribe it on-device.
- **Transcript display**: Read and select recognized text, then reset for another file.
- **Errors**: View error messages, with an option to choose another file.

## Requirements

- Xcode 26 or later and an iPhone running iOS 26 or later.
- A device and recognition language supported by `SpeechTranscriber`.
- Network access when required speech assets need to be downloaded.

Recognition uses the device's current locale. Once the required assets are installed, audio is processed locally.

## Quick Start

1. Open `Localisten.xcodeproj` in Xcode.
2. Under Signing & Capabilities, select your development team and set a unique bundle identifier. Choose a supported iPhone.
3. Run the app and tap **Start Listening**, then allow microphone access. Alternatively, open **Audio File** and tap **Add Audio File**.

## Limitations

This is a demonstration app. Live recording stops when its screen is left or the app becomes inactive. Transcripts are not saved, and dedicated sharing, export, and audio-file transcription cancellation are not implemented.

## License

Localisten is available under the MIT License. See [LICENSE](LICENSE) for the full license text.
