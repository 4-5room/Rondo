# Rondo (PomoTaskerMac)

> ポモドーロタイマー × タスク管理 × ロギング を統合した macOS ネイティブアプリ

YouTube チャンネル [4.5room](https://www.youtube.com/@4.5room) で AI と協働しながら個人開発した Mac 用生産性アプリです。SwiftUI + SwiftData で実装しています。

## 主な機能

- **Today**: 4分類 (緊急 / 重要 / 特殊 / 通常) のタスク管理
- **ポモドーロタイマー**: 作業/休憩自動切替、フリーカウントアップモード、タスクへの累計時間記録
- **メニューバー常駐**: 残り時間表示、一時停止/再開/中断をメニューバーから操作
- **Timeline**: 24時間軸の2列バーチカルログ、ポモ完了時自動記録 + 手動追加/編集
- **Stats**: D/W/M 集計、分類別ドーナツチャート、時間帯別バーチャート、月カレンダー
- **Goals**: 月次目標、コンテキストメニューで日次タスクへ流し込み
- **OCR**: 画像/PDF ファイルからタスク一括取り込み (ドラッグ&ドロップ対応、Vision multi-pass)
- **テーマ**: 7種のカラーパレット (4.5room オリジナルカラー含む) + ライト/ダーク
- **バックアップ**: JSON でのエクスポート/インポート

## 必要環境

- macOS 14 (Sonoma) 以上
- (開発時) Xcode 15.4 以上 + Swift 5.9

## インストール (一般ユーザー向け)

### バイナリ配布版

[Releases ページ](https://github.com/4-5room/Rondo/releases) から最新の `.dmg` をダウンロードしてください。

#### ⚠️ 初回起動時の注意

このアプリは **Apple 公証 (notarization) を行っていない** ため、初回起動時に「開発元が未確認」の警告が表示されます。以下の手順で開いてください:

1. ダウンロードした `.dmg` を開き、`PomoTaskerMac.app` を Applications フォルダにドラッグ
2. Finder で `PomoTaskerMac.app` を **右クリック → 「開く」**
3. 警告ダイアログで「開く」をクリック
4. (macOS Sequoia 以降の場合) System Settings → プライバシーとセキュリティ → 「このまま開く」

2回目以降は通常通りダブルクリックで起動できます。

> **なぜ警告が出るの?**: Apple Developer Program (年 $99) に未加入のため、Apple による署名・公証ができません。アプリ自体は完全にオンデバイスで動作し、データはあなたの Mac にローカル保存されるため、外部にデータが送信されることはありません。心配な方はソースコードを本リポジトリで全公開しているので、ご自身でビルドしてご利用ください。

## ビルド (開発者向け)

```bash
git clone https://github.com/4-5room/Rondo.git
cd Rondo
open PomoTaskerMac.xcodeproj
```

Xcode で `⌘R` を押して実行。

CLI からのビルド:

```bash
xcodebuild -project PomoTaskerMac.xcodeproj \
  -scheme PomoTaskerMac \
  -configuration Release \
  -destination 'platform=macOS' build
```

## .dmg のビルド (配布用)

[create-dmg](https://github.com/sindresorhus/create-dmg) を使うのがシンプル:

```bash
brew install create-dmg

# 1. Release ビルド
xcodebuild -project PomoTaskerMac.xcodeproj \
  -scheme PomoTaskerMac \
  -configuration Release \
  -derivedDataPath build

# 2. .dmg 生成
create-dmg "build/Build/Products/Release/PomoTaskerMac.app"
```

または、Xcode の **Product → Archive** から `.app` を書き出して、ディスクユーティリティで `.dmg` を作成。

## 開発について

このアプリは **AI (Claude) と人間の協働** で開発されています。コード品質に関する Issue / Pull Request を歓迎します。

## 技術スタック

| 領域 | 採用技術 |
|------|----------|
| UI | SwiftUI |
| 永続化 | SwiftData (ローカルのみ) |
| OCR | Vision framework (オンデバイス、日本語+英語、multi-pass) |
| メニューバー | MenuBarExtra (.window スタイル) |
| グラフ | Swift Charts |
| 通知 | UserNotifications |
| アーキテクチャ | MV (Model + View、Apple 公式推奨) |

## ディレクトリ構成

```
PomoTaskerMac/
├── PomoTaskerMac.xcodeproj
├── PomoTaskerMac/
│   ├── PomoTaskerMacApp.swift     # @main (PomodoroService + MenuBarExtra)
│   ├── ContentView.swift           # NavigationSplitView (5タブ)
│   ├── Models/                     # SwiftData @Model 群
│   ├── Services/                   # PomodoroTimer, Notification, OCR, Backup, TagMatcher
│   ├── Views/                      # Today / Pomodoro / Timeline / Stats / Goals / Settings / MenuBar
│   ├── Components/                 # CategoryBadge, CategorySelector
│   └── Extensions/                 # Date+Bucket
└── README.md
```

## ライセンス

[MIT License](LICENSE)

## 免責事項

このアプリは **無保証** で提供されます。データ損失等が発生しても作者は責任を負いません。重要なデータは Settings の「エクスポート」で定期的にバックアップしてください。

## 関連リンク

- YouTube: [4.5room](https://www.youtube.com/@4.5room)
