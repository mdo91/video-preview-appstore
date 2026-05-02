//
//  FFmpegToolPaths.swift
//  AppStorePreviewConverter
//

import Foundation

enum FFmpegToolPaths {
    /// Resolves bundled `ffmpeg` and `ffprobe` (under `Resources/` or `Resources/Binaries/`).
    /// Tries flat `Resources/` first: Xcode file-system sync often copies `Binaries/*` without preserving the subfolder.
    static func resolve(bundle: Bundle = .main) -> (ffmpeg: String, ffprobe: String)? {
        let fm = FileManager.default

        if let pair = resolveBundled(in: bundle, fm: fm) {
            return pair
        }
#if DEBUG
        let fallbacks: [(String, String)] = [
            ("/opt/homebrew/bin/ffmpeg", "/opt/homebrew/bin/ffprobe"),
            ("/usr/local/bin/ffmpeg", "/usr/local/bin/ffprobe"),
        ]
        for pair in fallbacks where fm.isExecutableFile(atPath: pair.0) && fm.isExecutableFile(atPath: pair.1) {
            return pair
        }
#endif
        return nil
    }

    private static func resolveBundled(in bundle: Bundle, fm: FileManager) -> (ffmpeg: String, ffprobe: String)? {
        let candidates: [(URL, URL)] = bundledCandidatePairs(bundle: bundle)
        for (ffmpegURL, ffprobeURL) in candidates {
            let fp = ffmpegURL.path
            let fq = ffprobeURL.path
            guard fm.fileExists(atPath: fp), fm.fileExists(atPath: fq) else { continue }
            guard fm.isExecutableFile(atPath: fp), fm.isExecutableFile(atPath: fq) else { continue }
            return (fp, fq)
        }
        return nil
    }

    /// Ordered list of (ffmpeg, ffprobe) URL pairs to try inside the bundle.
    private static func bundledCandidatePairs(bundle: Bundle) -> [(URL, URL)] {
        var pairs: [(URL, URL)] = []

        if let res = bundle.resourceURL {
            // Xcode file-system sync often copies `AppStorePreviewConverter/Binaries/*` flat into `Resources/` (no `Binaries/` subfolder).
            pairs.append((res.appendingPathComponent("ffmpeg"), res.appendingPathComponent("ffprobe")))
            pairs.append((res.appendingPathComponent("Binaries/ffmpeg"), res.appendingPathComponent("Binaries/ffprobe")))
        }

        // Explicit Contents/Resources paths (flat and nested).
        let contentsRes = bundle.bundleURL.appendingPathComponent("Contents/Resources")
        pairs.append((contentsRes.appendingPathComponent("ffmpeg"), contentsRes.appendingPathComponent("ffprobe")))
        let contentsBin = contentsRes.appendingPathComponent("Binaries")
        pairs.append((contentsBin.appendingPathComponent("ffmpeg"), contentsBin.appendingPathComponent("ffprobe")))

        if let u1 = bundle.url(forResource: "ffmpeg", withExtension: "", subdirectory: "Binaries"),
           let u2 = bundle.url(forResource: "ffprobe", withExtension: "", subdirectory: "Binaries") {
            pairs.append((u1, u2))
        }
        if let u1 = bundle.url(forResource: "ffmpeg", withExtension: nil, subdirectory: "Binaries"),
           let u2 = bundle.url(forResource: "ffprobe", withExtension: nil, subdirectory: "Binaries") {
            pairs.append((u1, u2))
        }

        return pairs
    }
}
