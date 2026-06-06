export PATH="/opt/local/libexec/gnubin:/usr/local/bin:/opt/local/bin:/opt/local/sbin:/usr/local/lib:/usr/sbin:$PATH"
if [[ "$(hostname)" == "v102" ]]; then
    export PATH="/usr/local/cuda/bin:$PATH"
fi
# ユーザがローカルにインストールしたコマンド（uv, pipxなど）
export PATH="$HOME/.local/bin:$PATH"

# UTF-8 locale fallback for terminals that start zsh with LANG/LC_CTYPE unset.
_dotfiles_locale_available() {
    local locale_name="$1"
    command -v locale >/dev/null 2>&1 || return 1
    locale -a 2>/dev/null | command grep -Fqi -- "$locale_name" && return 0

    case "$locale_name" in
        C.UTF-8)
            locale -a 2>/dev/null | command grep -Eqi '^C\.UTF-?8$'
            ;;
        en_US.UTF-8)
            locale -a 2>/dev/null | command grep -Eqi '^en_US\.(UTF-8|utf8)$'
            ;;
        ja_JP.UTF-8)
            locale -a 2>/dev/null | command grep -Eqi '^ja_JP\.(UTF-8|utf8)$'
            ;;
        *)
            return 1
            ;;
    esac
}

_dotfiles_utf8_locale() {
    if _dotfiles_locale_available C.UTF-8; then
        print -r -- C.UTF-8
    elif _dotfiles_locale_available en_US.UTF-8; then
        print -r -- en_US.UTF-8
    elif _dotfiles_locale_available ja_JP.UTF-8; then
        print -r -- ja_JP.UTF-8
    else
        print -r -- C.UTF-8
    fi
}

if [[ -z "${LANG:-}" || "$LANG" == "C" || "$LANG" == "POSIX" ]] || ! _dotfiles_locale_available "$LANG"; then
    export LANG="$(_dotfiles_utf8_locale)"
fi

if [[ -z "${LC_CTYPE:-}" || "$LC_CTYPE" == "C" || "$LC_CTYPE" == "POSIX" ]] || ! _dotfiles_locale_available "$LC_CTYPE"; then
    export LC_CTYPE="$LANG"
fi

if [[ "${LC_ALL:-}" == "C" || "$LC_ALL" == "POSIX" ]] || { [[ -n "${LC_ALL:-}" ]] && ! _dotfiles_locale_available "$LC_ALL"; }; then
    export LC_ALL="$LANG"
fi

unset -f _dotfiles_locale_available _dotfiles_utf8_locale
