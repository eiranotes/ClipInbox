#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_ID="${DEVICE_ID:-64C7804C-355B-4444-90EE-C8ED0D9355CF}"
BUNDLE_ID="app.eiradev.ClipInbox"
APP_PATH="${APP_PATH:-/Users/tofu/Library/Developer/Xcode/DerivedData/ClipInbox-Codex-ASO/Build/Products/Debug-iphonesimulator/ClipInbox.app}"
OUTPUT="$ROOT/docs/app-store/generated/aso-ko-v1"
RAW="$OUTPUT/raw"
UPLOAD="$OUTPUT/upload"
LOCAL_CACHE="/Users/tofu/Library/Caches/ClipInbox-ASO"

BG="#F3EFE7"
BOARD="#EEE8DD"
CARD="#FAF8F2"
INK="#171714"
MUTED="#5F6368"
LINE="#D8D1C4"
YELLOW="#FFD900"

mkdir -p "$RAW" "$UPLOAD" "$LOCAL_CACHE"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing simulator app at $APP_PATH" >&2
  exit 1
fi

xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl status_bar "$DEVICE_ID" override \
  --time 9:41 --batteryLevel 100 --batteryState charged --wifiBars 3 --cellularBars 4
xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" clip-inbox-onboarding-completed-v1 -bool true

capture_screen() {
  local locale="$1"
  local tab="$2"
  local filename="$3"
  local query="$4"
  local local_png="$LOCAL_CACHE/capture-${locale}-${filename}"

  if [[ -n "$query" ]]; then
    SIMCTL_CHILD_CLIP_INBOX_ASO_CAPTURE=1 \
    SIMCTL_CHILD_CLIP_INBOX_ASO_TAB="$tab" \
    SIMCTL_CHILD_CLIP_INBOX_ASO_SEARCH_QUERY="$query" \
      xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" >/dev/null
  else
    SIMCTL_CHILD_CLIP_INBOX_ASO_CAPTURE=1 \
    SIMCTL_CHILD_CLIP_INBOX_ASO_TAB="$tab" \
      xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" >/dev/null
  fi

  # A Debug simulator launch occasionally returns the blank UILaunchScreen even
  # after the process is running. Reject near-white frames and wait for real UI.
  local attempt
  local mean="1"
  for attempt in 1 2 3 4 5 6; do
    sleep 2
    xcrun simctl io "$DEVICE_ID" screenshot "$local_png" >/dev/null
    mean="$(magick "$local_png" -format '%[fx:mean]' info:)"
    if awk "BEGIN { exit !($mean < 0.97) }"; then
      break
    fi
  done
  if ! awk "BEGIN { exit !($mean < 0.97) }"; then
    echo "Blank simulator capture after $attempt attempts: $locale/$filename" >&2
    exit 1
  fi
  cp "$local_png" "$RAW/$locale/$filename"
}

capture_locale() {
  local locale="$1"
  local query="$2"
  local data_container
  data_container="$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data)"

  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  mkdir -p "$data_container/Library/Application Support" "$RAW/$locale" "$UPLOAD/$locale"
  cp "$ROOT/docs/app-store/aso-samples/$locale.json" \
    "$data_container/Library/Application Support/clip-inbox-data.json"

  # Warm the just-installed Debug build before the first saved frame. The
  # launch screen is intentionally blank and can otherwise leak into 04-inbox.
  SIMCTL_CHILD_CLIP_INBOX_ASO_CAPTURE=1 \
  SIMCTL_CHILD_CLIP_INBOX_ASO_TAB=inbox \
    xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" >/dev/null
  sleep 3
  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true

  capture_screen "$locale" inbox "04-inbox.png" ""
  capture_screen "$locale" search "05-search.png" "$query"
  capture_screen "$locale" folders "06-folders.png" ""
  capture_screen "$locale" settings "07-settings.png" ""
}

font_for_locale() {
  case "$1" in
    ko-KR) printf '%s' "$ROOT/ios/ClipInbox/Fonts/Pretendard-Bold.otf" ;;
    ja-JP) printf '%s' '/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc' ;;
    *) printf '%s' '/System/Library/Fonts/Helvetica.ttc' ;;
  esac
}

body_font_for_locale() {
  case "$1" in
    ko-KR) printf '%s' "$ROOT/ios/ClipInbox/Fonts/Pretendard-Regular.otf" ;;
    ja-JP) printf '%s' '/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc' ;;
    *) printf '%s' '/System/Library/Fonts/Helvetica.ttc' ;;
  esac
}

