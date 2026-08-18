# 便利な使い方

このdotfilesでよく使う操作を、目的別にまとめています。

Kittyとtmuxのペイン、タブ、コピー操作は[Kittyとtmuxのショートカット](terminal-shortcuts.md)にまとめています。

## 最近更新された項目を見る

`lt` は更新時刻の新しい順で一覧を表示します。`head` と組み合わせると、直近の項目だけを確認できます。

```zsh
# 新しい順に先頭10件
lt | head

# 先頭5件
lt | head -n 5
```

## ディレクトリ移動履歴を使う

`AUTO_PUSHD` が有効なので、`cd` で移動した場所は自動的にスタックへ保存されます。

```zsh
d
```

一覧と入力待ちが表示されたら、移動先の番号を入力します。スタックは最大20件です。1つ上へ移動するだけなら `cdd` を使えます。

ディレクトリ移動後は自動的に `ls` が実行されます。

## Zsh設定を再読み込みする

```zsh
sz
```

設定変更後に新しいターミナルを開かず反映できます。初期化処理をすべて再実行するため、問題の切り分けでは新しいシェルを起動する方法も有効です。

```zsh
exec zsh
```

## uv環境でPythonを実行する

```zsh
up script.py
up -m pytest
```

`up` は `uv run python` の短縮です。プロジェクトの仮想環境と依存関係を使って実行します。

## Git履歴をグラフ表示する

```zsh
g lgb
```

ブランチの分岐、コミットメッセージ、相対日時、作者をまとめて確認できます。

## 長いコマンドの終了をSlackへ通知する

まず `~/.zshrc.private` にWebhookを設定します。

```zsh
export SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...'
```

長いコマンドの後ろで `done-notify` を実行します。

```zsh
long-running-command; done-notify
```

実行ディレクトリと直前のコマンドがSlackへ送られます。WebhookをGitへ追加しないでください。

## 研究室サーバーのGPU利用状況を見る

```zsh
nvistat
```

v101〜v108へSSH接続し、GPU名、GPU使用率、メモリ使用率を一覧表示します。SSH設定と各サーバー上の `nvidia-smi` が必要です。

## PDFを圧縮する

```zsh
shrinkpdf report.pdf
```

Ghostscriptを使い、`report-s.pdf` を作成します。元ファイルは変更しません。

## Neovim設定をバックアップ・復元する

```zsh
backup-nvim
restore-nvim
```

> **警告:** `backup-nvim` は設定・データ・状態・キャッシュをコピーではなくタイムスタンプ付きディレクトリへ移動します。実行後は現在のNeovim環境が元の場所からなくなります。

> **注意:** `restore-nvim` は確認後、現在のNeovim関連ディレクトリを削除してから選択したバックアップを戻します。表示された4つのバックアップ先を確認してから実行してください。

## Quick LookとObsidianを開く

```zsh
ql document.pdf
obs search query="キーワード"
```

`ql` はmacOS専用です。`obs` はObsidian公式CLIを呼び出すため、Obsidianアプリを起動しておく必要があります。

## Sheldonプラグインを更新する

```zsh
sheldon lock --update
exec zsh
```

管理対象は `zsh-autosuggestions` と `zsh-syntax-highlighting` です。

## Starshipの状態を確認する

```zsh
starship explain
starship timings
```

プロンプトの1行目にはホスト、現在地、Git、開発環境、処理時間、時刻を表示し、2行目は入力欄として使います。
PythonとConda以外の情報もStarshipが自動検出し、必要な場合だけ1行目へ追加します。

## 起動トラブルを切り分ける

```zsh
command -v sheldon
command -v starship
sheldon lock
for file in \
  ~/.zshenv \
  ~/.zprofile \
  ~/.zshrc \
  ~/dotfiles/.config/zsh/*.zsh \
  ~/dotfiles/.config/zsh/functions/*.zsh \
  ~/dotfiles/.config/zsh/hosts/*.zsh
do
  zsh -n "$file" || break
done
```

SheldonまたはStarshipが見つからなくてもZsh自体は起動します。プラグインが出ない場合は `sheldon lock`、プロンプトが基本表示になる場合はStarshipのPATHを確認します。
