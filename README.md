# App Store Preview Converter

macOS SwiftUI utility that turns screen recordings (typically **QuickTime `.mov`**) into **`.mp4`** files aligned with Apple’s [App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-preview-specifications/) for upload in App Store Connect.

The heavy lifting is done by **`appstore_convert.sh`** (bundled `ffmpeg` / `ffprobe`); the app provides a small queue UI, sandbox-safe export, and bundled encoders.

---

## Features

- **Queue & import** — Add files via drag-and-drop or the file picker; convert the queue one after another.
- **Orientation** — **Portrait** or **landscape** for **6.5" iPhone** preview dimensions (886×1920 or 1920×886 with letterboxing / pillarboxing as needed).
- **App Store–oriented encode** (script-driven):
  - **Duration** — Output kept in the **15–30 second** window: sources longer than 30s are trimmed; shorter clips are padded (clone last frame) to meet the **15s minimum**.
  - **Video** — H.264 **High@Level 4.0**, ~**10–12 Mbps** target band, **30 fps CFR**, **yuv420p**, BT.709 color tags, **`setsar=1`** (square pixels).
  - **Audio** — **AAC 256 kbps**, **48 kHz stereo** (silent stereo if the source has no usable audio track).
  - **Container** — MP4 with **`faststart`** for streaming-friendly layout.
- **Two-pass x264** — Pass logs written under **`$TMPDIR`** so encoding works under the App Sandbox.
- **Sandbox-friendly export** — Encode to a temp file, then **`NSSavePanel`** so the user picks a destination (needed for reliable writes outside the container, e.g. Desktop).
- **Bundled tools** — Ships **`ffmpeg`** and **`ffprobe`** from `AppStorePreviewConverter/Binaries/` (see `Binaries/README.txt` and `THIRD_PARTY.txt`).

---

## Scope

| In scope | Out of scope (today) |
|----------|----------------------|
| macOS app + zsh script for local conversion | Uploading to App Store Connect (use Connect / Transporter separately) |
| 6.5" iPhone portrait/landscape frame sizes | Other device classes (e.g. 5.5", 6.7", iPad) unless you extend the script |
| `.mov` (and paths the script accepts as ffmpeg input) | Full validation of every Connect edge case or regional rule change |
| Developer / side-load use | Notarization, Mac App Store packaging, or automated CI signing (your pipeline) |

Apple’s rules and Connect behavior can change; this project encodes to the published preview spec as understood at build time—**always verify** in Connect after an OS or policy update.

---

## Requirements

- **macOS** with **Xcode** (SwiftUI target).
- **`AppStorePreviewConverter/Binaries/ffmpeg`** and **`ffprobe`** present and executable before archiving for other machines (see `Binaries/README.txt`). Debug builds may fall back to Homebrew `ffmpeg` on PATH when tools are missing—**not** suitable for redistribution as-is.

---

## Building

1. Open **`AppStorePreviewConverter.xcodeproj`** in Xcode.
2. Ensure the Binaries folder contains the two executables (or use PATH in Debug only).
3. **Product → Run** for local testing; **Product → Archive** for distribution builds.

Additional notes: **`BUILD-NOTES.txt`** (Run Script sandboxing, DMG), **`AppStorePreviewConverter.entitlements`** (App Sandbox + user-selected file access).

---

## Command-line usage

The script can be run outside the app (with `ffmpeg`/`ffprobe` on `PATH` or via `FFMPEG` / `FFPROBE` env vars):

```bash
./AppStorePreviewConverter/appstore_convert.sh recording.mov portrait
./AppStorePreviewConverter/appstore_convert.sh recording.mov landscape
```

Optional **`OUTPUT_FILE`** — absolute path for the encoded MP4 (used by the app for temp output).

---

## Future considerations

- **More preview sizes** — Add presets (resolution + aspect) for other iPhone/iPad slots Connect lists, possibly driven by a picker instead of only portrait/landscape 6.5".
- **Smaller repo / clones** — Move large binaries to **Git LFS** or a documented download step so the Git history stays light; keep runtime layout unchanged.
- **Xcode Run Script** — Re-enable **`ENABLE_USER_SCRIPT_SANDBOXING`** with explicit input/output paths if your org requires it (see `BUILD-NOTES.txt`).
- **Output folder access** — Optional **security-scoped bookmark** to a user-chosen folder to skip repeated Save panels for batch exports.
- **UX** — Per-file progress, cancel in-flight encode, remember last orientation and destination.
- **Formats** — Broader input types (e.g. `.mp4` re-encode) with explicit warnings when re-encoding is lossy.
- **Distribution** — Notarization, versioned releases, and optional **Sparkle** or Mac App Store if you productize the tool.
- **Tests** — Golden `ffprobe` checks on short fixtures in CI (no need to run full two-pass on every push).

---

## License

Application source: your repository license (if any). **FFmpeg** is LGPL/GPL components—see **`AppStorePreviewConverter/THIRD_PARTY.txt`** and comply when redistributing binaries.
