# dotfiles

macOSと研究室サーバーで共用する個人用dotfilesです。Zsh設定は機能別に分割し、プラグインをSheldon、プロンプトをStarshipで管理します。

構成の考え方は [nometoko/dotfiles](https://github.com/nometoko/dotfiles) を参考にしています。読み込み順は暗黙のglobにせず、`.config/zsh/init.zsh` へ明示しています。

## 主な特徴

- `.zshrc` はローダーだけにし、設定を機能別ファイルへ分割
- Sheldonで `zsh-autosuggestions` と `zsh-syntax-highlighting` を管理
- Starshipでホスト名、ディレクトリ、Git、仮想環境を1行表示
- macOS、研究室サーバー、ホスト固有設定を分離
- private設定と一部の不要なアプリ生成物をGit管理から除外
- 配布対象を許可リストで限定し、既存ファイルは確認後にバックアップ

## 主なディレクトリ構造

```text
.
├── .config/
│   ├── sheldon/
│   │   └── plugins.toml          # Zshプラグイン定義
│   ├── starship.toml             # 1行プロンプト設定
│   ├── zsh/
│   │   ├── init.zsh              # モジュールの読み込み順
│   │   ├── core.zsh              # colorsなどの基本初期化
│   │   ├── env.zsh               # 履歴・環境変数
│   │   ├── options.zsh           # setopt / unsetopt
│   │   ├── completion.zsh        # 補完とzstyle
│   │   ├── keybindings.zsh       # Ctrl-P/N、Shift-Tab
│   │   ├── aliases.zsh           # 一般エイリアス
│   │   ├── directories.zsh       # ディレクトリスタック
│   │   ├── integrations.zsh      # direnv、Kitty、ホスト設定
│   │   ├── prompt.zsh            # Starship初期化
│   │   ├── plugin-settings.zsh   # CJK向けプラグイン設定
│   │   ├── plugins.zsh           # Sheldon初期化
│   │   ├── functions/
│   │   │   ├── notification.zsh  # Slack通知
│   │   │   ├── nvidia.zsh        # GPU利用状況
│   │   │   ├── pdf.zsh           # PDF圧縮
│   │   │   └── nvim.zsh          # Neovimバックアップ・復元
│   │   └── hosts/
│   │       ├── init.zsh           # ホスト振り分け
│   │       ├── lab-server.zsh     # v101、v103〜v108共通
│   │       ├── macos.zsh          # JAVA_HOME、DISPLAY
│   │       └── oroshi1.zsh        # oroshi1固有
│   ├── kitty/                     # Kitty設定
│   ├── lf/                        # lf設定
│   └── nvim/                      # Neovim設定
├── docs/
│   ├── aliases.md                 # エイリアス一覧
│   └── usage.md                   # 利用例
├── scripts/
│   └── check-zsh.zsh              # Zsh設定のスモークテスト
├── .zshenv                        # 全Zshで必要なPATH・ロケール
├── .zprofile                      # ログインシェル用
├── .zshrc                         # private設定とinit.zshの読み込み
├── .zshrc.private.example         # private設定の見本
├── deploy.sh                      # シンボリックリンク配置
└── codex-remote-toggle.sh         # Codexリモート接続切り替え
```

## Zshの読み込み順

1. `.zshenv` でPATHとロケールを設定
2. ログインシェルでは `.zprofile` を読み込み
3. `.zshrc` が `~/.zshrc.private` を存在する場合だけ読み込み
4. `.config/zsh/init.zsh` が各モジュールを明示順で読み込み
5. Starshipを初期化
6. プラグイン事前設定を読み、Sheldonを初期化

`zsh-syntax-highlighting` が他のZLE設定より後になるよう、Sheldonは最後のプラグイン初期化として配置しています。

Starshipは「プロンプトを1行で表示」する設定です。初期化処理を `.zshrc` の1行目へ置く意味ではありません。環境変数やホスト設定を反映できるよう、各モジュールの後で初期化しています。

## セットアップ

### 1. リポジトリを取得

```zsh
git clone https://github.com/sugawarahirotaka/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2. StarshipとSheldonを導入

MacPortsではStarshipをインストールできます。

```zsh
sudo port install starship
```

SheldonはHomebrewまたはCargoの公式配布に対応しています。

```zsh
# Homebrewを使う場合
brew install sheldon

# Cargoを使い、~/.local/binへ入れる場合
cargo install sheldon --locked --root "$HOME/.local"
```

Sheldon 0.8.5はRust 1.81以上を必要とします。古いRustを使っている場合は、先に利用中のパッケージマネージャーでRust/Cargoを更新してください。

StarshipまたはSheldonが未導入でもZshは起動します。Starshipがない場合は基本プロンプトへフォールバックし、Sheldonがない場合はSheldon管理プラグインを読み込みません。

### 3. dotfilesを配置

```zsh
./deploy.sh
sheldon lock
```

既存ファイルがある場合は、バックアップして置き換えるか確認します。`~/.config` 全体ではなく、管理対象のサブディレクトリだけをリンクします。配置後の `sheldon lock` で、プラグインを初回取得します。

### 4. private設定を作成

```zsh
cp .zshrc.private.example ~/.zshrc.private
chmod 600 ~/.zshrc.private
```

Slack通知を使う場合だけ、`SLACK_WEBHOOK_URL` を設定してください。実ファイルはGit管理されません。

### 5. 新しいZshを開始

```zsh
exec zsh
```

## 検証

構文、シンボリックリンク配置、対話シェル起動、主要なエイリアスと関数、任意ツール未導入時のフォールバックを一括で確認できます。実際のprivate設定と履歴ファイルは読み書きしません。

```zsh
./scripts/check-zsh.zsh
```

## 更新

```zsh
cd ~/dotfiles
git pull
./deploy.sh
sheldon lock --update
```

## ホスト固有設定

- v101、v103〜v108: `hosts/lab-server.zsh`
- v102: `.zshenv` でCUDAのPATHを設定
- oroshi1: `hosts/oroshi1.zsh`
- macOS共通: `hosts/macos.zsh`
- その他の未管理ホスト: 互換用に `~/.zshrc.$HOST` があれば読み込み

## 詳細

- [エイリアス一覧](docs/aliases.md)
- [便利な使い方](docs/usage.md)
