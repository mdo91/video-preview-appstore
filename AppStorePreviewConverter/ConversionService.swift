//
//  ConversionService.swift
//  AppStorePreviewConverter
//

import AppKit
import Foundation
import UniformTypeIdentifiers

enum ConversionServiceError: LocalizedError {
    case missingConvertScript
    case missingFFmpegTools
    case processFailed(code: Int32, log: String)
    /// User dismissed Save; encoded file remains in temp (`encodingLog` is full encoder output).
    case exportCancelled(tempPath: String, encodingLog: String)

    var errorDescription: String? {
        switch self {
        case .missingConvertScript:
            return "Could not find appstore_convert.sh in the app bundle."
        case .missingFFmpegTools:
            return "ffmpeg/ffprobe not found. Add static binaries named \"ffmpeg\" and \"ffprobe\" under AppStorePreviewConverter/Binaries/ (see Binaries/README.txt), or install Homebrew ffmpeg for DEBUG builds only."
        case .processFailed(let code, let log):
            if log.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Conversion exited with status \(code). No script output (check file access, cwd, and ffmpeg)."
            }
            return "Conversion exited with status \(code). See Log for zsh/ffmpeg details."
        case .exportCancelled(let tempPath, _):
            return "Save was cancelled. Encoded MP4 is still at:\n\(tempPath)"
        }
    }
}

enum ConversionService {
    /// Same stem rule as `appstore_convert.sh`: strip `.mov` when present.
    private static func outputStem(for input: URL) -> String {
        let name = input.lastPathComponent
        if name.lowercased().hasSuffix(".mov") {
            return String(name.dropLast(4))
        }
        return input.deletingPathExtension().lastPathComponent
    }

    /// Encode to a temp file, then **`NSSavePanel`** so the destination URL is security-scoped (required for Desktop etc.).
    static func convert(input: URL, orientation: String) async throws -> String {
        guard let scriptURL = Bundle.main.url(forResource: "appstore_convert", withExtension: "sh") else {
            throw ConversionServiceError.missingConvertScript
        }
        guard let tools = FFmpegToolPaths.resolve() else {
            throw ConversionServiceError.missingFFmpegTools
        }

        let inputDir = input.deletingLastPathComponent()
        let parentScoped = inputDir.startAccessingSecurityScopedResource()
        let fileScoped = input.startAccessingSecurityScopedResource()
        defer {
            if fileScoped { input.stopAccessingSecurityScopedResource() }
            if parentScoped { inputDir.stopAccessingSecurityScopedResource() }
        }

        let scriptPath = scriptURL.path
        let inputPath = input.path
        let ffmpeg = tools.ffmpeg
        let ffprobe = tools.ffprobe
        let inputDirPath = inputDir.path

        let stem = outputStem(for: input)
        let tempOutputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("appstore_preview_\(UUID().uuidString).mp4")

        let debugHeader = """
            --- Conversion debug ---
            script: \(scriptPath)
            cwd: \(inputDirPath)
            input: \(inputPath)
            orientation: \(orientation)
            FFMPEG=\(ffmpeg)
            FFPROBE=\(ffprobe)
            OUTPUT_FILE (temp)= \(tempOutputURL.path)
            export: NSSavePanel (sandbox — see Apple “Accessing files from the macOS App Sandbox”)
            ---

            """

        let encodeLog: String
        do {
            encodeLog = try await Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-f", scriptPath, inputPath, orientation]
                process.currentDirectoryURL = URL(fileURLWithPath: inputDirPath, isDirectory: true)

                var env = ProcessInfo.processInfo.environment
                env["FFMPEG"] = ffmpeg
                env["FFPROBE"] = ffprobe
                env["OUTPUT_FILE"] = tempOutputURL.path
                process.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                var outData = Data()
                var errData = Data()
                let drain = DispatchGroup()
                drain.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    drain.leave()
                }
                drain.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    drain.leave()
                }

                do {
                    try process.run()
                } catch {
                    drain.wait()
                    let msg = "Failed to start zsh process: \(error.localizedDescription)\n\(error)"
                    throw ConversionServiceError.processFailed(code: -1, log: debugHeader + msg)
                }

                process.waitUntilExit()
                drain.wait()

                let combined = String(data: outData + errData, encoding: .utf8)
                    ?? "(Could not decode process output as UTF-8; raw bytes: \(outData.count + errData.count))"

                let code = process.terminationStatus
                let fullLog = debugHeader + combined
                if code != 0 {
                    throw ConversionServiceError.processFailed(code: code, log: fullLog)
                }
                return fullLog
            }.value
        } catch {
            try? FileManager.default.removeItem(at: tempOutputURL)
            throw error
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: tempOutputURL.path) else {
            throw ConversionServiceError.processFailed(
                code: -2,
                log: encodeLog + "\nEncoder finished but temp file is missing: \(tempOutputURL.path)\n"
            )
        }

        let exportedPath: String
        do {
            exportedPath = try await MainActor.run {
                let panel = NSSavePanel()
                panel.directoryURL = input.deletingLastPathComponent()
                panel.nameFieldStringValue = "\(stem)_appstore.mp4"
                panel.allowedContentTypes = [.mpeg4Movie]
                panel.canCreateDirectories = true
                panel.isExtensionHidden = false
                panel.title = "Export App Store preview"
                panel.message = "App Sandbox only allows writing here after you confirm the path (same as Finder “Export”). Desktop and Documents are protected."

                guard panel.runModal() == .OK, let dest = panel.url else {
                    throw ConversionServiceError.exportCancelled(tempPath: tempOutputURL.path, encodingLog: encodeLog)
                }

                let scoped = dest.startAccessingSecurityScopedResource()
                defer {
                    if scoped { dest.stopAccessingSecurityScopedResource() }
                }

                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.copyItem(at: tempOutputURL, to: dest)
                return dest.path
            }
        } catch let err as ConversionServiceError {
            throw err
        } catch {
            let extra = "\n— Save / copy failed —\n\(error.localizedDescription)\nTemp file kept at: \(tempOutputURL.path)\n"
            throw ConversionServiceError.processFailed(code: -3, log: encodeLog + extra)
        }

        try? fm.removeItem(at: tempOutputURL)

        return encodeLog + "\n✅ Exported to: \(exportedPath)\n"
    }
}
