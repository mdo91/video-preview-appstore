//
//  ContentView.swift
//  AppStorePreviewConverter
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation

private struct QueueItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
}

struct ContentView: View {
    @State private var queue: [QueueItem] = []
    @State private var selection: UUID?
    @State private var orientation: Orientation = .portrait
    @State private var logText = ""
    @State private var isConverting = false
    @State private var lastError: String?
    @State private var showImporter = false
    @State private var dragOver = false

    private enum Orientation: String, CaseIterable, Identifiable {
        case portrait
        case landscape
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolsStatusRow

            Text("Drop video files or add them with the button. After encoding, choose where to save *_appstore.mp4 (Save sheet — required for Desktop under App Sandbox).")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Add files…") { showImporter = true }
                Picker("Orientation", selection: $orientation) {
                    ForEach(Orientation.allCases) { o in
                        Text(o.label).tag(o)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)

                Spacer()

                Button(action: {
                    Task { await runQueue() }
                }) {
                    HStack(spacing: 8) {
                        if isConverting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isConverting ? "Converting..." : "Convert queue")
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(queue.isEmpty || isConverting)
            }

            List(selection: $selection) {
                ForEach(queue) { item in
                    HStack {
                        Text(item.url.lastPathComponent)
                            .lineLimit(1)
                        Spacer()
                        Button(role: .destructive) {
                            removeQueueItem(id: item.id)
                        }
                        .buttonStyle(.borderless)
                        .disabled(isConverting)
                    }
                    .tag(item.id)
                }
            }
            .frame(minHeight: 120)
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(dragOver ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: dragOver ? [] : [6]))
            }
            .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
                Task { await loadDroppedProviders(providers) }
                return true
            }

            GroupBox("Log") {
                ScrollView {
                    Text(logText.isEmpty ? "…" : logText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 220)
            }

            if let lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 420)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie, .video],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                addToQueue(urls)
            case .failure(let err):
                lastError = err.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var toolsStatusRow: some View {
        HStack(spacing: 8) {
            if FFmpegToolPaths.resolve() != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("ffmpeg / ffprobe available")
                    .font(.subheadline)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Add ffmpeg + ffprobe to Binaries/ (see README there).")
                    .font(.subheadline)
            }
        }
    }

    private func loadDroppedProviders(_ providers: [NSItemProvider]) async {
        var urls: [URL] = []
        for provider in providers {
            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) {
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                } else if let url = item as? URL {
                    urls.append(url)
                }
            }
        }
        await MainActor.run {
            addToQueue(urls)
        }
    }

    private func addToQueue(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let newItems = urls.map { QueueItem(id: UUID(), url: $0) }
        queue.append(contentsOf: newItems)
        selection = newItems.last?.id
    }

    private func removeQueueItem(id: UUID) {
        let isSelected = (selection == id)
        queue.removeAll { $0.id == id }
        if queue.isEmpty {
            selection = nil
        } else if isSelected {
            selection = queue.first?.id
        }
    }

    @MainActor
    private func runQueue() async {
        lastError = nil
        isConverting = true
        defer { isConverting = false }

        guard FFmpegToolPaths.resolve() != nil else {
            lastError = ConversionServiceError.missingFFmpegTools.localizedDescription
            return
        }

        let itemsToConvert: [QueueItem]
        if let selected = selection, let idx = queue.firstIndex(where: { $0.id == selected }) {
            itemsToConvert = Array(queue[idx...])
        } else {
            itemsToConvert = queue
        }

        for item in itemsToConvert {
            selection = item.id
            let url = item.url
            logText += "\n—— \(url.lastPathComponent) ——\n"
            do {
                let output = try await ConversionService.convert(input: url, orientation: orientation.rawValue)
                logText += output + (output.hasSuffix("\n") ? "" : "\n")
            } catch {
                if let conv = error as? ConversionServiceError {
                    switch conv {
                    case .processFailed(let code, let log):
                        logText += log + (log.hasSuffix("\n") ? "" : "\n")
                        lastError = "Conversion failed (exit \(code)). Details are in the log above."
                    case .exportCancelled(_, let encodingLog):
                        logText += encodingLog + (encodingLog.hasSuffix("\n") ? "" : "\n")
                        lastError = conv.localizedDescription
                    default:
                        let msg = conv.localizedDescription
                        lastError = msg
                        logText += "Error: \(msg)\n"
                    }
                } else {
                    let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    lastError = msg
                    logText += "Error: \(msg)\n"
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
