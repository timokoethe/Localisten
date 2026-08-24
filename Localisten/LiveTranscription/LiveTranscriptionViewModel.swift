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

    init(
        initialState: State = .idle,
        transcriptionService: TranscriptionService = .shared
    ) {
        self.state = initialState
        self.transcriptionService = transcriptionService
    }

    deinit {
        transcriptionTask?.cancel()
        transcriptionService.stopLiveTranscription()
    }

    func startTranscription() {
        //
    }

    func stopTranscription() {
        //
    }

    func reset() {
        stopTranscription()
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
