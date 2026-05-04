# Third-party components (App Store Preview Converter)

This document describes executable binaries that may be **bundled** with the macOS app target, and what that implies when you **redistribute** the app or this repository.

> **Disclaimer:** This is **informational**, not legal advice. If you ship software publicly or commercially, confirm obligations with qualified counsel.

---

## What is bundled

The app may ship these files inside the built `.app`:

- `Contents/Resources/ffmpeg`
- `Contents/Resources/ffprobe`
- `Contents/Resources/Binaries/ffmpeg` *(copy phase / legacy layout — verify in your build)*
- `Contents/Resources/Binaries/ffprobe`

In this repository, the canonical copies live under:

- `AppStorePreviewConverter/Binaries/ffmpeg`
- `AppStorePreviewConverter/Binaries/ffprobe`

---

## FFmpeg build characteristics (as committed here)

The copies currently committed were built from **FFmpeg upstream** and are approximately described by the following (the **authoritative** record is always whatever your binary prints from `ffmpeg -version`):

| Field | Value |
|------|------|
| **Reported version** | `N-124300-gdba0b078c8` |
| **Compiler** | Apple clang |
| **Notable configure flags** | `--enable-static --disable-shared` |
| | `--pkg-config-flags=--static` |
| | `--enable-gpl` |
| | `--enable-libx264` |

Your local builder may also show extra `--prefix`, `--extra-cflags`, and `--extra-ldflags` paths in the printed `configuration:` line.

### How to verify on your machine

From the repository root:

```bash
./AppStorePreviewConverter/Binaries/ffmpeg -version
./AppStorePreviewConverter/Binaries/ffprobe -version
```

---

## FFmpeg (project licensing overview)

- **Project:** [FFmpeg](https://ffmpeg.org/)
- **Upstream overview:** [FFmpeg legal / licensing considerations](https://www.ffmpeg.org/legal.html)
- **License text aggregation:** [FFmpeg `LICENSE.md` (GitHub)](https://github.com/FFmpeg/FFmpeg/blob/master/LICENSE.md)

FFmpeg’s own documentation explains that **optional GPL parts** exist, and that enabling certain options changes what license terms apply to the **resulting binaries**.

In particular, this repository’s bundled FFmpeg is configured with **`--enable-gpl`**.

---

## x264 (`--enable-libx264`)

Building FFmpeg with `--enable-libx264` links against **libx264**, which is **GPLv2+** software in typical distributions.

Combined with FFmpeg’s **`--enable-gpl`**, treat the resulting `ffmpeg`/`ffprobe` binaries as **GPL-class**, **not** “LGPL-only FFmpeg.”

---

## Redistribution implications (high level)

If you give others the `ffmpeg` / `ffprobe` binaries from this repo (or inside a shipped `.app`), you must follow the **GPL** (and any other applicable) obligations for those binaries, including (depending on how you distribute) items such as:

- correct **license notices**
- providing or offering **corresponding source** in the manner required by the license
- honoring **trademark / branding** guidance when mentioning FFmpeg in UI or marketing: [FFmpeg legal](https://www.ffmpeg.org/legal.html)

The **Swift application source** in this repository is a separate copyright work from FFmpeg itself, but **shipping GPL-enabled FFmpeg inside your app** commonly affects how you should plan overall distribution compliance. A typical open-source approach is to keep your app under a **GPL-compatible** license *or* replace these binaries with a build that matches your intended licensing model.

**Do not** describe this bundle as “LGPL-only FFmpeg.” The shipped configuration here is **GPL-class** because of `--enable-gpl` and `libx264`.

---

## Patents / media formats (separate from copyright)

Copyright licenses (GPL/LGPL) are not the same thing as **codec patent pools** or other rights that may apply to technologies such as **H.264** or **AAC** in some jurisdictions.

If you commercially redistribute tools that produce encoded media, understand your own obligations beyond open-source license compliance.

---

## `ffprobe`

`ffprobe` is built from the same FFmpeg sources as `ffmpeg` and inherits the same license characteristics as the FFmpeg build it came from.
