# エイリアス一覧

対話型Zshで利用できるエイリアスをまとめています。定義は主に [aliases.zsh](../.config/zsh/aliases.zsh) と [directories.zsh](../.config/zsh/directories.zsh) にあります。

## 一般コマンド

| エイリアス | 展開先 | 用途・注意 |
| --- | --- | --- |
| `emacs` | MacPorts版Emacsのターミナル起動 | v101〜v108、oroshi1ではホスト設定で上書き |
| `obs` | `obsidian` | Obsidian公式CLIの短縮。Obsidianアプリの起動が必要 |
| `sz` | `source ~/.zshrc` | Zsh設定を現在のシェルへ再読み込み |
| `ez` | `emacs ~/.zshrc` | Zshの入口ファイルを編集 |
| `py` | `python` | Pythonコマンドの短縮 |
| `g` | `git` | Gitコマンドの短縮 |
| `up` | `uv run python` | uv環境でPythonを実行 |
| `ql` | `qlmanage -p` | macOS Quick Lookでファイルを表示 |
| `ls` | `/bin/ls -GF` | ファイル種別記号を付けて表示。macOSでは色も付くが、GNU版の `-G` は別の意味 |
| `lt` | `ls -t` | 更新時刻の新しい順で一覧表示 |
| `remake` | `make clean && make` | ビルド成果物を消してから再ビルド |

`rm`はエイリアスではなくシェル関数として置き換えています。macOSではシステムのゴミ箱へ、Linuxでは`gio trash`（なければ`trash-put`）へ移動します。`-f`、`-r`、`-R`は互換性のため受け付けますが、trashへの移動自体には不要です。完全に削除するときだけ`command rm`を明示してください。利用可能なtrash機構がない場合、誤って完全削除しないようエラーで停止します。

## ディレクトリ移動

| エイリアス | 展開先 | 用途・注意 |
| --- | --- | --- |
| `cdd` | `cd ..` | 1つ上のディレクトリへ移動 |
| `d` | ディレクトリスタックを番号表示して移動 | 表示後に番号を入力。`AUTO_PUSHD` により移動履歴を最大20件保持 |

ディレクトリを移動すると `chpwd` 関数が自動で `ls` を実行します。

## 条件付きエイリアス

| エイリアス | 条件 | 展開先 |
| --- | --- | --- |
| `ssh` | Kitty上で実行している場合 | `kitten ssh` |

## Gitエイリアス

`.gitconfig` には次のGitエイリアスがあります。シェルエイリアスではないため `git` または `g` の後に指定します。

| コマンド | 用途 |
| --- | --- |
| `git lgb` / `g lgb` | ブランチ、コミット、相対日時、作者を色付きグラフで表示 |

## 確認方法

現在の定義は次のように確認できます。

```zsh
alias lt
alias g
git config --get-regexp '^alias\.'
```
