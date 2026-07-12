#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/docs/app-store/generated/aso-reference-refresh-v1"
UPLOAD="$OUTPUT/upload/ko-KR"
CACHE="/Users/tofu/Library/Caches/ClipInbox-ASO-Reference-Refresh"
RAW="$ROOT/docs/app-store/generated/aso-ko-v1/raw/ko-KR"

BG="#F3EFE7"
CARD="#FAF8F2"
INK="#171714"
MUTED="#5F6368"
LINE="#D8D1C4"
YELLOW="#FFD900"

FONT_BOLD="$ROOT/ios/ClipInbox/Fonts/Pretendard-Bold.otf"
FONT_SEMIBOLD="$ROOT/ios/ClipInbox/Fonts/Pretendard-SemiBold.otf"
FONT_REGULAR="$ROOT/ios/ClipInbox/Fonts/Pretendard-Regular.otf"
ICON="$ROOT/ios/ClipInbox/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
SHARE_CAPTURE="$ROOT/docs/app-store/generated/icon-reference-refresh/share-sheet-current.png"

mkdir -p "$UPLOAD" "$CACHE"

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing source asset: $1" >&2
    exit 1
  fi
}

for source in \
  "$RAW/04-inbox.png" \
  "$RAW/05-search.png" \
  "$RAW/06-folders.png" \
  "$FONT_BOLD" \
  "$FONT_SEMIBOLD" \
  "$FONT_REGULAR" \
  "$ICON" \
  "$SHARE_CAPTURE"; do
  require_file "$source"
done

copy_for() {
  case "$1" in
    1)
      HEADLINE=$'링크, 보자마자\n바로 저장'
      BODY='공유 시트에서 한 번에 클립 인박스로'
      FEATURES=('한 번에 저장' '원본 확인' '나중에 정리')
      ;;
    2)
      HEADLINE=$'저장만 하고,\n정리는 나중에'
      BODY='폴더와 태그로 가볍게 분류'
      FEATURES=('폴더 정리' '태그 분류' '로컬 보관')
      ;;
    3)
      HEADLINE=$'필요할 때,\n바로 다시 찾기'
      BODY='제목, URL, 태그, 메모까지 빠르게 검색'
      FEATURES=('제목 검색' '메모 검색' '계정 없음')
      ;;
  esac
}

make_text_layers() {
  local index="$1"
  copy_for "$index"

  magick -background none -fill "$INK" -font "$FONT_BOLD" -weight 700 \
    -pointsize 132 -interline-spacing 2 -gravity center -size 1120x430 \
    caption:"$HEADLINE" "$CACHE/headline-$index.png"
  magick -background none -fill "$MUTED" -font "$FONT_REGULAR" -weight 400 \
    -pointsize 50 -gravity center -size 1120x130 \
    caption:"$BODY" "$CACHE/body-$index.png"
}

make_brand() {
  magick "$ICON" -resize 112x112 \
    "$CACHE/brand-icon-flat.png"
  magick -size 112x112 xc:none \
    -fill white -draw 'roundrectangle 0,0 111,111 22,22' \
    "$CACHE/brand-icon-mask.png"
  magick "$CACHE/brand-icon-flat.png" "$CACHE/brand-icon-mask.png" \
    -alpha off -compose CopyOpacity -composite "$CACHE/brand-icon.png"
  magick -background none -fill "$INK" -font "$FONT_BOLD" -weight 700 \
    -pointsize 58 -gravity center -size 360x112 \
    caption:'Clip Inbox' "$CACHE/brand-name.png"
  magick "$CACHE/brand-icon.png" "$CACHE/brand-name.png" \
    +append "$CACHE/brand.png"
}

prepare_screen() {
  local source="$1"
  local slug="$2"

  # Keep only current app UI. Remove simulator status chrome and the home edge.
  magick "$source" -crop 1206x2400+0+145 +repage -resize 900x \
    "$CACHE/$slug-flat.png"
  local height
  height="$(identify -format '%h' "$CACHE/$slug-flat.png")"

  magick -size "900x${height}" xc:none \
    -fill white -draw "roundrectangle 0,0,899,$((height - 1)),42,42" \
    "$CACHE/$slug-mask.png"
  magick "$CACHE/$slug-flat.png" "$CACHE/$slug-mask.png" \
    -alpha off -compose CopyOpacity -composite "$CACHE/$slug.png"
}

