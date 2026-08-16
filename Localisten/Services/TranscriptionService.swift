//
//  TranscriptionService.swift
//  Localisten
//
//  Created by Timo Köthe on 16.08.26.
//

import Foundation

final class TranscriptionService {
    static let shared = TranscriptionService()

    private init() {}

    func startLiveTranscription() async throws {}

    func stopLiveTranscription() {}

    func transcribeAudioFile(at url: URL) async throws -> String {
        ""
    }
}