headline_size_for_locale() {
  case "$1" in
    ja-JP) printf '%s' '112' ;;
    *) printf '%s' '128' ;;
  esac
}

copy_for() {
  local locale="$1"
  local index="$2"
  case "$locale:$index" in
    ko-KR:1) HEADLINE=$'놓치기 전에\n바로 저장'; BODY='링크, 사진, 메모를 공유 시트에서 한 번에' ;;
    ko-KR:2) HEADLINE=$'한 곳에 모이면\n정리가 쉬워져요'; BODY='폴더와 태그로 가볍게 분류' ;;
    ko-KR:3) HEADLINE=$'필요할 때\n바로 찾으세요'; BODY='검색으로 저장한 순간을 다시 꺼내기' ;;
    ko-KR:4) HEADLINE=$'좋아하는 것을\n한 곳에'; BODY='링크, 이미지, 메모를 한눈에' ;;
    ko-KR:5) HEADLINE=$'기억 대신\n검색하세요'; BODY='제목, 메모, 태그까지 한 번에' ;;
    ko-KR:6) HEADLINE=$'내 방식대로\n가볍게 정리'; BODY='폴더별로 모으고 다시 찾기' ;;
    ko-KR:7) HEADLINE=$'계정 없이\n내 기기 안에서'; BODY='잠금, 백업, 저장 방식을 직접 선택' ;;
    en-US:1) HEADLINE=$'Save it before\nit disappears'; BODY='Links, photos, and notes from any share sheet' ;;
    en-US:2) HEADLINE=$'One inbox.\nLess clutter.'; BODY='Sort gently with folders and tags' ;;
    en-US:3) HEADLINE=$'Find it the moment\nyou need it'; BODY='Search across everything you saved' ;;
    en-US:4) HEADLINE=$'Everything you like,\nin one place'; BODY='Links, images, and notes at a glance' ;;
    en-US:5) HEADLINE=$'Search instead\nof remembering'; BODY='Titles, notes, and tags in one search' ;;
    en-US:6) HEADLINE=$'Organize it\nyour way'; BODY='Keep clips together with simple folders' ;;
    en-US:7) HEADLINE=$'No account.\nYour device.'; BODY='Choose your lock, backup, and save flow' ;;
    ja-JP:1) HEADLINE=$'見失う前に、\nすぐ保存'; BODY='リンクも写真もメモも共有シートから' ;;
    ja-JP:2) HEADLINE=$'ひとつに集めて、\nすっきり整理'; BODY='フォルダとタグで無理なく分類' ;;
    ja-JP:3) HEADLINE=$'必要なときに、\nすぐ見つかる'; BODY='保存したものを検索ですぐに' ;;
    ja-JP:4) HEADLINE=$'好きなものを、\nひとつの場所へ'; BODY='リンクも画像もメモもひと目で' ;;
    ja-JP:5) HEADLINE=$'覚える代わりに、\n検索する'; BODY='タイトル、メモ、タグをまとめて検索' ;;
    ja-JP:6) HEADLINE=$'自分らしく、\n気軽に整理'; BODY='シンプルなフォルダでまとめて保存' ;;
    ja-JP:7) HEADLINE=$'アカウント不要。\nデータは端末に。'; BODY='ロック、バックアップ、保存方法を選択' ;;
  esac
}

make_text_layers() {
  local locale="$1"
  local index="$2"
  local font
  local body_font
  local headline_size
  font="$(font_for_locale "$locale")"
  body_font="$(body_font_for_locale "$locale")"
  headline_size="$(headline_size_for_locale "$locale")"
  copy_for "$locale" "$index"

  magick -background none -fill "$INK" -font "$font" -weight 700 \
    -pointsize "$headline_size" -interline-spacing 2 -size 1160x500 \
    caption:"$HEADLINE" "$LOCAL_CACHE/headline.png"
  magick -background none -fill "$MUTED" -font "$body_font" -weight 400 \
    -pointsize 50 -interline-spacing 4 -size 1160x180 \
    caption:"$BODY" "$LOCAL_CACHE/body.png"
}

