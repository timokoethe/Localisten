//
//  TranscriptionService.swift
//  Localisten
//
//  Created by Timo Köthe on 16.08.26.
//

import Foundation
import AVFoundation
import Speech

final class TranscriptionService {
    static let shared = TranscriptionService()

    private init() {}

    func startLiveTranscription() async throws {}

    func stopLiveTranscription() {}

    func transcribeAudioFile(at url: URL) async throws -> String {
        let isAccessingSecurityScopedResource = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessingSecurityScopedResource {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let audioFile = try AVAudioFile(forReading: url)

        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
            throw TranscriptionError.unsupportedLocale
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)

        if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installationRequest.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let resultsTask = Task<[String], Error> {
            var transcriptParts: [String] = []

            for try await result in transcriber.results where result.isFinal {
                let text = String(result.text.characters)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !text.isEmpty {
                    transcriptParts.append(text)
                }
            }

            return transcriptParts
        }

        do {
            if let lastSampleTime = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: lastSampleTime)
            } else {
                await analyzer.cancelAndFinishNow()
                resultsTask.cancel()
                throw TranscriptionError.emptyAudioFile
            }

            let transcription = try await resultsTask.value
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !transcription.isEmpty else {
                throw TranscriptionError.noSpeechDetected
            }

            return transcription
        } catch {
            resultsTask.cancel()
            await analyzer.cancelAndFinishNow()
            throw error
        }
    }
}

enum TranscriptionError: LocalizedError {
    case emptyAudioFile
    case noSpeechDetected
    case unsupportedLocale

    var errorDescription: String? {
        switch self {
        case .emptyAudioFile:
            "The audio file is empty."
        case .noSpeechDetected:
            "No speech was detected in the audio file."
        case .unsupportedLocale:
            "The current language is not supported on this device."
        }
    }
}
