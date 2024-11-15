# # 初回は実行権限の付与が必要
# chmod +x deploy.sh

# # スクリプトを実行しシンボリックリンクを一気に作成する
# ./deploy.sh

for files in $(ls -A | grep -vE '\.git$|\.gitignore$|deploy.sh$|zsh$|README.md$|.DS_Store$');
do
    if (test -f $HOME/$files); then
        echo "File $files already exists in $HOME. Do you want to overwrite it? (y/n)"
        read answer
        if [ "$answer" != "${answer#[Yy]}" ] ;then
            mv $HOME/$files $HOME/$files.bak
            ln -sf $PWD/$files $HOME/$files
        fi
    else
        ln -s $PWD/$files $HOME/$files
    fi
done