prepare_share_inbox_pair() {
  magick "$SHARE_CAPTURE" -crop 1206x1450+0+1172 +repage -resize 660x \
    "$CACHE/share-pair-flat.png"
  local share_height
  share_height="$(identify -format '%h' "$CACHE/share-pair-flat.png")"
  magick -size "660x${share_height}" xc:none \
    -fill white -draw "roundrectangle 0,0,659,$((share_height - 1)),34,34" \
    "$CACHE/share-pair-mask.png"
  magick "$CACHE/share-pair-flat.png" "$CACHE/share-pair-mask.png" \
    -alpha off -compose CopyOpacity -composite "$CACHE/share-pair.png"

  magick "$RAW/04-inbox.png" -crop 1206x2400+0+145 +repage -resize 760x \
    "$CACHE/inbox-pair-flat.png"
  local inbox_height
  inbox_height="$(identify -format '%h' "$CACHE/inbox-pair-flat.png")"
  magick -size "760x${inbox_height}" xc:none \
    -fill white -draw "roundrectangle 0,0,759,$((inbox_height - 1)),38,38" \
    "$CACHE/inbox-pair-mask.png"
  magick "$CACHE/inbox-pair-flat.png" "$CACHE/inbox-pair-mask.png" \
    -alpha off -compose CopyOpacity -composite "$CACHE/inbox-pair.png"
}

make_feature_bar() {
  local index="$1"
  copy_for "$index"

  magick -size 1160x170 xc:none \
    -fill "$CARD" -stroke "$LINE" -strokewidth 2 \
    -draw 'roundrectangle 1,1 1158,168 84,84' \
    -stroke "$LINE" -strokewidth 2 \
    -draw 'line 386,40 386,130 line 773,40 773,130' \
    "$CACHE/feature-base-$index.png"

  local x
  for x in 0 1 2; do
    magick -background none -fill "$INK" -font "$FONT_SEMIBOLD" -weight 600 \
      -pointsize 36 -gravity center -size 360x120 \
      caption:"${FEATURES[$x]}" "$CACHE/feature-$index-$x.png"
  done

  magick "$CACHE/feature-base-$index.png" \
    "$CACHE/feature-$index-0.png" -geometry +13+25 -composite \
    "$CACHE/feature-$index-1.png" -geometry +400+25 -composite \
    "$CACHE/feature-$index-2.png" -geometry +787+25 -composite \
    "$CACHE/feature-bar-$index.png"
}

compose_panel() {
  local index="$1"
  local source="$2"
  local slug="$3"
  local output="$UPLOAD/0${index}-${slug}.png"

  make_text_layers "$index"
  if [[ "$index" == "1" ]]; then
    prepare_share_inbox_pair
  else
    prepare_screen "$source" "$slug"
  fi
  make_feature_bar "$index"

  if [[ "$index" == "1" ]]; then
    magick -size 1320x2868 "xc:$BG" \
      "$CACHE/brand.png" -gravity north -geometry +0+118 -composite \
      "$CACHE/headline-$index.png" -gravity north -geometry +0+286 -composite \
      -fill "$YELLOW" -stroke none -draw 'roundrectangle 430,716 890,734 9,9' \
      "$CACHE/body-$index.png" -gravity north -geometry +0+738 -composite \
      "$CACHE/share-pair.png" -geometry +54+972 -composite \
      "$CACHE/inbox-pair.png" -geometry +506+1080 -composite \
      "$CACHE/feature-bar-$index.png" -geometry +80+2630 -composite \
      -alpha off -colorspace sRGB "$output"
  else
    magick -size 1320x2868 "xc:$BG" \
      "$CACHE/brand.png" -gravity north -geometry +0+118 -composite \
      "$CACHE/headline-$index.png" -gravity north -geometry +0+286 -composite \
      -fill "$YELLOW" -stroke none -draw 'roundrectangle 430,716 890,734 9,9' \
      "$CACHE/body-$index.png" -gravity north -geometry +0+738 -composite \
      "$CACHE/$slug.png" -geometry +210+900 -composite \
      "$CACHE/feature-bar-$index.png" -geometry +80+2630 -composite \
      -alpha off -colorspace sRGB "$output"
  fi
}

make_brand
compose_panel 1 "$RAW/04-inbox.png" save-now
compose_panel 2 "$RAW/06-folders.png" organize-later
compose_panel 3 "$RAW/05-search.png" find-fast

magick montage \
  "$UPLOAD/01-save-now.png" \
  "$UPLOAD/02-organize-later.png" \
  "$UPLOAD/03-find-fast.png" \
  -thumbnail 330x717 -tile 3x1 -geometry +22+22 \
  -font "$FONT_REGULAR" -label '' \
  -background "$BG" "$OUTPUT/contact-sheet-ko-KR.png"

for file in "$UPLOAD"/*.png; do
  dimensions="$(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixelWidth|pixelHeight/{print $2}' | paste -sdx -)"
  alpha="$(sips -g hasAlpha "$file" | awk '/hasAlpha/{print $2}')"
  if [[ "$dimensions" != "1320x2868" || "$alpha" != "no" ]]; then
    echo "Invalid upload asset: $file ($dimensions, alpha=$alpha)" >&2
    exit 1
  fi
done

echo "Generated three reference-driven Korean ASO screenshots under $UPLOAD"
