#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
source_root="$repo_root/docs/app-store/ASO"
output_root="$repo_root/docs/app-store/generated/final-aso"

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick 'magick' is required." >&2
  exit 1
fi

render_locale() {
  source_prefix=$1
  locale=$2
  locale_output="$output_root/$locale"
  mkdir -p "$locale_output"

  magick "$source_root/${source_prefix} (1).png" -resize 1320x2868\! -colorspace sRGB -alpha off -strip "$locale_output/01-find-fast.png"
  magick "$source_root/${source_prefix} (2).png" -resize 1320x2868\! -colorspace sRGB -alpha off -strip "$locale_output/02-save-instantly.png"
  magick "$source_root/${source_prefix} (3).png" -resize 1320x2868\! -colorspace sRGB -alpha off -strip "$locale_output/03-organize-later.png"
}

render_locale aso_kr ko-KR
render_locale aso_en en-US
render_locale aso_jp ja-JP

find "$output_root" -type f -name '*.png' -print | sort
