# Security Policy

## Supported Versions

Security fixes are applied to the latest published Localisten release.

Localisten is a demonstration app for iOS 26 that uses Apple's Speech framework (`SpeechAnalyzer` and `SpeechTranscriber`) for on-device live and audio-file transcription. It is not production-ready, and older demo builds are not maintained.

The app has no backend or API key. Audio is processed locally once the required speech assets are installed; downloading those assets may require network access. Transcripts are held in app memory and are not saved by the app.

## Reporting a Vulnerability

Please do not disclose vulnerabilities in a public issue or pull request.

Use GitHub's private vulnerability reporting for this repository from the **Security** tab by choosing **Report a vulnerability**. Include the affected version, steps to reproduce, impact, and any suggested fix.

If **Report a vulnerability** is not visible, private vulnerability reporting has not been enabled yet. Open a public issue asking for a private contact channel without including vulnerability details.

When reporting a vulnerability, do not include private recordings, audio files, transcripts, credentials, personal data, or sensitive screenshots unless they are strictly required to explain the issue. Prefer synthetic or anonymized audio samples and redact anything that is not needed to reproduce the problem.

## What to Report Privately

Please use private vulnerability reporting for issues such as:

- Unintended network access, transmission of audio or transcripts, or telemetry beyond the expected download of speech assets
- Exposure or unintended persistence of microphone audio, imported audio files, transcripts, file names, device data, or local files
- Microphone capture without user initiation and permission, or continued capture after stopping, leaving the live transcription screen, or the app becoming inactive
- Unauthorized access to files outside the user's selection, or failure to release security-scoped file access after processing
- Crafted audio files that cause unauthorized data access or another demonstrable security impact
- Inclusion of credentials, signing assets, private keys, generated app bundles, or local system files
- A privacy issue that conflicts with Localisten's on-device transcription design
- A build or project configuration issue that could expose sensitive data

## Non-Security Issues

General app bugs, transcription inaccuracies, unsupported devices or recognition languages, unavailable speech assets, audio format compatibility issues, and UI problems can be reported with the public bug report template unless they expose private data or create a security risk.
