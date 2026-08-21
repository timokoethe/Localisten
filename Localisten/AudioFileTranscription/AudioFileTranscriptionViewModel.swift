//
//  AudioFileTranscriptionViewModel.swift
//  Localisten
//
//  Created by Timo Köthe on 16.08.26.
//

import Observation
import Foundation

@Observable
final class AudioFileTranscriptionViewModel {
    /// The complete UI state for audio-file transcription.
    ///
    /// - `idle`: No file is selected and no transcription has started.
    /// - `importing`: The system file picker is visible.
    /// - `transcribing`: A file is selected and speech analysis is running.
    /// - `completed`: Transcription finished successfully and contains displayable text.
    /// - `failed`: Importing or transcription failed with a user-facing message.
    enum State: Equatable {
        case idle
        case importing
        case transcribing(fileName: String)
        case completed(fileName: String, transcription: String)
        case failed(message: String)
    }

    var state: State

    var isFileImporterPresented: Bool {
        get {
            state == .importing
        }
        set {
            if newValue {
                state = .importing
            } else if state == .importing {
                state = .idle
            }
        }
    }

    private let transcriptionService: TranscriptionService

    init(
        initialState: State = .idle,
        transcriptionService: TranscriptionService = .shared
    ) {
        self.state = initialState
        self.transcriptionService = transcriptionService
    }

    func selectAudioFile() {
        state = .importing
    }

    func cancelImport() {
        state = .idle
    }

    func transcribeSelectedFile(from result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            transcribeAudioFile(at: url)
        case .failure(let error):
            state = .failed(message: userFacingMessage(for: error))
        }
    }

    func reset() {
        state = .idle
    }

    private func transcribeAudioFile(at url: URL) {
        let fileName = url.lastPathComponent
        state = .transcribing(fileName: fileName)

        Task {
            do {
                let transcription = try await transcriptionService.transcribeAudioFile(at: url)
                state = .completed(fileName: fileName, transcription: transcription)
            } catch {
                state = .failed(message: userFacingMessage(for: error))
            }
        }
    }

    private func userFacingMessage(for error: any Error) -> String {
        if let localizedError = error as? any LocalizedError,
           let errorDescription = localizedError.errorDescription {
            return errorDescription
        }

        return error.localizedDescription
    }
}
