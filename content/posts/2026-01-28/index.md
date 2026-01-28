---
title: "ftdv紹介"
date: 2026-01-24
description: "TUIつくってみた"
tags:
  - ratatui
  - rust
---

以前自分がせっせこ作っていたTUIツールになります。

| サイト    | URL                             |
| --------- | ------------------------------- |
| GitHub    | <https://github.com/wtnqk/ftdv> |
| crates.io | <https://crates.io/crates/ftdv> |

ftdv (File Tree Diff Viewer) は、[diffnav](https://github.com/dlvhdr/diffnav) と [lazygit](https://github.com/jesseduffield/lazygit) にインスパイアされたターミナルベースのdiffビューアで、Rustの [ratatui](https://github.com/ratatui-org/ratatui) で構築されています。
diffnavの直感的なファイルナビゲーションとlazygitの柔軟なdiffツール設定システムを組み合わせ、delta、bat、ydiff、difftasticなどの様々なdiffツールをサポートするgit diffの対話的なインターフェースを提供します。

## 概要

![image][461091774-43ab0c27-0764-4342-a049-fb4930463811.png]

## 設計思想

ftdvは、対話的なgit統合に焦点を当てたモダンなTUI diffページャーです：

- **直接的なgit統合**: gitオペレーションのネイティブサポート（`ftdv branch1 branch2`）
- **ファイル単位のdiff**: 選択されたファイルごとに新しいdiffコンテンツ
- **外部ツール統合**: delta、difftastic、bat、ydiffなどの柔軟な設定
- **対話的なナビゲーション**: 永続的な状態を持つファイルツリーインターフェース

## 機能

- ディレクトリ折りたたみ機能を持つ対話的なファイルツリーナビゲーション（diffnavにインスパイア）
- テンプレート変数を使用した柔軟なdiffツール設定（lazygitにインスパイア）
- 複数のdiffツールのサポート：delta、bat、ydiff、difftasticなど
- ANSIカラーサポート - カラー出力を自動的に検出してレンダリング
- レビュー済みファイルをマークするチェックボックス機能（レビュー追跡）
- チェック済みファイルの永続的な状態管理
- リアルタイムフィルタリング付き検索機能
- Vimスタイルのキーボードナビゲーション
- カスタマイズ可能なテーマとカラー
- 直接的なファイル/ディレクトリ比較サポート
- 複数の操作モードを持つGit統合

## インストール

```bash
# crates.ioからインストール
cargo install ftdv

# またはソースからクローンしてビルド
git clone https://github.com/wtnqk/ftdv.git
cd ftdv
cargo install --path .
```

## 使い方

### 基本コマンド

```bash
# 作業ディレクトリの変更を表示（デフォルト）
ftdv

# ステージされた変更を表示
ftdv --cached

# 特定のコミット/ブランチと比較
ftdv main

# 2つのコミット/ブランチを比較
ftdv main feature-branch

# 2つのファイルを比較
ftdv file1.txt file2.txt

# 2つのディレクトリを比較
ftdv dir1/ dir2/

# シェル補完を生成
ftdv completions bash > ftdv.bash
```

### キーボードショートカット

#### ナビゲーション

| キー      | アクション                       |
| --------- | -------------------------------- |
| `j` / `↓` | ファイルリストで下に移動         |
| `k` / `↑` | ファイルリストで上に移動         |
| `g`       | ファイルリストの最上部へジャンプ |
| `G`       | ファイルリストの最下部へジャンプ |

#### Diffコンテンツスクロール

| キー             | アクション                 |
| ---------------- | -------------------------- |
| `h` / `←`        | diff左スクロール（5文字）  |
| `l` / `→`        | diff右スクロール（5文字）  |
| `H`              | diff左スクロール（20文字） |
| `L`              | diff右スクロール（20文字） |
| `e` / `J`        | diff下スクロール（1行）    |
| `y` / `K`        | diff上スクロール（1行）    |
| `d` / `PageDown` | diff下スクロール（10行）   |
| `u` / `PageUp`   | diff上スクロール（10行）   |
| `f`              | diff下スクロール（20行）   |
| `b`              | diff上スクロール（20行）   |

#### ファイル操作

| キー    | アクション                     |
| ------- | ------------------------------ |
| `Enter` | ディレクトリの展開/折りたたみ  |
| `Space` | diffコンテンツの更新           |
| `Tab`   | ファイルチェックボックスの切替 |

#### 検索

| キー        | アクション           |
| ----------- | -------------------- |
| `/`         | 検索モードに入る     |
| `Enter`     | 検索確定（検索中）   |
| `Esc`       | 検索モードを終了     |
| `Backspace` | 文字を削除（検索中） |

#### アプリケーション

| キー  | アクション                                 |
| ----- | ------------------------------------------ |
| `q`   | アプリケーションを終了                     |
| `Esc` | アプリケーションを終了（検索中でない場合） |

## 設定

ftdvは `~/.config/ftdv/config.yaml` にあるYAML設定ファイルを使用します。

### 基本設定構造

```yaml
# Gitページング設定
git:
  paging:
    # stdin/stdoutベースのツール用（delta、bat、ydiff）
    pager: "オプション付きコマンド"

    # 外部diffツール用（difftastic）
    externalDiffCommand: "オプション付きコマンド"

    # gitに渡されるカラー引数
    colorArg: "always"

    # gitの設定されたページャーを使用
    useConfig: false

# テーマ設定
theme:
  name: dark
  colors:
    # カラー定義...
```

### Diffツール設定

#### Delta（推奨）

```yaml
git:
  paging:
    pager: "delta --dark --paging=never --line-numbers --side-by-side -w={{diffAreaWidth}}"
    colorArg: "always"
```

#### bat

```yaml
git:
  paging:
    pager: "bat --style=plain --color=always --terminal-width={{diffAreaWidth}}"
    colorArg: "always"
```

#### ydiff

```yaml
git:
  paging:
    pager: "ydiff -p cat --color=always --theme=dark --width={{diffAreaWidth}}"
    colorArg: "always"
```

#### difftastic

```yaml
git:
  paging:
    # 注意：difftasticはpagerではなくexternalDiffCommandを使用します
    externalDiffCommand: "difft --color=always --background dark --width {{diffAreaWidth}}"
    colorArg: "always"
```

### テンプレート変数

以下のテンプレート変数（lazygitの設定システムにインスパイア）がpagerとexternalDiffCommand文字列で使用できます：

| 変数                  | 説明                                         |
| --------------------- | -------------------------------------------- |
| `{{width}}`           | ターミナルの全幅                             |
| `{{columnWidth}}`     | ターミナル幅の半分からパディングを引いた値   |
| `{{diffAreaWidth}}`   | diff表示エリアの幅（80%）                    |
| `{{diffColumnWidth}}` | diff表示エリア幅の半分（サイドバイサイド用） |

### テーマ設定

#### カラーオプション

カラーは以下で指定できます：

- 名前付きカラー：`black`、`red`、`green`、`yellow`、`blue`、`magenta`、`cyan`、`white`
- グレーバリアント：`gray`、`dark_gray`
- ライトバリアント：`light_red`、`light_green`、`light_yellow`など
- RGB 16進コード：`#ff0000`、`#00ff00`、`#323264`
- 256カラーパレット：`color0`から`color255`

#### テーマ例

##### ダークテーマ（デフォルト）

```yaml
theme:
  name: dark
  colors:
    # ファイルツリー
    tree_line: dark_gray
    tree_selected_bg: "#323264"
    tree_selected_fg: yellow
    tree_directory: blue
    tree_file: white

    # ステータス
    status_added: green
    status_removed: red
    status_modified: yellow

    # UI
    border: dark_gray
    border_focused: cyan
    title: cyan
    status_bar_bg: dark_gray
    status_bar_fg: white

    # テキスト
    text_primary: white
    text_secondary: gray
    text_dim: dark_gray

    # 背景
    background: black
```

##### ライトテーマ

```yaml
theme:
  name: light
  colors:
    tree_selected_bg: "#e6e6fa"
    tree_selected_fg: black
    tree_directory: blue
    tree_file: black
    status_added: green
    status_removed: red
    border: gray
    border_focused: blue
    text_primary: black
    background: white
```

## 高度な使い方

### 異なるDiffツールの使用

#### ページャーと外部Diffコマンド

- **ページャー**：stdin経由でdiffコンテンツを受け取るツール（delta、bat、ydiff）
- **外部Diffコマンド**：Gitの外部diffメカニズムで動作するツール（difftastic）

この区別は重要です：

1. ページャーはstdinを通じてdiffコンテンツを受け取ります
2. 外部diffツールはGitによってファイルパスを引数として呼び出されます

### カスタムDiffツール統合

新しいdiffツールを追加するには：

1. それがページャーか外部diffツールかを判断します
2. 適切な設定を追加します：

```yaml
# ページャーツールの場合
git:
  paging:
    pager: "your-tool --option1 --width={{diffAreaWidth}}"
    colorArg: "always"

# 外部diffツールの場合
git:
  paging:
    externalDiffCommand: "your-tool --option1 --width {{diffAreaWidth}}"
    colorArg: "always"
```

### 永続性

ftdvは `~/.local/share/ftdv/` に永続的なデータを保存します：

- チェック済みファイルの状態はセッション間で保持されます

## トラブルシューティング

### よくある問題

#### Diffツールが動作しない

1. ツールがインストールされ、PATHに含まれていることを確認
2. `pager`または`externalDiffCommand`を使用すべきか確認
3. 設定でコマンド構文を確認

#### 幅の問題

- ほとんどの場合は`{{diffAreaWidth}}`を使用
- 一部のツールはターミナル全幅のために`{{width}}`が必要かもしれません
- ツールが`COLUMNS`環境変数を読み取るか確認

#### カラーが表示されない

- `colorArg: "always"`が設定されていることを確認
- 一部のツールは追加のカラーフラグが必要かもしれません
