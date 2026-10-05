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
        try Task.checkCancellation()
        cancelLiveTranscription()

        guard await AVAudioApplication.requestRecordPermission() else {
            throw TranscriptionError.microphonePermissionDenied
        }
        try Task.checkCancellation()

        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
            throw TranscriptionError.unsupportedLocale
        }
        try Task.checkCancellation()

        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)

        if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try Task.checkCancellation()
            try await installationRequest.downloadAndInstall()
        }
        try Task.checkCancellation()

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
        try Task.checkCancellation()

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
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true)
            try audioEngine.start()
        } catch {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            await analyzer.cancelAndFinishNow()
            throw error
        }

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
                var transcript = LiveTranscript()

                for try await result in transcriber.results {
                    transcript.update(
                        text: String(result.text.characters),
                        isFinal: result.isFinal
                    )
                    transcriptionContinuation.yield(transcript.text)
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
    }

    func cancelLiveTranscription() {
        liveSession?.cancel()
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

private struct LiveTranscript {
    private var finalizedParts: [String] = []
    private var provisionalText = ""

    var text: String {
        (finalizedParts + [provisionalText])
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    mutating func update(text: String, isFinal: Bool) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if isFinal {
            if !text.isEmpty {
                finalizedParts.append(text)
            }
            // The final result replaces the provisional version of this phrase.
            provisionalText = ""
        } else {
            provisionalText = text
        }
    }
}

private final class LiveTranscriptionSession {
    private var isStopped = false
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
        guard !isStopped else { return }
        isStopped = true
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        inputContinuation.finish()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func cancel() {
        stop()
        transcriptionContinuation.finish()
        analysisTask.cancel()
        resultsTask.cancel()
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
