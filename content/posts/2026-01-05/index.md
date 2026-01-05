---
title: "このブログの構成"
date: 2026-01-05
description: "Hugo + Obsidian + Cloudflare Pages + Terraform で構築したブログの技術構成について"
tags:
  - Hugo
  - Obsidian
  - Cloudflare
  - Terraform
  - GitHub Actions
---

このブログの技術構成についてまとめる。

## 概要

```
Obsidian (執筆)
    ↓
Hugo (ビルド)
    ↓
GitHub Actions (CI/CD)
    ↓
Cloudflare Pages (ホスティング)
```

インフラ管理にはTerraformを使用している。

## 静的サイトジェネレーター: Hugo

静的サイトジェネレーターとして [Hugo](https://gohugo.io/) を採用した。

選定理由:

- Go製のシングルバイナリで依存関係が少ない
- テーマが豊富

テーマは [hugo-blog-awesome](https://github.com/hugo-sid/hugo-blog-awesome) を使用。ミニマルでかっこいい、ダークモード対応。

## 記事管理: Obsidian

記事の執筆・管理には [Obsidian](https://obsidian.md/) を使用している。

![Obsidianでの執筆画面](Screenshot%202026-01-05%20at%2021.55.31.png)

`content/posts` ディレクトリをObsidian Vaultとして開くことで、Markdownエディタとして活用できる。Obsidianの利点:

- Markdownのプレビューがリアルタイム
- 内部リンクやバックリンクで記事間の関連を把握できる
- プラグインで機能拡張可能

### 記事のディレクトリ構成

各記事は独立したディレクトリとして管理する。

```
content/posts/
├── .obsidian/           # Obsidian設定
├── 2026-01-05/
│   ├── index.md         # 記事本体
│   └── image.png        # 記事に使う画像
└── 2026-01-06/
    └── index.md
```

簡素だがこのようなMakefileを用意した

```Bash
post: ## Create new post (usage: make post)
 @if [ -z "$(TITLE)" ]; then echo "Usage: make post"; exit 1; fi
 @DIR="content/posts/$$(date +%Y-%m-%d)"; \
 mkdir -p "$$DIR"; \
 hugo new "posts/$$(date +%Y-%m-%d)/index.md"; \
 echo "Created: $$DIR/index.md"
```

この構成により:

- 記事と関連アセット（画像等）を同じディレクトリで管理できる
- ディレクトリ名でURLが決まるため、考える必要がない

ただし、YYYY-MM-DD形式なので1日1本しか書けないのが難点。
そんなに書かないだろうから自分はこれでよい。

## デプロイ先: Cloudflare Pages

ホスティングには [Cloudflare Pages](https://pages.cloudflare.com/) を使用。

メリット:

- 無料枠がHuge（帯域幅無制限、リクエスト無制限）
- グローバルCDN
- 自動SSL
- Preview環境（ブランチごとにプレビューURLが発行される）

カスタムドメイン `blog.wtnqk.org` を設定している。

## CI/CD: GitHub Actions

GitHub Actionsで、mainブランチへのpush時に自動デプロイを実行する。

```yaml
name: Deploy

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
          fetch-depth: 0

      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v3
        with:
          hugo-version: "latest"
          extended: true

      - name: Build
        run: hugo --minify

      - name: Deploy to Cloudflare Pages
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy public --project-name=wtnqk-blog
```

ワークフローの流れ:

1. リポジトリをチェックアウト（テーマはsubmoduleとして管理）
2. Hugoでビルド
3. wranglerでCloudflare Pagesにデプロイ

## インフラ管理: Terraform

Cloudflareのリソース管理にTerraformを使用している。

管理対象:

- Cloudflare Pagesプロジェクト
- カスタムドメイン設定
- DNSレコード（CNAME）

```hcl
resource "cloudflare_pages_project" "blog" {
  account_id        = var.cloudflare_account_id
  name              = var.project_name
  production_branch = "main"
}

resource "cloudflare_pages_domain" "blog" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.blog.name
  domain       = var.custom_domain
}

resource "cloudflare_record" "blog" {
  zone_id = var.cloudflare_zone_id
  name    = var.dns_record_name
  content = cloudflare_pages_project.blog.subdomain
  type    = "CNAME"
  proxied = true
}
```

Terraformを使う理由:

- インフラをコードで管理できる（Infrastructure as Code）
- 変更履歴がGitで追跡できる
- 環境の再現が容易

## まとめ

| 役割                     | 技術             |
| ------------------------ | ---------------- |
| 静的サイトジェネレーター | Hugo             |
| 記事執筆・管理           | Obsidian         |
| ホスティング             | Cloudflare Pages |
| CI/CD                    | GitHub Actions   |
| インフラ管理             | Terraform        |

この構成により、記事を書いてpushするだけで自動的にデプロイされる快適な執筆環境が実現できた。

## さいごに

いずれはTypstをつかったジェネレータに移管したい。
また次の記事でお会いしましょう。ノシ
