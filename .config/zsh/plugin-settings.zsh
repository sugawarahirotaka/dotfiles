# IME入力中の二重描画を避けるため、全角文字を含む履歴候補を除外する。
ZSH_AUTOSUGGEST_HISTORY_IGNORE='*[![:ascii:]]*'

# autosuggestionsとの組み合わせでCJK文字が二重描画されないようにする。
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[unknown-token]=default
