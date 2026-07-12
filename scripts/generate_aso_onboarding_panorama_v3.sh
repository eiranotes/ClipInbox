#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/docs/app-store/generated/aso-onboarding-panorama-v3"
SOURCE="$OUTPUT/source/panorama-onboarding-imagegen.png"
UPLOAD="$OUTPUT/upload/ko-KR"
CACHE="/Users/tofu/Library/Caches/ClipInbox-ASO-Onboarding-v3"

BG="#F3EFE7"
INK="#171714"
YELLOW="#FFD900"
FONT_BOLD="$ROOT/ios/ClipInbox/Fonts/Pretendard-Bold.otf"
FONT_SEMIBOLD="$ROOT/ios/ClipInbox/Fonts/Pretendard-SemiBold.otf"
FONT_REGULAR="$ROOT/ios/ClipInbox/Fonts/Pretendard-Regular.otf"

mkdir -p "$UPLOAD" "$CACHE"

for required in "$SOURCE" "$FONT_BOLD" "$FONT_SEMIBOLD" "$FONT_REGULAR"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing source asset: $required" >&2
    exit 1
  fi
done

copy_for() {
  case "$1" in
    1)
      HEADLINE=$'링크 저장,\n공유 한 번이면 끝'
      BODY=$'보고 있던 페이지를\n바로 보내세요'
      ;;
    2)
      HEADLINE=$'입력 없이\n인박스에 쏙'
      BODY=$'제목과 주소는 알아서\n담아줘요'
      ;;
    3)
      HEADLINE=$'저장한 링크,\n바로 찾아요'
      BODY=$'검색하고 폴더로\n가볍게 정리'
      ;;
  esac
}

make_text_layers() {
  local index="$1"
  copy_for "$index"

  magick -background none -fill "$INK" -font "$FONT_BOLD" -weight 700 \
    -pointsize 156 -interline-spacing -8 -size 1140x470 \
    caption:"$HEADLINE" "$CACHE/headline-$index.png"
  magick -background none -fill "$INK" -font "$FONT_SEMIBOLD" -weight 600 \
    -pointsize 68 -interline-spacing 0 -size 1050x220 \
    caption:"$BODY" "$CACHE/body-$index.png"
}

compose_master() {
  local master="$CACHE/triptych-master.png"
  local next="$CACHE/triptych-next.png"

  magick "$SOURCE" -resize '3960x1800!' -alpha off -colorspace sRGB \
    "$CACHE/panorama-art.png"
  magick -size 3960x2868 "xc:$BG" \
    "$CACHE/panorama-art.png" -geometry +0+1068 -composite \
    -alpha off -colorspace sRGB "$master"

  for index in 1 2 3; do
    local panel_x=$(( (index - 1) * 1320 ))
    local text_x=$(( panel_x + 76 ))
    local bar_x=$(( panel_x + 38 ))
    local note_left=$(( panel_x + 48 ))
    local note_right=$(( panel_x + 1230 ))
    make_text_layers "$index"
    magick "$master" \
      -fill "$YELLOW" -draw "roundrectangle $bar_x,110 $((bar_x + 30)),505 15,15" \
      -fill "$YELLOW" -draw "polygon $note_left,635 $note_right,615 $((note_right - 24)),900 $((note_left + 18)),920" \
      "$CACHE/headline-$index.png" -geometry +$text_x+120 -composite \
      "$CACHE/body-$index.png" -geometry +$text_x+660 -composite \
      -alpha off -colorspace sRGB "$next"
    mv "$next" "$master"
  done

  cp "$master" "$OUTPUT/triptych-ko-KR.png"
  magick "$master" -crop 1320x2868+0+0 +repage \
    "$UPLOAD/01-link-inbox.png"
  magick "$master" -crop 1320x2868+1320+0 +repage \
    "$UPLOAD/02-share-save.png"
  magick "$master" -crop 1320x2868+2640+0 +repage \
    "$UPLOAD/03-find-organize.png"

  magick montage \
    "$UPLOAD/01-link-inbox.png" \
    "$UPLOAD/02-share-save.png" \
    "$UPLOAD/03-find-organize.png" \
    -thumbnail 330x717 -tile 3x1 -geometry +24+24 \
    -font "$FONT_REGULAR" -label '' \
    -background "$BG" "$OUTPUT/contact-sheet-ko-KR.png"
}

compose_master

for file in "$UPLOAD"/*.png; do
  dimensions="$(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixelWidth|pixelHeight/{print $2}' | paste -sdx -)"
  alpha="$(sips -g hasAlpha "$file" | awk '/hasAlpha/{print $2}')"
  if [[ "$dimensions" != "1320x2868" || "$alpha" != "no" ]]; then
    echo "Invalid upload asset: $file ($dimensions, alpha=$alpha)" >&2
    exit 1
  fi
done

reconstructed="$CACHE/reconstructed.png"
magick \
  "$UPLOAD/01-link-inbox.png" \
  "$UPLOAD/02-share-save.png" \
  "$UPLOAD/03-find-organize.png" \
  +append "$reconstructed"

pixel_diff="$(compare -metric AE "$OUTPUT/triptych-ko-KR.png" "$reconstructed" null: 2>&1 || true)"
pixel_diff="${pixel_diff%% *}"
if [[ "$pixel_diff" != "0" ]]; then
  echo "Triptych reconstruction differs from the master" >&2
  exit 1
fi

echo "Generated the onboarding-style Korean panorama under $UPLOAD"
