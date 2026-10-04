#!/usr/bin/env bash
#
# Generates thumbnail previews for the wallpaper picker's grid.
#
# The grid used to load every wallpaper at full resolution. With a few
# thousand images that meant decoding ~100 MB JPEGs per cell just to paint a
# 370 px box, which is what made the overlay crawl while scrolling. This
# script writes one small JPEG per wallpaper so the grid only ever decodes a
# few hundred pixels' worth of pixels.
#
# Thumb layout mirrors the source tree (minus the leading slash), so the
# plugin can derive a thumbnail path from a wallpaper path with a single
# string concatenation -- no manifest, no index, nothing to get out of sync:
#
#   ~/Pictures/Wallpapers-sorted/anime/foo.jpg
#   ~/.cache/wallpicker-grid/thumbs/home/mihai/Pictures/.../foo.jpg.jpg
#
# Re-running is cheap. A thumbnail is only rewritten when it is missing or
# older than its source, so this is safe to wire up to a systemd timer or run
# after a bulk import.
#
# Usage:
#   ./thumbnails.sh                     # both default wallpaper roots
#   ./thumbnails.sh ~/Pictures/Other    # only the roots given
#   ./thumbnails.sh --size 640          # wider thumbs (HiDPI grids)
#   ./thumbnails.sh --jobs 4            # cap parallelism (default: nproc/2)
#   ./thumbnails.sh --backend magick    # force a backend instead of probing

set -euo pipefail

SIZE=512
JOBS=0
CACHE_ROOT=""
WANT_BACKEND=auto

# The same two roots WallpaperPicker.qml scans by default. Keep in sync.
DEFAULT_ROOTS=(
  "$HOME/Pictures/Wallpapers"
  "$HOME/Pictures/Wallpapers-sorted"
)

usage() {
  # The comment block at the top, up to its first blank line. Hardcoding a
  # line range would start printing code the moment the header grew a line.
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  printf 'thumbnails: %s\n' "$1" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -s | --size)
      [ $# -ge 2 ] || die "--size needs a value"
      SIZE=$2
      shift 2
      ;;
    -j | --jobs)
      [ $# -ge 2 ] || die "--jobs needs a value"
      JOBS=$2
      shift 2
      ;;
    -c | --cache)
      [ $# -ge 2 ] || die "--cache needs a value"
      CACHE_ROOT=$2
      shift 2
      ;;
    -b | --backend)
      [ $# -ge 2 ] || die "--backend needs a value"
      WANT_BACKEND=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
done

ROOTS=("$@")
[ ${#ROOTS[@]} -gt 0 ] || ROOTS=("${DEFAULT_ROOTS[@]}")

[ -n "$CACHE_ROOT" ] || CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/wallpicker-grid/thumbs"

case "$SIZE" in
  '' | *[!0-9]*) die "--size must be a positive integer, got '$SIZE'" ;;
esac
[ "$SIZE" -gt 0 ] || die "--size must be greater than 0"

if [ "$JOBS" -eq 0 ]; then
  CPUS=$(nproc 2>/dev/null || echo 4)
  JOBS=$((CPUS / 2))
  [ "$JOBS" -lt 1 ] && JOBS=1
fi

# vipsthumbnail decodes through libvips with shrink-on-load, which is roughly
# 3x faster than an ImageMagick pass and writes noticeably smaller files.
# ImageMagick is kept as a fallback so the script still works without libvips.
pick_backend() {
  case "$WANT_BACKEND" in
    auto)
      if command -v vipsthumbnail >/dev/null 2>&1; then
        printf vips
      elif command -v magick >/dev/null 2>&1; then
        printf magick
      elif command -v convert >/dev/null 2>&1; then
        printf convert
      else
        die "need vipsthumbnail (libvips) or ImageMagick"
      fi
      ;;
    vips)
      command -v vipsthumbnail >/dev/null 2>&1 || die "vipsthumbnail not found"
      printf vips
      ;;
    magick | convert)
      if [ "$WANT_BACKEND" = magick ]; then
        command -v magick >/dev/null 2>&1 || die "magick not found"
        printf magick
      else
        command -v convert >/dev/null 2>&1 || die "convert not found"
        printf convert
      fi
      ;;
    *)
      die "unknown backend '$WANT_BACKEND' (want auto, vips, magick or convert)"
      ;;
  esac
}

BACKEND=$(pick_backend)

printf 'thumbnails: backend=%s size=%s jobs=%s\n' "$BACKEND" "$SIZE" "$JOBS"
printf 'thumbnails: cache=%s\n' "$CACHE_ROOT"

# One wallpaper -> one thumbnail. Written to a temp name and moved into place
# so the picker never picks up a half-written JPEG and show an error tile.
render() {
  local src=$1
  local rel=${src#/}
  local dst="$CACHE_ROOT/$rel.jpg"
  local tmp="$dst.tmp.$$.jpg"

  [ -f "$src" ] || return 0

  if [ -s "$dst" ] && [ ! "$src" -nt "$dst" ]; then
    return 0
  fi

  mkdir -p -- "${dst%/*}" || return 1

  if [ "$BACKEND" = vips ]; then
    # Neither vipsthumbnail nor magick accepts a "--" terminator here (vips
    # reads it as a filename, magick errors out). Not needed anyway: the roots
    # are normalised to absolute paths, so nothing can look like an option.
    vipsthumbnail -s "$SIZE" "$src" -o "$tmp" >/dev/null 2>&1
  else
    "$BACKEND" "$src" -auto-orient -resize "${SIZE}x${SIZE}>" -strip \
      -interlace Plane -quality 82 "$tmp" >/dev/null 2>&1
  fi

  if [ -s "$tmp" ]; then
    mv -f -- "$tmp" "$dst"
  else
    rm -f -- "$tmp"
    return 1
  fi
}

export -f render
export CACHE_ROOT SIZE BACKEND

for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || continue

  # Absolute, so paths handed to the backends can never look like options.
  case "$root" in
    /*) ;;
    *) root="$PWD/$root" ;;
  esac

  # Same extension set as the picker's find filter. -print0 all the way
  # through so spaces and newlines in filenames survive.
  find "$root" -type f \( \
    -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o \
    -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o \
    -iname '*.tiff' \) -print0 2>/dev/null |
    xargs -0 -r -P "$JOBS" -n 1 bash -c '
      render "$1" || printf "thumbnails: failed: %s\n" "$1" >&2
    ' _
done

count=$(find "$CACHE_ROOT" -type f -name '*.jpg' 2>/dev/null | wc -l)
printf 'thumbnails: %s thumbnails in %s\n' "$count" "$CACHE_ROOT"
printf 'thumbnails: done\n'