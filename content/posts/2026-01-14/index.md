---
title: "tmux学習"
date: 2026-01-14
description: "tmuxを用いた開発環境について"
tags:
  - tmux
  - terminal
---

## はじめに

開発作業をしていると、複数のターミナルセッションを効率的に管理したいと思うことはありませんか？SSHで作業中に接続が切れて、実行中のプロセスが止まってしまった経験はないでしょうか？

今回は、そんな悩みを解決してくれるターミナルマルチプレクサ「tmux」の魅力について紹介します。

## tmuxとは

tmuxは、1つのターミナルで複数のセッションを管理できるターミナルマルチプレクサです。
以下がtmuxの特徴になります。

- **セッションの永続化**: デタッチ・アタッチ機能により、ターミナルを閉じても作業を継続可能
- **画面分割**: 1つの画面を複数のペインに分割して作業効率UP
- **SSHセッションの保護**: 接続が切れても実行中のプロセスは継続

## なぜtmuxを選ぶのか

### 設計思想：「コアは薄く、拡張性は高く」

tmuxの最大の魅力は、必要最小限の機能だけを提供し、ユーザーが自由に拡張できる設計にあります。これにより、**"for me"な環境**を自分で作る楽しさを体験できます。

### プロセスとターミナルの分離

tmuxはクライアント・サーバーアーキテクチャを採用しており、ターミナル（表示）とプロセス（実行）が分離されています。通常のターミナルでは、ターミナルを閉じるとそこで実行中のプロセスも一緒に終了してしまいますが、tmuxではサーバー側でプロセスが動作し続けるため、ターミナルの切断がプロセスに影響しません。

これが特に活きる場面として：

- **バッチ実行中のSSH切断**: 長時間かかるデプロイやビルドの途中でSSH接続が切れても、プロセスはtmuxサーバー上で動き続ける
- **ネットワーク不安定な環境**: 再接続して`tmux attach`するだけで、作業状態がそのまま復元される
- **意図的なデタッチ**: 重い処理を走らせたまま`Ctrl-b d`でデタッチし、別の作業に移れる

`nohup`や`disown` でも同様のことは可能ですが、tmuxなら実行中の出力をいつでも確認でき、対話的な操作も再開できる点が大きな違いです。

### 豊富なプラグインエコシステム

[tmux-plugins](https://github.com/tmux-plugins/list)では、数多くのプラグインが公開されています：

- **tmux-resurrect**: セッションの保存・復元
- **tmux-continuum**: 自動保存機能
- **tmux-yank**: コピー機能の拡張
- **tmux-fzf**: fuzzy finderとの連携

## tmuxの基本概念

tmuxは3つの階層で管理されます：

```
セッション
├── ウィンドウ1（タブのような概念）
│   ├── ペイン1
│   └── ペイン2
└── ウィンドウ2
    └── ペイン1
```

- **セッション**: プロジェクトごとなどの作業単位
- **ウィンドウ**: ブラウザのタブのような概念
- **ペイン**: 画面分割の単位

## 基本的な使い方

### セッション管理

```bash
# 新規セッション作成
tmux new -s session-name

# セッション一覧
tmux ls

# セッションにアタッチ
tmux attach -t session-name

# セッションからデタッチ
# セッション内で: Ctrl-b d
```

### よく使うキーバインド

デフォルトのプレフィックスキーは `Ctrl-b` です：

```
C-b c    # 新規ウィンドウ作成
C-b n    # 次のウィンドウへ
C-b p    # 前のウィンドウへ
C-b .    # 垂直分割
C-b ,    # 水平分割
C-b z    # ペインの最大化/元に戻す
C-b s    # セッション選択
```

## おすすめ設定

`~/.tmux.conf` に以下のような設定を追加することで、より使いやすくなります：

### プラグイン管理（TPM）

```bash
# TPMのインストール
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

```conf
# ~/.tmux.conf
# プラグイン設定
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-pain-control'
set -g @plugin 'sainnhe/tmux-fzf'

# TPMの初期化（最下部に記載）
run '~/.tmux/plugins/tpm/tpm'
```

### 便利な設定

```conf
# プレフィックスキーをC-aに変更（ワタナベはC-a派）
set-option -g prefix C-a
unbind-key C-b
bind-key C-a send-prefix

# マウス操作を有効化
set-option -g mouse on

# ペイン移動
bind-key h select-pane -L
bind-key j select-pane -D
bind-key k select-pane -U
bind-key l select-pane -R

# ペインリサイズ（-rで連続押し可能）
bind-key -r H resize-pane -L 5
bind-key -r J resize-pane -D 5
bind-key -r K resize-pane -U 5
bind-key -r L resize-pane -R 5
```

## プロジェクト別セッション自動化

開発環境を素早く立ち上げるスクリプトを作成するとチョー便利です：

```bash
#!/bin/bash
# tmux-project.sh

SESSION="myproject"

# エディタウィンドウ
tmux new-session -d -s $SESSION -n editor
tmux send-keys -t $SESSION:editor 'cd ~/project && nvim' C-m

# 開発サーバーウィンドウ
tmux new-window -t $SESSION -n server
tmux send-keys -t $SESSION:server 'cd ~/project && npm run dev' C-m

# Gitウィンドウ
tmux new-window -t $SESSION -n git
tmux send-keys -t $SESSION:git 'cd ~/project && git status' C-m

# セッションにアタッチ
tmux attach -t $SESSION
```

## まとめ

1. **薄いコア設計**: 必要な機能だけを自分で追加できる自由度
2. **豊富なエコシステム**: 活発なコミュニティとプラグイン開発
3. **効率的な操作体系**: カスタマイズ可能なキーバインドで作業効率UP

---

## 昔つくったスライド

みつけたら

## 参考資料

- [tmux公式Wiki](https://github.com/tmux/tmux/wiki)
- [tmux plugins一覧](https://github.com/tmux-plugins)
- [tmux cheat sheet](https://tmuxcheatsheet.com/)
