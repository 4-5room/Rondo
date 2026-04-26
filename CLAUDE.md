# CLAUDE.md — PomoTaskerMac

iOS/iPadOS 向けポモドーロタスク管理アプリ「PomoTasker」(別名 Rondo)の **macOS ネイティブ版**。
**GitHub 公開を前提とした OSS プロジェクト** として独立リポジトリで開発する。

---

## 基本情報

- **対象 OS**: macOS 14.0 (Sonoma) 以上を想定
- **言語/フレームワーク**: Swift 5.9+ / SwiftUI(macOS) / SwiftData
- **配布形態**: GitHub OSS(リポジトリ名は後日決定。仮: `PomoTaskerMac`)
- **作業ディレクトリ**: `~/AIタスク/個人用/PomoTaskerMac/`
- **Claude Code**: このプロジェクト単体で運用(iOS 版とは別セッション)

---

## 元プロジェクト(参照のみ)

iOS 版コード:
```
~/AIタスク/個人用/PomoTasker/PomoTasker/PomoTasker/
```

- iOS 版から **モデル / ロジックは流用可**(コピー後に macOS 用にリファクタ)
- ただし依存関係(UIKit / ActivityKit / CoreMotion など)は注意
- **Mac で意味のない機能は移植しない**(下記スコープ参照)

---

## 機能スコープ

### 採用する機能(iOS 版から移植)
- ポモドーロタイマー(集中 / 休憩、カウントアップモード)
- タスク管理(Today / Timeline / Stats / Goals)
- カテゴリ(緊急 / 重要 / 特殊 / 通常)
- 生活領域(仕事 / プライベート)
- タグ機能 + サジェスト(チップ UI)
- 累計時間集計
- バックアップ / 復元(JSON)
- カラーパレット(テーマ切替)

### macOS 向け代替仕様
- **OCR**: カメラ機能は廃止。**ファイル(画像 / PDF)からの読み込みのみ**
  - ドラッグ&ドロップ対応
  - Vision フレームワーク自体は macOS でも使えるので、認識ロジックは流用可
- **メニューバーアプリ機能を追加**:
  - iOS の Live Activity / Dynamic Island の代替
  - メニューバーから残り時間 / 状態 / 最優先タスクをチラ見せ
  - メニューバーからタイマーの一時停止 / 再開 / 中断ができる
- **キーボードショートカット**: macOS らしさのため要検討(タイマー開始/停止、新規タスク等)
- **マルチウィンドウ**: SwiftUI の Scene を活用

### 非対応機能(Mac には不要)
- **モーションセンサー**(landscape 検知での自動開始): Mac にハードがない
- **iOS Live Activity / Dynamic Island**: 存在しない
- **iOS 通知**: 必要なら macOS の `UNUserNotificationCenter` で代替
- **カレンダー連動**: 初期版は省略。必要なら EventKit (macOS) で対応

---

## 想定ディレクトリ構成

```
PomoTaskerMac/
├── CLAUDE.md                # ←本ファイル
├── README.md                # GitHub 公開用(後で整備)
├── LICENSE                  # MIT 想定(後で確定)
├── .gitignore
├── PomoTaskerMac.xcodeproj
├── PomoTaskerMac/
│   ├── App/                 # PomoTaskerMacApp.swift, MenuBarExtra
│   ├── Models/              # TaskItem, PomodoroSession, ... (iOS 版から流用)
│   ├── Services/            # PomodoroTimerService, OCRService, BackupService...
│   ├── Views/
│   │   ├── Main/            # メインウィンドウ
│   │   ├── MenuBar/         # メニューバー UI
│   │   ├── Today/
│   │   ├── Timeline/
│   │   ├── Stats/
│   │   └── Goals/
│   ├── Components/          # 共通 UI 部品
│   └── Resources/           # アセット、Info.plist 相当
└── PomoTaskerMacTests/
```

---

## 開発フェーズ(暫定)

1. **基盤整備**: Xcode プロジェクト雛形作成、SwiftData モデル移植
2. **コア機能**: タイマー、Today タブ、タスク CRUD
3. **タブ整備**: Timeline、Stats、Goals
4. **メニューバー**: MenuBarExtra で常駐
5. **OCR (ファイル)**: Vision で画像読み込み → タスク化
6. **バックアップ**: JSON 入出力
7. **設定 / テーマ**: カラーパレット、ショートカット
8. **OSS 公開準備**: README、LICENSE、スクショ、ビルド手順

---

## グローバルルール継承

`~/CLAUDE.md` のグローバルルールを継承する。要約:
- **日本語で返答**、回答は簡潔に
- 不明点は **必ず確認**(勝手に判断しない)
- **ファイル削除しない**
- 既存ファイル編集前に **内容確認**
- **新規ファイル作成は事前確認**
- 既存コードのスタイルに合わせる
- **ライブラリ追加は事前確認**
- コメントは過不足なく

---

## このプロジェクト固有のルール

### iOS 版からのコード移植
- **コピーペーストではなく、Mac 専用にリファクタリングして移植**する
- `#if os(iOS)` のような条件分岐は最小限。Mac 専用実装の方が読みやすい
- モデル(`TaskItem` など)は流用。Service 層の UIKit 依存は要置換
- ビュー(`TaskRowView` など)は iOS 用 UI 前提なので、macOS 用に再設計する場合あり

### OSS 公開を意識
- **コミットメッセージは英語**(GitHub 公開のため)
- **Bundle ID / 開発者情報は最終段階で確定**
- **機密情報を含めない**(API キー、署名証明書 等)
- 必要なら **環境変数 / `.xcconfig` で外部化**

### macOS UX
- メインウィンドウ + メニューバーの **2 重インターフェース**
- ウィンドウを閉じてもアプリは終了しない(メニューバー常駐)
- **キーボードショートカット**を多用(macOS らしさ)
- **Cmd+N**: 新規タスク、**Cmd+Space**: タイマー操作 など(後で確定)

---

## メモ

- iOS 版で「タグ機能」「LifeArea (仕事/プライベート)」「カウントアップタイマー」が実装済み。これらは Mac 版でも継承
- iOS 版でレイアウト試行錯誤中だったが、Mac 版は最初から綺麗な UI を作る方針(画面領域が広いため、List + Sidebar 構造が自然)
- Mac 版 OCR は手書きノートよりも、**スクリーンショットや PDF からのタスク取り込み** が主用途になる想定
