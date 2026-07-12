#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/docs/app-store/generated/aso-panorama-v2"
SOURCE="$OUTPUT/source"
UPLOAD="$OUTPUT/upload/ko-KR"
CACHE="/Users/tofu/Library/Caches/ClipInbox-ASO-Panorama-v2"

BG="#F3EFE7"
CARD="#FAF8F2"
INK="#171714"
MUTED="#5F6368"
LINE="#D8D1C4"
YELLOW="#FFD900"
FONT_BOLD="$ROOT/ios/ClipInbox/Fonts/Pretendard-Bold.otf"
FONT_REGULAR="$ROOT/ios/ClipInbox/Fonts/Pretendard-Regular.otf"

mkdir -p "$UPLOAD" "$CACHE"

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing source asset: $1" >&2
    exit 1
  fi
}

require_file "$SOURCE/triptych-background-imagegen.png"
require_file "$SOURCE/real-ui/01-link-share-sheet-imagegen-edit.png"
require_file "$SOURCE/real-ui/02-save-confirmation.png"
require_file "$SOURCE/real-ui/03-inbox.png"
require_file "$FONT_BOLD"
require_file "$FONT_REGULAR"

copy_for() {
  case "$1" in
    1)
      HEADLINE=$'공유 한 번으로\n링크 저장'
      BODY='Safari 공유 시트에서 클립 인박스로 바로'
      ;;
    2)
      HEADLINE=$'메모 없이도\n바로 보관'
      BODY='제목과 주소를 인식해 인박스에 저장'
      ;;
    3)
      HEADLINE=$'인박스에 모아두고\n나중에 정리'
      BODY='필요할 때 검색하고 폴더로 분류'
      ;;
  esac
}

make_text_layers() {
  local index="$1"
  copy_for "$index"

  magick -background none -fill "$INK" -font "$FONT_BOLD" -weight 700 \
    -pointsize 128 -interline-spacing 0 -size 1140x380 \
    caption:"$HEADLINE" "$CACHE/headline-$index.png"
  magick -background none -fill "$MUTED" -font "$FONT_REGULAR" -weight 400 \
    -pointsize 50 -interline-spacing 4 -size 1140x130 \
    caption:"$BODY" "$CACHE/body-$index.png"
}

prepare_screen() {
  local source="$1"
  local crop="$2"
  local slug="$3"
  local width=1040
  local height

  magick "$source" -crop "$crop" +repage -resize "${width}x" \
    "$CACHE/$slug-flat.png"
  height="$(identify -format '%h' "$CACHE/$slug-flat.png")"

  magick -size "${width}x${height}" xc:none \
    -fill white -draw "roundrectangle 0,0,$((width - 1)),$((height - 1)),44,44" \
    "$CACHE/$slug-mask.png"
  magick "$CACHE/$slug-flat.png" "$CACHE/$slug-mask.png" \
    -alpha off -compose CopyOpacity -composite "$CACHE/$slug.png"
  magick -size "${width}x${height}" xc:none \
    -fill "$CARD" -stroke "$LINE" -strokewidth 4 \
    -draw "roundrectangle 2,2,$((width - 3)),$((height - 3)),44,44" \
    "$CACHE/$slug-border.png"
}

compose_master() {
  local master="$CACHE/triptych-master.png"
  local next="$CACHE/triptych-next.png"

  magick "$SOURCE/triptych-background-imagegen.png" \
    -resize '3960x1320^' -gravity center -extent 3960x1320 \
    "$CACHE/background.png"
  magick -size 3960x2868 "xc:$BG" \
    "$CACHE/background.png" -geometry +0+1548 -composite \
    -alpha off -colorspace sRGB "$master"

  for index in 1 2 3; do
    local panel_x=$(( (index - 1) * 1320 ))
    local text_x=$(( panel_x + 86 ))
    local bar_x=$(( panel_x + 50 ))
    make_text_layers "$index"
    magick "$master" \
      -fill "$YELLOW" -draw "roundrectangle $bar_x,142 $((bar_x + 22)),336 11,11" \
      "$CACHE/headline-$index.png" -geometry +$text_x+150 -composite \
      "$CACHE/body-$index.png" -geometry +$text_x+620 -composite \
      -alpha off -colorspace sRGB "$next"
    mv "$next" "$master"
  done

  prepare_screen "$SOURCE/real-ui/01-link-share-sheet-imagegen-edit.png" '853x1694+0+150' share
  prepare_screen "$SOURCE/real-ui/02-save-confirmation.png" '1206x2400+0+145' saved
  prepare_screen "$SOURCE/real-ui/03-inbox.png" '1206x2400+0+145' inbox

  magick "$master" \
    "$CACHE/share-border.png" -geometry +140+760 -composite \
    "$CACHE/share.png" -geometry +140+760 -composite \
    "$CACHE/saved-border.png" -geometry +1460+760 -composite \
    "$CACHE/saved.png" -geometry +1460+760 -composite \
    "$CACHE/inbox-border.png" -geometry +2780+760 -composite \
    "$CACHE/inbox.png" -geometry +2780+760 -composite \
    -alpha off -colorspace sRGB "$OUTPUT/triptych-ko-KR.png"

  magick "$OUTPUT/triptych-ko-KR.png" -crop 1320x2868+0+0 +repage \
    "$UPLOAD/01-share-save.png"
  magick "$OUTPUT/triptych-ko-KR.png" -crop 1320x2868+1320+0 +repage \
    "$UPLOAD/02-instant-save.png"
  magick "$OUTPUT/triptych-ko-KR.png" -crop 1320x2868+2640+0 +repage \
    "$UPLOAD/03-inbox-organize.png"

  magick montage \
    "$UPLOAD/01-share-save.png" \
    "$UPLOAD/02-instant-save.png" \
    "$UPLOAD/03-inbox-organize.png" \
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
  "$UPLOAD/01-share-save.png" \
  "$UPLOAD/02-instant-save.png" \
  "$UPLOAD/03-inbox-organize.png" \
  +append \
  "$reconstructed"

pixel_diff="$(compare -metric AE "$OUTPUT/triptych-ko-KR.png" "$reconstructed" null: 2>&1 || true)"
pixel_diff="${pixel_diff%% *}"
if [[ "$pixel_diff" != "0" ]]; then
  echo "Triptych reconstruction differs from the master" >&2
  exit 1
fi

echo "Generated the three-panel Korean panorama under $UPLOAD"
