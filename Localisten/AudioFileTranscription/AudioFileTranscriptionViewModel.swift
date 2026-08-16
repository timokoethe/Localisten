//
//  AudioFileTranscriptionViewModel.swift
//  Localisten
//
//  Created by Timo Köthe on 16.08.26.
//

import Observation

@Observable
final class AudioFileTranscriptionViewModel {
    private let transcriptionService: TranscriptionService

    init(transcriptionService: TranscriptionService = .shared) {
        self.transcriptionService = transcriptionService
    }
}
