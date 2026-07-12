#!/usr/bin/env bash
# Real-UI feature frames 04-07 for every App Store locale.
#
# The first three upload frames per locale are the supplied concept drafts in
# docs/app-store/ASO (normalized by scripts/finalize_aso.sh). This script adds
# four real-simulator proof frames per locale — save, note, link preview/open,
# folders — with the phone status bar and home indicator cropped away and the
# same warm-ivory, oversized-headline, yellow-underline direction.
#
# Usage:
#   APP_PATH=/path/to/Debug-iphonesimulator/ClipInbox.app \
#     bash scripts/generate_aso_feature_frames.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_ID="${DEVICE_ID:-64C7804C-355B-4444-90EE-C8ED0D9355CF}"
BUNDLE_ID="app.clipinbox.ClipInbox"
APP_PATH="${APP_PATH:?Set APP_PATH to a Debug-iphonesimulator ClipInbox.app}"
OUTPUT="$ROOT/docs/app-store/generated/final-aso"
RAW="$ROOT/docs/app-store/generated/final-aso-raw"
LOCAL_CACHE="${LOCAL_CACHE:-$HOME/Library/Caches/ClipInbox-ASO-Features}"

# 시안(docs/app-store/ASO)에서 추출한 배경/잉크/포인트 색.
BG="srgb(249,240,230)"
INK="#1B1A17"
SUB="#3D3B36"
LINE="#D8D1C4"
YELLOW="#FFD900"

mkdir -p "$RAW" "$LOCAL_CACHE"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing simulator app at $APP_PATH" >&2
  exit 1
fi

xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null
xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" clip-inbox-onboarding-completed-v1 -bool true

# ---------------------------------------------------------------------------
# Seeding: enrich the locale sample with a fuller trip note and one real URL
# so the link-detail frame shows live summary metadata.
# ---------------------------------------------------------------------------
seed_locale() {
  local locale="$1"
  local data_container
  data_container="$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data)"
  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  mkdir -p "$data_container/Library/Application Support"
  python3 - "$ROOT/docs/app-store/aso-samples/$locale.json" \
    "$data_container/Library/Application Support/clip-inbox-data.json" \
    "$locale" <<'PY'
import json, sys

source, target, locale = sys.argv[1:4]
data = json.load(open(source))

memo_by_locale = {
    "ko-KR": "여권, 충전기, 우산 챙기기.\n호텔 체크인 15시, 짐은 먼저 맡기기.\n금요일 저녁에 한 번 더 확인.",
    "en-US": "Passport, charger, umbrella.\nHotel check-in at 3 pm - drop the bags first.\nDouble-check everything on Friday evening.",
    "ja-JP": "パスポート、充電器、傘を準備。\nチェックインは15時、荷物は先に預ける。\n金曜の夜にもう一度確認。",
}
wiki_by_locale = {
    "ko-KR": "https://ko.wikipedia.org/wiki/%EB%B6%81%EC%B4%8C%ED%95%9C%EC%98%A5%EB%A7%88%EC%9D%84",
    "en-US": "https://en.wikipedia.org/wiki/Bukchon_Hanok_Village",
    "ja-JP": "https://ja.wikipedia.org/wiki/%E5%8C%97%E6%9D%91%E9%9F%93%E5%B1%8B%E6%9D%91",
}

for clip in data["clips"]:
    suffix = clip["id"] % 100
    if suffix == 4 and clip["type"] == "memo":
        clip["memo"] = memo_by_locale[locale]
    if suffix == 2 and clip["type"] == "link":
        clip["url"] = wiki_by_locale[locale]
        clip["source"] = "wikipedia.org"

json.dump(data, open(target, "w"), ensure_ascii=False)
PY
}

# ---------------------------------------------------------------------------
# Capture
# ---------------------------------------------------------------------------
launch_and_capture() {
  local out="$1"
  local settle="$2"
  shift 2
  # simctl 데몬은 외부 볼륨에 쓸 수 없으므로 로컬 캐시에 캡처한 뒤 복사한다.
  local local_png="$LOCAL_CACHE/capture.png"
  env "$@" xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" >/dev/null
  sleep "$settle"
  local attempt mean="1"
  for attempt in 1 2 3 4 5; do
    xcrun simctl io "$DEVICE_ID" screenshot "$local_png" >/dev/null
    mean="$(magick "$local_png" -format '%[fx:mean]' info:)"
    if awk "BEGIN { exit !($mean < 0.97) }"; then
      cp "$local_png" "$out"
      return 0
    fi
    sleep 2
  done
  echo "Blank simulator capture: $out" >&2
  exit 1
}

