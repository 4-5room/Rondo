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

## データ互換性 / バックアップ仕様

iOS 版で出力した JSON バックアップを **Mac 版で復元できる** ことを設計上の必須要件とする。
両アプリが同じ Snapshot スキーマを共有することで、ユーザーが iOS と Mac の間でデータ移行可能になる。

### Snapshot スキーマ(iOS 版から流用)

iOS 版 `BackupService.swift` の以下の DTO 構造をそのまま流用する:

```
Snapshot
├── version: Int                        # 現状 1。互換性ポリシーは下記
├── exportedAt: Date
├── fingerprint: UUID?                  # 自端末書込み判定用
├── tasks: [TaskItemDTO]
├── sessions: [PomodoroSessionDTO]
├── entries: [TimelineEntryDTO]
├── goals: [MonthlyGoalDTO]
└── settings: [UserSettingsDTO]
```

各 DTO のフィールド名・型・optional 性は **iOS 版と完全一致** させること。
不一致があると `JSONDecoder` で復元失敗する。

### バージョン互換性ポリシー

- **`Snapshot.version` は iOS 版 / Mac 版で常に揃える**
- スキーマ変更時のルール:
  - **新規フィールド追加** → optional(`?` 型)で追加。旧 JSON は nil で読み込まれる
  - **既存フィールド変更/削除** → 不可(version を上げて移行ロジックを書く)
- 双方向互換を維持する原則:
  - 旧 JSON → 新版アプリ: optional フィールドは nil で許容
  - 新 JSON → 旧版アプリ: 新フィールドは無視される

### 同期方法(Mac 版で対応する 3 種)

| 方法 | 説明 | 優先度 |
|---|---|---|
| **A. 同期フォルダ** | iOS 版と同様、ユーザー指定の任意フォルダ(iCloud Drive / Dropbox 等)に `rondo-sync.json` を読み書き。設定画面でフォルダ選択 | 🔴 必須 |
| **B. 手動 Import / Export** | `.fileImporter` / `NSOpenPanel` でファイル選択 → JSON 読み込み | 🔴 必須 |
| **C. iCloud コンテナ共有** | iOS と同じ Bundle ID にして同コンテナを共有(自動同期) | 🟡 任意。OSS 公開時のハードル↑なので **初期版では非対応** |

→ **同期は A + B で対応**。C は追加機能として後日検討。

### Mac 版で実装する Import / Export UI

- **メニュー**: ファイル → エクスポート / インポート
- **キーボードショートカット**:
  - `Cmd+Shift+E`: バックアップを書き出し
  - `Cmd+Shift+I`: ファイルから取り込み
- **ドラッグ&ドロップ**: メインウィンドウに JSON ファイルを D&D で取り込み

### 復元時の安全策

- インポート時は **既存データの自動バックアップを取ってからマージ**(誤上書き防止)
- `version` 不一致時はダイアログで警告表示
- マージ戦略は upsert(同じ ID は更新、無い ID は新規追加)— iOS 版と同じ

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
