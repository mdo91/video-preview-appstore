# Contributing

Thanks for your interest in contributing.

## Before you start

- Search existing **Issues** *and* **Discussions** to avoid duplicates.
- For usage questions (“how should I encode…”, “why did Connect reject…”), prefer **[GitHub Discussions](https://github.com/mdo91/video-preview-appstore/discussions)**.
- For larger changes, open an issue first to align on approach (unless it's strictly a Discussion-level question).
- Keep pull requests focused and small when possible.

## Development setup

1. Open `AppStorePreviewConverter.xcodeproj` in Xcode.
2. Build and run the `AppStorePreviewConverter` scheme.
3. If needed, ensure `AppStorePreviewConverter/Binaries/ffmpeg` and `ffprobe` are present and executable.

## Pull request guidelines

- Use clear commit messages.
- Explain what changed and why.
- Include screenshots for UI changes when relevant.
- Include manual test notes (what you tested and expected result).
- Update docs if behavior, setup, or distribution changed.

## Coding expectations

- Keep changes consistent with existing style.
- Prefer simple, maintainable solutions.
- Avoid unrelated refactors in the same PR.

## Reporting bugs

Please include:

- macOS version
- Xcode version
- Repro steps
- Expected vs actual result
- Relevant logs/output

## Feature requests

Feature requests are welcome. Please describe the use case, constraints, and what a successful outcome looks like.
