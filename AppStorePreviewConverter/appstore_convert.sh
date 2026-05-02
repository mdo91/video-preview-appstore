#!/bin/zsh

# =====================================================
# App Store Preview Converter (Updated)
# Converts .mov screen recordings into fully compliant
# App Store–ready .mp4 previews with strict formatting.
#
# Usage:
#   ./appstore_convert.sh input.mov portrait
#   ./appstore_convert.sh input.mov landscape
#
# Optional env (set by the macOS app):
#   FFMPEG, FFPROBE — absolute paths to binaries; default: ffmpeg/ffprobe on PATH
#   OUTPUT_FILE — if set, absolute path for the final .mp4 (e.g. under $TMPDIR); app moves beside source
# =====================================================

INPUT="$1"
ORIENTATION="$2"

FFMPEG="${FFMPEG:-ffmpeg}"
FFPROBE="${FFPROBE:-ffprobe}"

if [[ -z "$INPUT" ]]; then
  echo "❌ Usage: ./appstore_convert.sh <input.mov> [portrait|landscape]"
  exit 1
fi

# Default to portrait if not specified
if [[ -z "$ORIENTATION" ]]; then
  ORIENTATION="portrait"
fi

# Output file (.mp4 required by App Store)
BASENAME=$(basename "$INPUT" .mov)
if [[ -n "${OUTPUT_FILE:-}" ]]; then
  OUTPUT="$OUTPUT_FILE"
else
  OUTPUT="${BASENAME}_appstore.mp4"
fi

# Set resolution based on orientation
if [[ "$ORIENTATION" == "landscape" ]]; then
  # 6.5" iPhone landscape
  SCALE="scale=1920:886:force_original_aspect_ratio=decrease,pad=1920:886:(ow-iw)/2:(oh-ih)/2"
else
  # 6.5" iPhone portrait
  SCALE="scale=886:1920:force_original_aspect_ratio=decrease,pad=886:1920:(ow-iw)/2:(oh-ih)/2"
fi

if [[ -n "${OUTPUT_FILE:-}" ]]; then
  echo "🎬 Converting $INPUT → temp output $OUTPUT ($ORIENTATION mode)…"
else
  echo "🎬 Converting $INPUT → $OUTPUT ($ORIENTATION mode)..."
fi

# Duration (whole seconds) — App Preview requires 15–30 s; Connect often mislabels violations as “too large”.
DURATION=$("$FFPROBE" -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$INPUT" | cut -d. -f1)

if [[ -z "$DURATION" ]] || [[ "$DURATION" -eq 0 ]]; then
  echo "❌ Could not determine video duration"
  exit 1
fi

TRIM_ARGS=()
if [[ "$DURATION" -gt 30 ]]; then
  echo "⚠️ Source longer than 30s; trimming output to 30s (App Store preview maximum)."
  TRIM_ARGS=(-t 30)
fi

EFFECTIVE_DUR=$DURATION
if [[ "$DURATION" -gt 30 ]]; then
  EFFECTIVE_DUR=30
fi

VIDEO_FILTER="$SCALE"
if [[ "$EFFECTIVE_DUR" -lt 15 ]]; then
  PAD_SEC=$((15 - EFFECTIVE_DUR))
  echo "⚠️ Source under 15s after trim; padding end ${PAD_SEC}s (App Store preview minimum)."
  VIDEO_FILTER="${VIDEO_FILTER},tpad=stop_mode=clone:stop_duration=${PAD_SEC}"
fi
# Sample aspect ratio must be 1:1 or Connect can reject / misreport (see App Preview specs).
VIDEO_FILTER="${VIDEO_FILTER},setsar=1"

# Apple H.264 preview **target** bitrate is 10–12 Mbps (not “use most of 500 MB file cap”).
# High bitrate encodes confuse validation and can trigger “preview too large” / level issues.
V_TARGET_K=11000
V_MAX_K=12000
V_BUF_K=$((V_MAX_K * 2))

echo "📊 Source ~${DURATION}s | H.264 ${V_TARGET_K}k target (10–12 Mbps) | High@L4.0 | AAC 256k"

# Two-pass stats must be writable under App Sandbox (see OUTPUT_FILE / TMPDIR notes elsewhere).
PASSLOG_PREFIX="${TMPDIR:-/tmp}/appstore_preview_$$"

# Silent stereo AAC (Apple requires stereo AAC for previews; video-only sources need anullsrc).
ANULL="anullsrc=channel_layout=stereo:sample_rate=48000"

run_pass() {
  local passn=$1
  shift
  "$FFMPEG" -nostdin \
    -i "$INPUT" \
    "${TRIM_ARGS[@]}" \
    -f lavfi -i "$ANULL" \
    -map 0:v:0 -map 1:a:0 \
    -shortest \
    -vf "$VIDEO_FILTER" \
    -r 30 -fps_mode cfr \
    -c:v libx264 -profile:v high -level 4.0 -preset slow \
    -b:v ${V_TARGET_K}k -maxrate ${V_MAX_K}k -bufsize ${V_BUF_K}k \
    -pix_fmt yuv420p \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
    -c:a aac -b:a 256k -ar 48000 -ac 2 \
    -passlogfile "$PASSLOG_PREFIX" \
    -pass "$passn" \
    "$@"
}

# -------------------------
# PASS 1: analysis
# -------------------------
run_pass 1 -f null /dev/null

if [[ $? -ne 0 ]]; then
  echo "❌ First pass failed."
  exit 1
fi

# -------------------------
# PASS 2: final output
# -------------------------
run_pass 2 -movflags +faststart "$OUTPUT"

EXIT_CODE=$?

# Cleanup two-pass logs (temp prefix + any legacy names in cwd)
rm -f "${PASSLOG_PREFIX}-0.log" "${PASSLOG_PREFIX}-0.log.mbtree"
rm -f ffmpeg2pass-0.log ffmpeg2pass-0.log.mbtree

if [[ $EXIT_CODE -eq 0 ]]; then
  OUTPUT_SIZE=$(du -h "$OUTPUT" | cut -f1)
  echo "✅ Success! Created: $OUTPUT (${OUTPUT_SIZE})"
else
  echo "❌ Conversion failed."
  exit 1
fi
