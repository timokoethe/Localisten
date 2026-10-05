//
//  LiveTranscriptionView.swift
//  Localisten
//
//  Created by Timo Köthe on 12.08.26.
//

import SwiftUI

struct LiveTranscriptionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: LiveTranscriptionViewModel

    init(initialState: LiveTranscriptionViewModel.State = .idle) {
        _viewModel = State(initialValue: LiveTranscriptionViewModel(initialState: initialState))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                stateContent

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .navigationTitle("Live Transcription")
            .onDisappear {
                viewModel.stopTranscription()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    viewModel.stopTranscription()
                }
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.state {
        case .idle, .preparing:
            ContentUnavailableView {
                Label("Ready to Listen", systemImage: "mic")
            } description: {
                Text("Start live transcription to capture speech from the microphone.")
            } actions: {
                startButton
                    .disabled(viewModel.state == .preparing)
            }

        case .recording(let transcription):
            transcriptContent(
                title: "Listening",
                systemImage: "waveform",
                transcription: transcription,
                isRecording: true
            )

        case .stopped(let transcription):
            transcriptContent(
                title: "Recording Stopped",
                systemImage: "stop.circle.fill",
                transcription: transcription,
                isRecording: false
            )

        case .failed(let message):
            ContentUnavailableView {
                Label("Live Transcription Failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                startButton
            }
        }
    }

    private func transcriptContent(
        title: String,
        systemImage: String,
        transcription: String,
        isRecording: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color("Tint"))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(isRecording ? "Microphone is active" : "Microphone is off")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isRecording {
                    Button {
                        viewModel.stopTranscription()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("Tint"))
                } else {
                    Button {
                        viewModel.reset()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .tint(Color("Tint"))
                }
            }

            Divider()

            Text("Transcript")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(transcription.isEmpty ? "Speech will appear here as it is recognized." : transcription)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundStyle(transcription.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Color(.secondarySystemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("Tint").opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var startButton: some View {
        Button {
            viewModel.startTranscription()
        } label: {
            Label("Start Listening", systemImage: "mic.fill")
        }
        .buttonStyle(.borderedProminent)
        .tint(Color("Tint"))
    }
}

#Preview {
    LiveTranscriptionView()
}

#Preview("Recording") {
    LiveTranscriptionView(
        initialState: .recording(
            transcription: "Welcome to Localisten. This is a live transcription preview with text arriving from the microphone."
        )
    )
}

#Preview("Stopped") {
    LiveTranscriptionView(
        initialState: .stopped(
            transcription: "The recording has stopped, and the final live transcript remains available for review."
        )
    )
}
