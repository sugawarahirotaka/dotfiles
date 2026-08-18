# Kittyとtmuxのショートカット

このdotfilesで利用できるKittyとtmuxの操作をまとめる。
Kittyが「window」と呼ぶ領域は、同じタブ内を分割して表示するペインに相当する。

表では、`⌘`をCommand、`Ctrl`をControl、`Shift`をShiftキーとして表記する。
`Ctrl-q`、`|`のようにコンマで区切った操作は、両方を同時に押すのではなく、`Ctrl-q`を離してから`|`を押す。

## Kittyのペイン操作

KittyはGridレイアウトだけを有効にしている。
複数のペインを作ると、利用できる領域へ格子状に配置される。

このdotfilesで追加した操作は次のとおりである。

| キー | 操作 | 補足 |
| --- | --- | --- |
| `⌘D` | ペインを追加 | 現在のペインと同じディレクトリでZshを開く |

Kittyの既定設定から、ペイン操作に利用できる主なキーも有効である。

| キー | 操作 | 補足 |
| --- | --- | --- |
| `⌘Enter` | ペインを追加 | Kitty既定の新規window操作 |
| `Shift-⌘D` | 現在のペインを閉じる | 実行中の処理がある場合は終了に注意する |
| `Ctrl-Shift-]` | 次のペインへ移動 | 同じタブ内を順番に移動する |
| `Ctrl-Shift-[` | 前のペインへ移動 | 同じタブ内を逆順に移動する |
| `⌘1`〜`⌘9` | 番号でペインを選択 | 左上から時計回りに数える |
| `⌘R` | サイズ変更モードを開始 | 画面に表示されるキーで大きさを調整する |

`⌘D`は現在のディレクトリを確実に引き継ぐため、通常はこちらを使う。

## KittyのタブとOSウィンドウ

KittyのタブとmacOS上のウィンドウは、ペインとは別の階層で管理される。

| キー | 操作 |
| --- | --- |
| `⌘T` | タブを追加 |
| `⌘W` | 現在のタブを閉じる |
| `Shift-⌘]` | 次のタブへ移動 |
| `Shift-⌘[` | 前のタブへ移動 |
| `⌘N` | macOS上のKittyウィンドウを追加 |
| `Shift-⌘W` | macOS上のKittyウィンドウを閉じる |

## tmuxのプレフィックス

tmuxの操作は、最初に**プレフィックス**を入力してから操作キーを押す。
このdotfilesでは既定の`Ctrl-b`を無効化し、`Ctrl-q`へ変更している。

例えば、左右に分割するときは`Ctrl-q`を押して離し、その後で`|`を押す。

## tmuxのペイン操作

| キー | 操作 | 補足 |
| --- | --- | --- |
| `Ctrl-q`、`|` | 左右に分割 | 新しいペインを右側へ作る |
| `Ctrl-q`、`-` | 上下に分割 | 新しいペインを下側へ作る |
| `Ctrl-q`、`h` | 左のペインへ移動 | Vimと同じ方向キー |
| `Ctrl-q`、`j` | 下のペインへ移動 | Vimと同じ方向キー |
| `Ctrl-q`、`k` | 上のペインへ移動 | Vimと同じ方向キー |
| `Ctrl-q`、`l` | 右のペインへ移動 | Vimと同じ方向キー |
| `Ctrl-q`、`H` | 左方向へ5セル変更 | プレフィックス後に`H`を続けて押せる |
| `Ctrl-q`、`J` | 下方向へ5セル変更 | プレフィックス後に`J`を続けて押せる |
| `Ctrl-q`、`K` | 上方向へ5セル変更 | プレフィックス後に`K`を続けて押せる |
| `Ctrl-q`、`L` | 右方向へ5セル変更 | プレフィックス後に`L`を続けて押せる |
| `Ctrl-q`、`S` | 全ペインへの同期入力を切り替える | 再度押すと解除する |

同期入力中は、コマンドだけでなくパスワードや終了操作も全ペインへ送られる。
一括操作が終わったら、ステータスメッセージが`off`になるまで`Ctrl-q`、`S`を押す。

## tmuxのウィンドウ操作

tmuxの**ウィンドウ**は、複数のペインをまとめるタブに相当する。
次のキーはtmuxの既定操作であり、プレフィックスだけ`Ctrl-q`へ置き換わっている。

