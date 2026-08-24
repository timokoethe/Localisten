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

    private var liveSession: LiveTranscriptionSession?

    private init() {}

    func startLiveTranscription() async throws -> AsyncThrowingStream<String, Error> {
        stopLiveTranscription()

        guard await AVAudioApplication.requestRecordPermission() else {
            throw TranscriptionError.microphonePermissionDenied
        }

        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
            throw TranscriptionError.unsupportedLocale
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)

        if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installationRequest.downloadAndInstall()
        }

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let analysisFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
            considering: inputFormat
        ) ?? inputFormat

        let converter = Self.makeConverterIfNeeded(from: inputFormat, to: analysisFormat)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.prepareToAnalyze(in: analysisFormat)

        let (inputStream, inputContinuation) = AsyncThrowingStream.makeStream(of: AnalyzerInput.self)
        let (transcriptionStream, transcriptionContinuation) = AsyncThrowingStream.makeStream(of: String.self)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            if let converter {
                guard let convertedBuffer = Self.convert(buffer, with: converter, to: analysisFormat) else {
                    return
                }

                inputContinuation.yield(AnalyzerInput(buffer: convertedBuffer))
            } else {
                inputContinuation.yield(AnalyzerInput(buffer: buffer))
            }
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true)
        try audioEngine.start()

        let analysisTask = Task {
            do {
                let lastSampleTime = try await analyzer.analyzeSequence(inputStream)

                if let lastSampleTime {
                    try await analyzer.finalizeAndFinish(through: lastSampleTime)
                } else {
                    await analyzer.cancelAndFinishNow()
                }
            } catch {
                transcriptionContinuation.finish(throwing: error)
                throw error
            }
        }

        let resultsTask = Task {
            do {
                var segments: [LiveTranscriptionSegment] = []

                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !text.isEmpty else {
                        continue
                    }

                    let segment = LiveTranscriptionSegment(
                        startTime: result.range.start.seconds,
                        text: text
                    )

                    if let index = segments.firstIndex(where: { $0.startTime == segment.startTime }) {
                        segments[index] = segment
                    } else {
                        segments.append(segment)
                    }

                    let transcription = segments
                        .sorted { $0.startTime < $1.startTime }
                        .map(\.text)
                        .joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    transcriptionContinuation.yield(transcription)
                }

                transcriptionContinuation.finish()
            } catch {
                transcriptionContinuation.finish(throwing: error)
                throw error
            }
        }

        liveSession = LiveTranscriptionSession(
            audioEngine: audioEngine,
            inputContinuation: inputContinuation,
            transcriptionContinuation: transcriptionContinuation,
            analysisTask: analysisTask,
            resultsTask: resultsTask
        )

        return transcriptionStream
    }

    func stopLiveTranscription() {
        liveSession?.stop()
        liveSession = nil
    }

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
    case microphonePermissionDenied
    case noSpeechDetected
    case unsupportedLocale

    var errorDescription: String? {
        switch self {
        case .emptyAudioFile:
            "The audio file is empty."
        case .microphonePermissionDenied:
            "Microphone access is required for live transcription."
        case .noSpeechDetected:
            "No speech was detected in the audio file."
        case .unsupportedLocale:
            "The current language is not supported on this device."
        }
    }
}

private struct LiveTranscriptionSegment {
    let startTime: TimeInterval
    let text: String
}

private final class LiveTranscriptionSession {
    let audioEngine: AVAudioEngine
    let inputContinuation: AsyncThrowingStream<AnalyzerInput, Error>.Continuation
    let transcriptionContinuation: AsyncThrowingStream<String, Error>.Continuation
    let analysisTask: Task<Void, any Error>
    let resultsTask: Task<Void, any Error>

    init(
        audioEngine: AVAudioEngine,
        inputContinuation: AsyncThrowingStream<AnalyzerInput, Error>.Continuation,
        transcriptionContinuation: AsyncThrowingStream<String, Error>.Continuation,
        analysisTask: Task<Void, any Error>,
        resultsTask: Task<Void, any Error>
    ) {
        self.audioEngine = audioEngine
        self.inputContinuation = inputContinuation
        self.transcriptionContinuation = transcriptionContinuation
        self.analysisTask = analysisTask
        self.resultsTask = resultsTask
    }

    func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        inputContinuation.finish()
        transcriptionContinuation.finish()
        analysisTask.cancel()
        resultsTask.cancel()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private extension TranscriptionService {
    static func makeConverterIfNeeded(
        from inputFormat: AVAudioFormat,
        to outputFormat: AVAudioFormat
    ) -> AVAudioConverter? {
        let formatsMatch = inputFormat.sampleRate == outputFormat.sampleRate
            && inputFormat.channelCount == outputFormat.channelCount
            && inputFormat.commonFormat == outputFormat.commonFormat

        guard !formatsMatch else {
            return nil
        }

        return AVAudioConverter(from: inputFormat, to: outputFormat)
    }

    static func convert(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let sampleRateRatio = outputFormat.sampleRate / buffer.format.sampleRate
        let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * sampleRateRatio) + 1

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: frameCapacity
        ) else {
            return nil
        }

        var didProvideInput = false
        var conversionError: NSError?

        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        switch status {
        case .haveData, .inputRanDry, .endOfStream:
            return convertedBuffer.frameLength > 0 ? convertedBuffer : nil
        case .error:
            return nil
        @unknown default:
            return nil
        }
    }
}
