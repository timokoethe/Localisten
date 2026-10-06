//
//  LiveTranscriptionViewModel.swift
//  Localisten
//
//  Created by Timo Köthe on 16.08.26.
//

import Observation
import Foundation

@Observable
final class LiveTranscriptionViewModel {
    /// The complete UI state for live transcription.
    ///
    /// - `idle`: Live transcription has not started.
    /// - `preparing`: Permissions, audio session, and speech assets are being prepared.
    /// - `recording`: The microphone is active and transcript updates are streaming.
    /// - `stopped`: Recording has ended and the last transcript remains available.
    /// - `failed`: Starting or running live transcription failed with a user-facing message.
    enum State: Equatable {
        case idle
        case preparing
        case recording(transcription: String)
        case stopped(transcription: String)
        case failed(message: String)
    }

    var state: State

    private let transcriptionService: TranscriptionService
    private var transcriptionTask: Task<Void, Never>?
    private var sessionID: UUID?

    init(
        initialState: State = .idle,
        transcriptionService: TranscriptionService = .shared
    ) {
        self.state = initialState
        self.transcriptionService = transcriptionService
    }

    deinit {
        transcriptionTask?.cancel()
        transcriptionService.cancelLiveTranscription()
    }

    func startTranscription() {
        guard transcriptionTask == nil else { return }
        let sessionID = UUID()
        self.sessionID = sessionID
        state = .preparing

        let service = transcriptionService
        transcriptionTask = Task { [weak self] in
            guard !Task.isCancelled, self?.sessionID == sessionID else { return }
            do {
                let updates = try await service.startLiveTranscription()
                guard !Task.isCancelled, self?.sessionID == sessionID else { return }
                self?.state = .recording(transcription: "")

                for try await transcription in updates {
                    guard !Task.isCancelled, self?.sessionID == sessionID else { return }

                    // Keep final results arriving after Stop visible.
                    if case .stopped = self?.state {
                        self?.state = .stopped(transcription: transcription)
                    } else {
                        self?.state = .recording(transcription: transcription)
                    }
                }

                guard !Task.isCancelled, self?.sessionID == sessionID else { return }
                if case .recording(let transcription) = self?.state {
                    self?.state = .stopped(transcription: transcription)
                }
            } catch {
                guard !Task.isCancelled, self?.sessionID == sessionID else { return }
                self?.state = .failed(message: self?.userFacingMessage(for: error) ?? error.localizedDescription)
            }

            // Only the current session may clean up the shared service and task.
            guard self?.sessionID == sessionID else { return }
            service.cancelLiveTranscription()
            self?.transcriptionTask = nil
            self?.sessionID = nil
        }
    }

    func stopTranscription() {
        switch state {
        case .preparing:
            reset()
        case .recording(let transcription):
            state = .stopped(transcription: transcription)
            transcriptionService.stopLiveTranscription()
        default:
            break
        }
    }

    func reset() {
        sessionID = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
        transcriptionService.cancelLiveTranscription()
        state = .idle
    }

    private func userFacingMessage(for error: any Error) -> String {
        if let localizedError = error as? any LocalizedError,
           let errorDescription = localizedError.errorDescription {
            return errorDescription
        }

        return error.localizedDescription
    }
}