capture_locale() {
  local locale="$1"
  local memo_id="$2"
  local link_id="$3"
  mkdir -p "$RAW/$locale"
  seed_locale "$locale"

  # Debug 빌드 첫 실행의 빈 런치 스크린을 예열로 소진한다.
  env SIMCTL_CHILD_CLIP_INBOX_ASO_CAPTURE=1 SIMCTL_CHILD_CLIP_INBOX_ASO_TAB=inbox \
    xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" >/dev/null
  sleep 3

  # 링크 상세를 먼저 열어 위키백과 메타데이터 분석을 끝내 두면
  # 인박스 캡처에서도 요약 줄이 채워진 상태가 된다.
  launch_and_capture "$RAW/$locale/link-detail.png" 12 \
    SIMCTL_CHILD_CLIP_INBOX_ASO_CAPTURE=1 \
    SIMCTL_CHILD_CLIP_INBOX_ASO_DETAIL_CLIP_ID="$link_id"
  launch_and_capture "$RAW/$locale/inbox.png" 5 \
    SIMCTL_CHILD_CLIP_INBOX_ASO_CAPTURE=1 \
    SIMCTL_CHILD_CLIP_INBOX_ASO_TAB=inbox
  launch_and_capture "$RAW/$locale/memo-detail.png" 5 \
    SIMCTL_CHILD_CLIP_INBOX_ASO_CAPTURE=1 \
    SIMCTL_CHILD_CLIP_INBOX_ASO_DETAIL_CLIP_ID="$memo_id"
  launch_and_capture "$RAW/$locale/folders.png" 5 \
    SIMCTL_CHILD_CLIP_INBOX_ASO_CAPTURE=1 \
    SIMCTL_CHILD_CLIP_INBOX_ASO_TAB=folders
}

# ---------------------------------------------------------------------------
# Composition
# ---------------------------------------------------------------------------
font_for_locale() {
  case "$1" in
    ja-JP) printf '%s' '/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc' ;;
    *) printf '%s' "$ROOT/ios/ClipInbox/Fonts/Pretendard-Bold.otf" ;;
  esac
}

body_font_for_locale() {
  case "$1" in
    ja-JP) printf '%s' '/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc' ;;
    *) printf '%s' "$ROOT/ios/ClipInbox/Fonts/Pretendard-Regular.otf" ;;
  esac
}

headline_size_for_locale() {
  case "$1" in
    ja-JP) printf '%s' '104' ;;
    *) printf '%s' '118' ;;
  esac
}

copy_for() {
  local locale="$1"
  local slug="$2"
  case "$locale:$slug" in
    ko-KR:save)    HEADLINE=$'공유 한 번이면\n저장 끝'; BODY='Safari와 사진에서 링크·이미지를 바로 인박스로' ;;
    ko-KR:note)    HEADLINE=$'짧은 메모도\n잊지 않게'; BODY='생각을 적고 폴더와 태그로 가볍게 정리' ;;
    ko-KR:preview) HEADLINE=$'요약 보고,\n바로 열기'; BODY='저장한 링크의 핵심을 먼저 확인하고 원본으로' ;;
    ko-KR:folders) HEADLINE=$'폴더와 태그로\n가볍게 정리'; BODY='모아 두면 필요할 때 다시 찾기 쉬워요' ;;
    en-US:save)    HEADLINE=$'One share.\nSaved.'; BODY='Send links and photos straight to your inbox' ;;
    en-US:note)    HEADLINE=$'Quick notes,\nkept for later'; BODY='Write it down, file it with folders and tags' ;;
    en-US:preview) HEADLINE=$'Preview first,\nopen instantly'; BODY='See the summary, then jump to the original page' ;;
    en-US:folders) HEADLINE=$'Tidy with folders\nand tags'; BODY='A light structure that keeps everything findable' ;;
    ja-JP:save)    HEADLINE=$'共有一回で、\n保存完了'; BODY='Safariや写真からそのまま受信トレイへ' ;;
    ja-JP:note)    HEADLINE=$'小さなメモも、\n忘れずに'; BODY='書き留めて、フォルダとタグで整理' ;;
    ja-JP:preview) HEADLINE=$'要約を見て、\nすぐ開く'; BODY='保存したリンクの要点を先にチェック' ;;
    ja-JP:folders) HEADLINE=$'フォルダとタグで、\n気軽に整理'; BODY='まとめておけば、あとで探しやすい' ;;
  esac
}

