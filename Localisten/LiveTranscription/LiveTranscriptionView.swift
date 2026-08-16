//
//  LiveTranscriptionView.swift
//  Localisten
//
//  Created by Timo Köthe on 12.08.26.
//

import SwiftUI

struct LiveTranscriptionView: View {
    @State private var viewModel = LiveTranscriptionViewModel()

    var body: some View {
        Text("Live Transcription View")
    }
}

#Preview {
    LiveTranscriptionView()
}
