Place ffmpeg and ffprobe here (no file extension), named exactly:

  ffmpeg
  ffprobe

The Xcode target folder AppStorePreviewConverter/ is synchronized into the app bundle, so files in this Binaries/ directory are shipped with the app.

For distribution to other Macs, prefer static builds (no Homebrew Cellar paths). Homebrew’s ffmpeg is dynamically linked to /opt/homebrew/Cellar/ffmpeg/... — it runs on your machine while Homebrew is installed, but can fail on machines without those libraries.

See THIRD_PARTY.txt in this target for FFmpeg license obligations.

For DMG/Archive export and ENABLE_USER_SCRIPT_SANDBOXING, see BUILD-NOTES.txt at the repository root.