compose_frame() {
  local locale="$1"
  local index="$2"
  local slug="$3"
  local source="$4"
  local out="$OUTPUT/$locale/0${index}-${slug}.png"
  local font body_font headline_size
  font="$(font_for_locale "$locale")"
  body_font="$(body_font_for_locale "$locale")"
  headline_size="$(headline_size_for_locale "$locale")"
  copy_for "$locale" "$slug"

  # 상태바·다이내믹 아일랜드(상단 170px)와 홈 인디케이터(하단 72px)를 잘라 낸다.
  magick "$source" -crop 1206x2380+0+170 +repage "$LOCAL_CACHE/screen-raw.png"

  # 위쪽 모서리만 둥근 마스크를 씌운 뒤 폭 1092로 축소하고 은은한 그림자를 더한다.
  magick "$LOCAL_CACHE/screen-raw.png" \
    \( +clone -alpha extract \
       -draw 'fill black polygon 0,0 0,56 56,0 fill white circle 56,56 56,0' \
       \( +clone -flop \) -compose Multiply -composite \) \
    -alpha off -compose CopyOpacity -composite \
    -resize 1092x "$LOCAL_CACHE/screen-rounded.png"
  magick "$LOCAL_CACHE/screen-rounded.png" \
    \( +clone -background '#B9AE9C' -shadow 45x28+0+10 \) +swap \
    -background none -layers merge +repage "$LOCAL_CACHE/screen-shadow.png"

  magick -background none -fill "$INK" -font "$font" \
    -pointsize "$headline_size" -interline-spacing 6 -gravity center \
    -size 1180x420 caption:"$HEADLINE" "$LOCAL_CACHE/headline.png"
  magick -background none -fill "$SUB" -font "$body_font" \
    -pointsize 47 -gravity center -size 1180x140 \
    caption:"$BODY" "$LOCAL_CACHE/body.png"

  mkdir -p "$OUTPUT/$locale"
  magick -size 1320x2868 "xc:$BG" \
    "$LOCAL_CACHE/headline.png" -gravity north -geometry +0+170 -composite \
    -gravity none -fill "$YELLOW" -draw 'roundrectangle 450,640 870,660 10,10' \
    "$LOCAL_CACHE/body.png" -gravity north -geometry +0+716 -composite \
    -gravity none "$LOCAL_CACHE/screen-shadow.png" -geometry +86+940 -composite \
    -alpha off -colorspace sRGB -strip "$out"
}

compose_locale() {
  local locale="$1"
  compose_frame "$locale" 4 save "$RAW/$locale/inbox.png"
  compose_frame "$locale" 5 note "$RAW/$locale/memo-detail.png"
  compose_frame "$locale" 6 preview "$RAW/$locale/link-detail.png"
  compose_frame "$locale" 7 folders "$RAW/$locale/folders.png"

  magick montage "$OUTPUT/$locale"/*.png -thumbnail 264x574 -tile 7x1 -geometry +12+12 \
    -font '/System/Library/Fonts/Helvetica.ttc' -label '' \
    -background "$BG" "$OUTPUT/contact-sheet-$locale.png"
}

run_locale() {
  local locale="$1" memo_id="$2" link_id="$3"
  if [[ "${SKIP_CAPTURE:-0}" != "1" ]]; then
    capture_locale "$locale" "$memo_id" "$link_id"
  fi
  compose_locale "$locale"
}

run_locale ko-KR 104 102
run_locale en-US 204 202
run_locale ja-JP 304 302

for file in "$OUTPUT"/*/0[4-7]-*.png; do
  dimensions="$(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixelWidth|pixelHeight/{print $2}' | paste -sdx -)"
  alpha="$(sips -g hasAlpha "$file" | awk '/hasAlpha/{print $2}')"
  if [[ "$dimensions" != "1320x2868" || "$alpha" != "no" ]]; then
    echo "Invalid upload asset: $file ($dimensions, alpha=$alpha)" >&2
    exit 1
  fi
done

echo "Generated feature frames 04-07 for ko-KR, en-US, ja-JP under $OUTPUT"
