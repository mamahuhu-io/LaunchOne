# LaunchOne

**言語**: [English](../../README.md) | [中文](../../README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [Tiếng Việt](README.vi.md)

## 📥 ダウンロード

**[こちらからダウンロード](https://github.com/mamahuhu-io/LaunchOne/releases/latest)** - 最新バージョンを入手

⭐ [LaunchOne](https://github.com/mamahuhu-io/LaunchOne) と元のプロジェクト [LaunchNext](https://github.com/RoversX/LaunchNext) にスターをお願いします！

| | |
|:---:|:---:|
| ![](../assets/main.webp) | ![](../assets/setting-general.webp) |
| ![](../assets/setting-appearance.webp) | ![](../assets/setting-apptitle.webp) |

macOS Tahoe は Launchpad を削除し、新しい UI は使いづらく、Bio GPU を十分活用できません。Apple さん、少なくとも切り替えオプションをください。それまでは、LaunchOne をどうぞ。

*[RoversX](https://github.com/RoversX/LaunchNext) の [LaunchNext] をベースに開発しました。オリジナルプロジェクトに感謝します！*

*LaunchNext は GPL 3 ライセンスを選択しており、LaunchOne も同じ条件に従います。*

### LaunchOne が提供する機能
- ✅ **旧システムの Launchpad をワンクリックでインポート** — ネイティブの Launchpad SQLite データベース（`/private$(getconf DARWIN_USER_DIR)com.apple.dock.launchpad/db/db`）を直接読み取り、既存のフォルダ・アプリアイコン位置・レイアウトを完全再現
- ✅ **クラシックな Launchpad 体験** — 愛されてきたオリジナルと同じ操作性
- ✅ **多言語サポート** — 英語・中国語・日本語・フランス語・スペイン語に対応
- ✅ **アイコンラベルの非表示** — アプリ名が不要な場合のミニマルビュー
- ✅ **アイコンサイズのカスタマイズ** — 好みに合わせて調整
- ✅ **スマートなフォルダ管理** — これまで通りのフォルダ作成と整理
- ✅ **インスタント検索とキーボードナビゲーション** — アプリを素早く検索

### macOS Tahoe で失われた機能
- ❌ アプリのカスタム整理不可
- ❌ ユーザーフォルダの作成不可
- ❌ ドラッグ&ドロップによるカスタマイズ不可
- ❌ アプリのビジュアル管理不可
- ❌ 強制的なカテゴリ分け

## 機能

### 🎯 **アプリをすぐに起動**
- ダブルクリックで直接起動
- キーボードナビゲーションを完全サポート
- リアルタイムフィルタリングによる高速検索

### 📁 **高度なフォルダシステム**
- アプリを重ねてフォルダを作成
- インライン編集でフォルダ名を変更
- カスタムフォルダアイコンと整理
- アプリのドラッグ&ドロップがシームレス

### 🔍 **スマート検索**
- リアルタイムのあいまい一致
- すべてのインストール済みアプリを検索
- キーボードショートカットですばやくアクセス

### 🎨 **モダンな UI デザイン**
- **リキッドガラス効果**: regularMaterial と上品な影
- 全画面モードとウィンドウモード
- スムーズなアニメーションとトランジション
- シンプルでレスポンシブなレイアウト

### 🔄 **シームレスなデータ移行**
- **ワンクリック Launchpad インポート**（macOS ネイティブ DB から）
- アプリの自動検出とスキャン
- SwiftData によるレイアウトの永続化
- システム更新時のデータ損失ゼロ

### ⚙️ **システム統合**
- ネイティブ macOS アプリ
- マルチディスプレイ対応のスマート配置
- Dock や他のシステムアプリと連携
- 背景クリック検知（スマートクローズ）

## 技術アーキテクチャ

### モダンな技術で構築
- **SwiftUI**: 宣言的で高性能な UI フレームワーク
- **SwiftData**: 強力なデータ永続化レイヤー
- **AppKit**: macOS との深い統合
- **SQLite3**: Launchpad DB の直接読み取り

### データ保存
アプリデータは以下に安全に保存されます：
```
~/Library/Application Support/LaunchOne/Data.store
```

### ネイティブ Launchpad 統合
システム Launchpad DB から直接読み取り：
```bash
/private$(getconf DARWIN_USER_DIR)com.apple.dock.launchpad/db/db
```

## インストール

### システム要件
- macOS 26 (Tahoe) 以降
- Apple Silicon または Intel プロセッサ
- Xcode 26（ソースからのビルド用）

### ソースからビルド

1. **リポジトリをクローン**
   ```bash
   clone git@github.com:mamahuhu-io/LaunchOne.git
   cd LaunchOne
   ```

2. **Xcode で開く**
   ```bash
   open LaunchOne.xcodeproj
   ```

3. **ビルド & 実行**
   - ターゲットデバイスを選択
   - `⌘+R` でビルド＆実行
   - または `⌘+B` でビルドのみ

### コマンドラインでビルド
```bash
xcodebuild -project LaunchOne.xcodeproj -scheme LaunchOne -configuration Release
```

## 使い方

### クイックスタート
1. **初回起動**: LaunchOne がインストール済みアプリを自動スキャン
2. **選択**: クリックで選択、ダブルクリックで起動
3. **検索**: 入力でアプリを即時フィルタ
4. **整理**: アプリをドラッグしてフォルダやカスタムレイアウトを作成

### Launchpad をインポート
1. 設定（ギアアイコン）を開く
2. **"Import Launchpad"** をクリック
3. 既存のレイアウトとフォルダが自動的にインポートされます

### フォルダ管理
- **フォルダ作成**: アプリを重ねる
- **フォルダ名変更**: 名前をクリック
- **アプリ追加**: アプリをフォルダにドラッグ
- **アプリ削除**: フォルダからドラッグアウト

### 表示モード
- **ウィンドウ**: 角丸のフローティングウィンドウ
- **フルスクリーン**: 最大の可視性
- 設定で切り替え

## 既知の問題

> **現在の開発状況**
> - 🔄 **スクロール挙動**: 一部シーンで不安定になる場合があります（素早いジェスチャー時など）
> - 🎯 **フォルダ作成**: ドロップ判定が一部で不安定な場合があります
> - 🛠️ **積極開発中**: これらは今後のリリースで改善されます

## トラブルシューティング

### よくある質問

**Q: アプリが起動しない？**
A: macOS 26+ を確認し、システム権限をチェックしてください。

**Q: インポートボタンがない？**
A: SettingsView.swift にインポート機能が含まれているか確認してください。

**Q: 検索が動作しない？**
A: アプリの再スキャン、または設定からデータをリセットしてください。

**Q: パフォーマンスの問題？**
A: アイコンキャッシュ設定を確認し、アプリを再起動してください。

## なぜ LaunchOne？

### Apple の「Applications」インターフェースとの比較
| 機能 | Applications (Tahoe) | LaunchOne |
|---------|---------------------|------------|
| カスタム整理 | ❌ | ✅ |
| ユーザーフォルダ | ❌ | ✅ |
| ドラッグ&ドロップ | ❌ | ✅ |
| ビジュアル管理 | ❌ | ✅ |
| 既存データのインポート | ❌ | ✅ |
| パフォーマンス | 遅い | 速い |

### 他の Launchpad 代替との比較
- **ネイティブ統合**: Launchpad DB を直接読み取り
- **最新アーキテクチャ**: SwiftUI/SwiftData
- **依存なし**: ピュア Swift、外部ライブラリなし
- **アクティブ開発**: 定期的なアップデート
- **リキッドガラスデザイン**: 高品質な見た目

## 貢献

貢献を歓迎します！

1. リポジトリを Fork
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチをプッシュ (`git push origin feature/amazing-feature`)
5. Pull Request を作成

### 開発ガイド
- Swift のスタイルガイドに従う
- 複雑なロジックには簡潔で有用なコメントを
- 複数の macOS バージョンでテスト
- 後方互換性を維持

## アプリ管理の未来

Apple がカスタマイズ可能な UI から離れていく中で、LaunchOne はユーザーのコントロールとパーソナライズへのコミットメントを表します。ユーザーが自分のワークスペースをどう整理するかは、ユーザー自身が決めるべきだと信じています。

**LaunchOne** は単なる Launchpad の代替ではなく、ユーザーの選択が重要であるという宣言です。


---

**LaunchOne** — アプリランチャーを取り戻そう 🚀

*カスタマイズを妥協しない macOS ユーザーのために。*

## 開発ツール

このプロジェクトは以下のツールの助けを借りて開発されました：
- Claude Code - AI 開発アシスタント
- Cursor
- Cursor Cli - コード生成と最適化