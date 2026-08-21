//
//  ContentView.swift
//  Localisten
//
//  Created by Timo Köthe on 08.08.26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Transcription", systemImage: "microphone.fill") {
                LiveTranscriptionView()
            }

            Tab("Audio File", systemImage: "doc.fill") {
                AudioFileTranscriptionView()
            }
        }
        .tint(Color("Tint"))
    }
}

#Preview {
    ContentView()
}