| キー | 操作 |
| --- | --- |
| `Ctrl-q`、`c` | tmuxウィンドウを追加 |
| `Ctrl-q`、`n` | 次のtmuxウィンドウへ移動 |
| `Ctrl-q`、`p` | 前のtmuxウィンドウへ移動 |
| `Ctrl-q`、`1`〜`9` | 番号でtmuxウィンドウを選択 |
| `Ctrl-q`、`,` | tmuxウィンドウの名前を変更 |

## tmuxのコピー操作

マウスホイールを上へ動かすと、必要に応じてコピーモードへ入る。
キーボードだけで操作する場合は、`Ctrl-q`、`[`でコピーモードへ入る。

| キー | 操作 |
| --- | --- |
| `v` | 文字単位の選択を開始 |
| `V` | 行単位の選択を開始 |
| `Ctrl-v` | 矩形選択へ切り替え |
| `y` | 選択範囲をtmuxバッファへコピー |
| `Y` | 現在行をtmuxバッファへコピー |
| `Ctrl-q`、`Ctrl-p` | tmuxバッファを貼り付け |

## v101からv108を8ペインで操作する

tmuxの外で次のコマンドを実行する。

```zsh
tmux new-session -d -s vservers 'ssh v101'
for host in v102 v103 v104 v105 v106 v107 v108; do
  tmux split-window -t vservers:1 "ssh $host"
  tmux select-layout -t vservers:1 tiled
done
tmux attach-session -t vservers
```

接続後に`Ctrl-q`、`S`で同期入力を有効にし、全サーバーで同じコマンドを実行する。

```zsh
cd ~/dotfiles &&
  git fetch --prune &&
  git merge --ff-only '@{u}' &&
  ./deploy.sh &&
  { ! command -v sheldon >/dev/null || sheldon lock; } &&
  exec zsh
```

既存のシンボリックリンクが正しければ、マージしたファイルはリンク先へそのまま反映されるため、`deploy.sh`は毎回の更新に必須ではない。
それでも、新しい配布対象が追加された場合やリンクが欠けている場合に備え、定型手順ではマージ後に実行する。

`plugins.toml`が変わった場合は、`sheldon lock`がプラグインのロック情報を更新する。
Sheldonが入っていないホストでも一括操作を止めないよう、コマンドの存在を確認してから実行する。

Zshの設定ファイルは起動時に読み込むため、最後の`exec zsh`で現在のシェルへ反映する。
`.zprofile`を変更した場合は、`exec zsh`ではなく`exec zsh -l`でログインシェルを起動し直す。

`deploy.sh`が既存ファイルの置き換えを質問した場合は、ホストごとに状態が異なる可能性がある。
その場で`Ctrl-q`、`S`を押して同期入力を解除し、各ペインの対象ファイルとバックアップ先を確認してから回答する。

処理が終わったら、`Ctrl-q`、`S`で同期入力を解除する。

## StarshipとSheldonを8台へ導入する

StarshipとSheldonは、公式GitHubリポジトリを各ホストの`~/.local/src`へcloneしてビルドする。
v101〜v108にはRustとCargoが入っていないため、初回だけ公式rustupを導入する。

同期入力を有効にし、次のコマンドを実行する。

```zsh
if [[ -r "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
fi

if ! command -v rustup >/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
    sh -s -- -y --profile minimal --no-modify-path
  source "$HOME/.cargo/env"
fi

rustup update stable
mkdir -p "$HOME/.local/src" "$HOME/.local/bin"

if [[ ! -d "$HOME/.local/src/starship/.git" ]]; then
  git clone https://github.com/starship/starship.git \
    "$HOME/.local/src/starship"
fi
git -C "$HOME/.local/src/starship" pull --ff-only
cargo build --release --locked \
  --manifest-path "$HOME/.local/src/starship/Cargo.toml"
ln -sfn "$HOME/.local/src/starship/target/release/starship" \
  "$HOME/.local/bin/starship"

if [[ ! -d "$HOME/.local/src/sheldon/.git" ]]; then
  git clone https://github.com/rossmacarthur/sheldon.git \
    "$HOME/.local/src/sheldon"
fi
git -C "$HOME/.local/src/sheldon" pull --ff-only
cargo build --release --locked \
  --manifest-path "$HOME/.local/src/sheldon/Cargo.toml"
ln -sfn "$HOME/.local/src/sheldon/target/release/sheldon" \
  "$HOME/.local/bin/sheldon"

starship --version
sheldon --version
```

