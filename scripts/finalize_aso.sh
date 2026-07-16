#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
source_root="$repo_root/docs/app-store/ASO"
output_root="$repo_root/docs/app-store/generated/final-aso"
target_width=1284
target_height=2778

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick 'magick' is required." >&2
  exit 1
fi

render_locale() {
  source_prefix=$1
  locale=$2
  locale_output="$output_root/$locale"
  mkdir -p "$locale_output"

  magick "$source_root/${source_prefix} (1).png" -resize "${target_width}x${target_height}^" -gravity center -extent "${target_width}x${target_height}" -colorspace sRGB -alpha off -depth 8 -strip "$locale_output/01-find-fast.png"
  magick "$source_root/${source_prefix} (2).png" -resize "${target_width}x${target_height}^" -gravity center -extent "${target_width}x${target_height}" -colorspace sRGB -alpha off -depth 8 -strip "$locale_output/02-save-instantly.png"
  magick "$source_root/${source_prefix} (3).png" -resize "${target_width}x${target_height}^" -gravity center -extent "${target_width}x${target_height}" -colorspace sRGB -alpha off -depth 8 -strip "$locale_output/03-organize-later.png"
}

# final-aso contains upload files only. Contact sheets are reproducible QA output.
rm -f "$output_root"/contact-sheet-*.png

render_locale aso_kr ko-KR
render_locale aso_en en-US
render_locale aso_jp ja-JP

for file in "$output_root"/*/0[1-3]-*.png; do
  dimensions=$(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixelWidth|pixelHeight/{print $2}' | paste -sdx -)
  alpha=$(sips -g hasAlpha "$file" | awk '/hasAlpha/{print $2}')
  depth=$(magick identify -format '%z' "$file")
  colorspace=$(magick identify -format '%[colorspace]' "$file")
  if [ "$dimensions" != "${target_width}x${target_height}" ] || [ "$alpha" != "no" ] || [ "$depth" != "8" ] || [ "$colorspace" != "sRGB" ]; then
    echo "Invalid upload asset: $file ($dimensions, alpha=$alpha, depth=$depth, colorspace=$colorspace)" >&2
    exit 1
  fi
done

find "$output_root" -type f -name '*.png' -print | sort