compose_triptych() {
  local locale="$1"
  local triptych="$LOCAL_CACHE/triptych-$locale.png"
  local next="$LOCAL_CACHE/triptych-next.png"
  local art="$OUTPUT/source/triptych-master-imagegen.png"

  magick "$art" -crop 1536x700+0+250 +repage -resize '3960x1800^' \
    -gravity center -extent 3960x1800 "$LOCAL_CACHE/triptych-art.png"
  magick -size 3960x2868 "xc:$BG" \
    "$LOCAL_CACHE/triptych-art.png" -geometry +0+1010 -composite \
    -alpha off -colorspace sRGB "$triptych"

  for index in 1 2 3; do
    local x=$(( (index - 1) * 1320 + 86 ))
    local bar_x=$(( (index - 1) * 1320 + 50 ))
    make_text_layers "$locale" "$index"
    magick "$triptych" \
      -fill "$YELLOW" -draw "roundrectangle $bar_x,142 $((bar_x + 22)),336 11,11" \
      "$LOCAL_CACHE/headline.png" -geometry +$x+150 -composite \
      "$LOCAL_CACHE/body.png" -geometry +$x+650 -composite \
      -alpha off -colorspace sRGB "$next"
    mv "$next" "$triptych"
  done

  magick "$triptych" -crop 1320x2868+0+0 +repage "$UPLOAD/$locale/01-capture.png"
  magick "$triptych" -crop 1320x2868+1320+0 +repage "$UPLOAD/$locale/02-collect.png"
  magick "$triptych" -crop 1320x2868+2640+0 +repage "$UPLOAD/$locale/03-find.png"
  cp "$triptych" "$OUTPUT/triptych-$locale.png"
}

compose_feature() {
  local locale="$1"
  local index="$2"
  local source="$3"
  local slug="$4"
  local illustration="$5"
  local output="$UPLOAD/$locale/0${index}-${slug}.png"
  make_text_layers "$locale" "$index"

  # Remove simulator status bar, Dynamic Island, and the bottom home indicator.
  # The remaining real app canvas is placed upright with no device frame.
  magick "$source" -crop 1206x2400+0+145 +repage -resize 840x \
    "$LOCAL_CACHE/screen.png"
  magick "$illustration" -resize '650x488^' -gravity center -extent 650x488 \
    "$LOCAL_CACHE/illustration.png"
  magick -size 1320x2868 "xc:$BG" \
    -fill "$YELLOW" -draw 'roundrectangle 50,142 72,336 11,11' \
    "$LOCAL_CACHE/headline.png" -geometry +86+150 -composite \
    "$LOCAL_CACHE/body.png" -geometry +86+650 -composite \
    -fill "$CARD" -draw 'roundrectangle 48,790 730,1310 26,26' \
    "$LOCAL_CACHE/illustration.png" -geometry +64+806 -composite \
    "$LOCAL_CACHE/screen.png" -geometry +430+1010 -composite \
    -fill "$YELLOW" -draw 'roundrectangle 86,2660 386,2680 10,10' \
    -alpha off -colorspace sRGB "$output"
}

compose_locale() {
  local locale="$1"
  compose_triptych "$locale"
  compose_feature "$locale" 4 "$RAW/$locale/04-inbox.png" inbox \
    "$ROOT/ios/ClipInbox/Assets.xcassets/onboarding-saved.imageset/onboarding-saved.png"
  compose_feature "$locale" 5 "$RAW/$locale/05-search.png" search \
    "$ROOT/ios/ClipInbox/Assets.xcassets/onboarding-destination.imageset/onboarding-destination.png"
  compose_feature "$locale" 6 "$RAW/$locale/06-folders.png" folders \
    "$ROOT/ios/ClipInbox/Assets.xcassets/onboarding-share.imageset/onboarding-share.png"
  compose_feature "$locale" 7 "$RAW/$locale/07-settings.png" settings \
    "$ROOT/ios/ClipInbox/Assets.xcassets/onboarding-saved.imageset/onboarding-saved.png"

  magick montage "$UPLOAD/$locale"/*.png -thumbnail 330x717 -tile 4x2 -geometry +18+18 \
    -font '/System/Library/Fonts/Helvetica.ttc' -label '' \
    -background "$BG" "$OUTPUT/contact-sheet-$locale.png"
}

if [[ "${SKIP_CAPTURE:-0}" != "1" ]]; then
  capture_locale ko-KR '디자인'
fi
compose_locale ko-KR

xcrun simctl status_bar "$DEVICE_ID" clear

for file in "$UPLOAD"/*/*.png; do
  dimensions="$(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixelWidth|pixelHeight/{print $2}' | paste -sdx -)"
  alpha="$(sips -g hasAlpha "$file" | awk '/hasAlpha/{print $2}')"
  if [[ "$dimensions" != "1320x2868" || "$alpha" != "no" ]]; then
    echo "Invalid upload asset: $file ($dimensions, alpha=$alpha)" >&2
    exit 1
  fi
done

echo "Generated 7 upload-ready Korean screenshots under $UPLOAD/ko-KR"