8台で同時にRustをビルドするため、完了まで時間がかかる。
いずれかのペインでエラーが出た場合は同期入力を解除し、そのホストのログを個別に確認する。

## StarshipとSheldonを更新する

clone済みの公式ソースは、pullと再ビルドで更新する。
同期入力を有効にして次を実行する。

```zsh
source "$HOME/.cargo/env"
rustup update stable

git -C "$HOME/.local/src/starship" pull --ff-only &&
  cargo build --release --locked \
    --manifest-path "$HOME/.local/src/starship/Cargo.toml" &&
  git -C "$HOME/.local/src/sheldon" pull --ff-only &&
  cargo build --release --locked \
    --manifest-path "$HOME/.local/src/sheldon/Cargo.toml" &&
  starship --version &&
  sheldon --version
```

ビルド後も`~/.local/bin`のシンボリックリンクは同じ場所を指すため、作り直す必要はない。
更新が終わったら`Ctrl-q`、`S`で同期入力を解除する。

## private設定を追加する

`~/.zshrc.private`は、Webhookやホストごとの秘密値を置くGit管理外のファイルである。
`git merge`と`deploy.sh`は、この実ファイルを作成、更新しない。

ファイルがないホストでは、次のコマンドで見本から作成する。

```zsh
if [[ ! -e ~/.zshrc.private ]]; then
  cp ~/dotfiles/.zshrc.private.example ~/.zshrc.private
  chmod 600 ~/.zshrc.private
fi
```

このコマンドは既存ファイルを上書きしないため、8ペインへの同期入力でも実行できる。
作成後の秘密値は、同期入力を解除してから各ホストで編集する。
コマンドラインへ秘密値を書くとシェル履歴へ残るため、エディターを使う。

```zsh
${EDITOR:-vi} ~/.zshrc.private
exec zsh
```

新しいprivate変数をdotfilesの機能から参照する場合は、次の二つを分けて更新する。

1. `.zshrc.private.example`へ、値を伏せたコメント例を追加する。
2. 各ホストの`~/.zshrc.private`へ、実際の値を手動で追加する。

秘密ではなく、v101からv108で共通に使う設定はprivateへ重複して書かない。
その場合は、Git管理される`hosts/lab-server.zsh`や他のZshモジュールへ追加すると、通常のマージで全ホストへ配布できる。

## 設定ファイル別の再読み込み

更新したファイルによって、現在のセッションへ反映するコマンドが異なる。

| 変更対象 | 反映方法 |
| --- | --- |
| `.zshrc`、`.zshenv`、`.config/zsh/` | `exec zsh` |
| `.zprofile` | `exec zsh -l` |
| `.config/sheldon/plugins.toml` | `sheldon lock`の後に`exec zsh` |
| Starship、Sheldon本体 | 公式cloneをpullして`cargo build --release --locked` |
| `.tmux.conf` | `tmux source-file ~/.tmux.conf` |
| `.config/kitty/kitty.conf` | macOS側のKittyで`Ctrl-Shift-F5` |
| 新しい配布対象、欠けたリンク | `./deploy.sh` |

## Kittyとtmuxを同時に使う場合

KittyはmacOS側でキーを処理し、tmuxはターミナル内へ送られた`Ctrl-q`から始まるキーを処理する。
Kittyの`⌘D`はKittyのペインを増やし、tmuxの`Ctrl-q`、`|`は現在のtmuxセッション内だけを分割する。

SSH接続を再利用したい場合や処理を接続後も残したい場合はtmuxを使う。
独立したローカルシェルを素早く並べたい場合はKittyのペインを使う。

## 参照

- [Kittyの既定ショートカット](https://sw.kovidgoyal.net/kitty/overview/)
- [Kittyの設定](https://sw.kovidgoyal.net/kitty/conf/)
- [Starship公式ソース](https://github.com/starship/starship)
- [Sheldon公式ソース](https://github.com/rossmacarthur/sheldon)
- [Sheldonのソースビルド手順](https://sheldon.cli.rs/Installation.html#building-from-source)
