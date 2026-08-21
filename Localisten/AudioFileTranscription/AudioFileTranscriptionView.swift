//
//  AudioFileTranscriptionView.swift
//  Localisten
//
//  Created by Timo Köthe on 16.08.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct AudioFileTranscriptionView: View {
    @State private var viewModel: AudioFileTranscriptionViewModel

    init(initialState: AudioFileTranscriptionViewModel.State = .idle) {
        _viewModel = State(initialValue: AudioFileTranscriptionViewModel(initialState: initialState))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                stateContent

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .navigationTitle("Audio File")
            .fileImporter(
                isPresented: $viewModel.isFileImporterPresented,
                allowedContentTypes: [.audio],
                onCompletion: viewModel.transcribeSelectedFile(from:)
            )
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.state {
        case .idle, .importing:
            ContentUnavailableView {
                Label("No Audio File", systemImage: "waveform")
            } description: {
                Text("Choose an audio file to transcribe it locally.")
            } actions: {
                Button {
                    viewModel.selectAudioFile()
                } label: {
                    Label("Add Audio File", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
            }

        case .transcribing(let fileName):
            VStack(alignment: .leading, spacing: 16) {
                Label(fileName, systemImage: "doc.fill")
                    .font(.headline)

                ProgressView("Transcribing...")
                    .progressViewStyle(.linear)
            }

        case .completed(let fileName, let transcription):
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color("Tint"))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transcription Complete")
                            .font(.headline)

                        Text(fileName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        viewModel.reset()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .tint(Color("Tint"))
                }

                Divider()

                Text("Transcript")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ScrollView {
                    Text(transcription)
                        .font(.body)
                        .lineSpacing(4)
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

        case .failed(let message):
            ContentUnavailableView {
                Label("Transcription Failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button {
                    viewModel.selectAudioFile()
                } label: {
                    Label("Choose Another File", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var isTranscribing: Bool {
        if case .transcribing = viewModel.state {
            true
        } else {
            false
        }
    }

}

#Preview {
    AudioFileTranscriptionView()
}

#Preview("Completed") {
    AudioFileTranscriptionView(
        initialState: .completed(
            fileName: "Interview.m4a",
            transcription: """
            Thanks for joining the recording. Today we are reviewing the first version of Localisten's audio-file transcription flow.

            The main workflow is simple: select an audio file, wait for local speech analysis to finish, and then review the completed transcript in a selectable text view.
            """
        )
    )
}
