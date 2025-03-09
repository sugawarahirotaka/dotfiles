export PATH="/opt/local/libexec/gnubin:/usr/local/bin:/opt/local/bin:/opt/local/sbin:/usr/local/lib:/usr/sbin:$PATH"
if [[ "$(hostname)" == "v102" ]]; then
    export PATH="/usr/local/cuda/bin:$PATH"
fi
