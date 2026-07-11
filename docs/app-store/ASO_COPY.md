# Clip Inbox App Store Metadata

Prepared for the first native iOS release. Character limits follow the current App Store Connect fields: name and subtitle 30 characters, promotional text 170 characters, keywords 100 bytes, and description 4,000 characters.

## Positioning

- Primary category: Productivity
- Secondary category: Utilities
- Core promise: save a link, image, screenshot, or text from the iOS share sheet, then find it later by folder, tag, or search.
- Differentiator: a local-first inbox with immediate capture, optional folder/note review, no account, no feed, and no recommendation scoring.

## Korean (ko-KR)

App name: `Clip Inbox`

Subtitle: `링크·이미지·메모 빠른 보관`

Promotional text:

`공유 시트에서 링크, 이미지, 메모를 바로 저장하세요. 필요할 때는 저장 전에 폴더와 메모를 한 번만 확인할 수 있습니다.`

Keywords:

`링크저장,북마크,클립,메모,자료정리,웹수집,스크린샷,폴더,레퍼런스`

Description:

Clip Inbox는 나중에 다시 보고 싶은 링크, 이미지, 스크린샷, 메모를 한곳에 모아두는 로컬 인박스입니다.

Safari, 사진 등에서 iOS 공유 시트를 열고 Clip Inbox를 선택하세요. 기본은 바로 저장이며, 원하면 저장 전에 폴더와 메모를 고르도록 바꿀 수 있습니다.

주요 기능

- 공유 시트에서 링크, 텍스트, 이미지 저장
- 바로 저장 또는 폴더·메모 확인 후 저장
- 폴더, 태그, 검색을 이용한 빠른 정리
- 미정리 클립을 하나씩 정리하는 분류 흐름
- JSON 백업 내보내기와 가져오기
- 선택 사항인 Face ID 앱 잠금
- 한국어, 영어, 일본어 지원

계정 가입이나 서버 동기 없이 데이터를 기기에 보관합니다. 앱에서 언제든 모든 로컬 데이터를 삭제할 수 있습니다.

What's New:

`Clip Inbox 첫 버전입니다. iOS 공유 시트 저장, 폴더·태그·검색, JSON 백업, 선택적 앱 잠금, 한국어·영어·일본어를 지원합니다.`

## English (en-US)

App name: `Clip Inbox`

Subtitle: `Save links, images and notes`

Promotional text:

`Save links, images, screenshots, and text from the iOS share sheet. Keep one-tap capture or review the folder and note before saving.`

Keywords:

`bookmark,link saver,clip,notes,organizer,read later,reference,inbox,web capture`

Description:

Clip Inbox is a local-first inbox for links, images, screenshots, and notes you want to find again.

Open the iOS share sheet in Safari, Photos, or another app and choose Clip Inbox. Save immediately by default, or switch to a short review step where you choose a folder and add a note before saving.

Key features

- Save links, text, and images from the iOS share sheet
- Choose instant save or folder-and-note review
- Organize with folders, tags, and search
- Process unsorted clips one at a time with Sort Later
- Export and import a JSON backup
- Protect the app with optional Face ID lock
- Use the app in Korean, English, or Japanese

Your clips stay on your device. Clip Inbox has no account requirement and no server sync. You can delete all local data from Settings at any time.

What's New:

`Welcome to the first version of Clip Inbox, with iOS share-sheet capture, folders, tags, search, JSON backup, optional App Lock, and Korean, English, and Japanese interfaces.`

## Japanese (ja-JP)

App name: `Clip Inbox`

Subtitle: `リンク・画像・メモをすぐ保存`

Promotional text:

`iOSの共有シートからリンク、画像、メモを保存。すぐに保存するか、フォルダとメモを確認してから保存できます。`

Keywords:

`リンク保存,ブックマーク,メモ,資料整理,あとで読む,画像保存,フォルダ`

Description:

Clip Inboxは、あとで見返したいリンク、画像、スクリーンショット、メモを1か所にまとめるローカル保存型の受信トレイです。

Safariや写真アプリでiOSの共有シートを開き、Clip Inboxを選びます。初期設定ではすぐに保存されます。必要な場合は、保存前にフォルダを選び、メモを追加する方式に変更できます。

主な機能

- iOS共有シートからリンク、テキスト、画像を保存
- すぐに保存、またはフォルダとメモを確認して保存
- フォルダ、タグ、検索で整理
- 未整理のクリップを1件ずつ処理
- JSONバックアップの書き出しと読み込み
- 任意のFace IDアプリロック
- 韓国語、英語、日本語に対応

アカウン登録やサーバー同期はありません。データは端末に保存され、設定からすべて削除できます。

What's New:

`Clip Inboxの初リリースです。iOS共有シートからの保存、フォルダ、タグ、検索、JSONバックアップ、任意のApp Lock、韓国語・英語・日本語に対応しました。`

## Screenshot Storyboard

Capture real app UI at the 6.9-inch portrait size accepted by App Store Connect. Use 1320 x 2868 or another currently accepted 6.9-inch size. Localize captions and in-app UI together.

1. `Save it before it gets lost` / Inbox with real mixed clip rows.
2. `One tap from the share sheet` / compact quick-save confirmation over Safari.
3. `Choose a folder when it matters` / review-before-save form with folder and note.
4. `Find it by folder, tag, or search` / Search with filter grid and results.
5. `Your clips stay on your device` / Settings showing App Lock off, quick save on, backup, and language.

Do not use generated fake app screens. Use the simulator captures produced by this repository, then add only caption and device-safe framing in the final marketing composition.

## App Review Notes

Clip Inbox does not require an account and has no server-backed login.

To test the Share Extension:

1. Open Safari and load any public web page.
2. Tap Share and select Clip Inbox.
3. With Settings > Share save behavior set to Save immediately, a compact saved message appears and returns to Safari.
4. Change that setting to Choose folder and note.
5. Share again, select a folder, optionally enter a note, then tap Save clip.
6. Return to Clip Inbox. The shared item appears in the selected folder.

App Lock is off by default. If enabled, it uses the system device-owner authentication prompt. The app stores clips locally and exposes JSON backup and delete-all controls in Settings.

## Required App Store Connect Values Not Invented Here

- Privacy Policy URL: `<HTTPS_PRIVACY_POLICY_URL_REQUIRED>`
- Support URL: `<HTTPS_SUPPORT_URL_REQUIRED>`
- Marketing URL: optional, `<HTTPS_MARKETING_URL>`
- Support email in the app: replace `support@clipinbox.local` with an owned, monitored address before submission.
- App ownership, seller name, copyright, price, availability, age-rating questionnaire, and export-compliance answers must be completed by the account holder.
