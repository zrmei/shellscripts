RRequire base.public base.private functions.os

function CreateGitProject() {
    local project_name=$1

    if IsEmpty $project_name; then
        echo "useage: $0 [project_name]"
        return $RAY_RET_FAILED
    fi

    if ! cat /etc/passwd | grep -q ^git; then
        $RAY_SUDO useradd git
        AddSudoPremission git
        $RAY_SUDO mkdir /home/git
        $RAY_SUDO chown git:git /home/git
        $RAY_SUDO chmod 755 /home/git
        $RAY_SUDO chsh -s "$(command -v git-shell)" git
        local Password_default=`MakePassword 30`
        echo "git:$Password_default" | $RAY_SUDO chpasswd

        echo "passwd for git: $Password_default"

        if IsDir /usr/share/git-core/templates/hooks; then
            $RAY_SUDO cp -f $RAY_SCRIP_FILE_PATH/extras/post-receive /usr/share/git-core/templates/hooks/post-receive
            $RAY_SUDO chmod +x /usr/share/git-core/templates/hooks/post-receive
        fi
    fi

    local curDir=$(pwd)
    local prjDir=/home/git/$project_name.git
    $RAY_SUDO mkdir $prjDir
    $RAY_SUDO chmod 777 $prjDir
    
    cd $prjDir
    if  IsSameStr "$(pwd)" "$prjDir"; then 
        ray_none_output $RAY_SUDO git init --bare
    fi
    cd $curDir

    $RAY_SUDO chown -R git:git $prjDir
    $RAY_SUDO chmod 755 $prjDir
}

function VimGitPostReceive() {
    if ! IsEmpty $1; then
        if IsDir /home/git/$1.git; then
            $RAY_SUDO $RAY_EDIT /home/git/$1.git/hooks/post-receive
            ray_printStatusOk "update /home/git/$1.git success..."
            return $RAY_RET_SUCCESS
        fi
    fi

    local file_path
    if IsFile /usr/share/git-core/templates/hooks/post-receive; then
        file_path=/usr/share/git-core/templates/hooks/post-receive
    else
        $RAY_SUDO cp -f $RAY_SCRIP_FILE_PATH/extras/post-receive /tmp/post-receive
        file_path=/tmp/post-receive
    fi

    # $RAY_SUDO cat $file_path >/dev/null
    $RAY_SUDO $RAY_EDIT $file_path

    if ! IsDir /home/git; then
        return $RAY_RET_FAILED
    fi

    local modify_time=$(stat -c %Y $file_path)
    local base_time=$(date +%s)

    if [ $[ $base_time - $modify_time ] -gt 30 ]; then
        echo "file is not changed..."
        return $RAY_RET_SUCCESS
    fi

    for dir in `$RAY_SUDO find /home/git -name "*.git"`; do
        if ! ConformInfo "update post-receive in $dir ?"; then
            continue
        fi

        $RAY_SUDO cp -f $file_path $dir/hooks/post-receive
        $RAY_SUDO chmod +x  $dir/hooks/post-receive
        $RAY_SUDO chown git:git $dir/hooks/post-receive

        ray_printStatusOk "update $dir success..."
    done

    return $RAY_RET_SUCCESS
}


function changeGitUserEmail() {
cat <<EOF
git filter-branch --env-filter '
OLD_EMAIL="^_^@^_^.com"
CORRECT_NAME="Ray"
CORRECT_EMAIL="xiaosu@gmail.com"
if [ "\$GIT_COMMITTER_EMAIL" = "\$OLD_EMAIL" ]
then
    export GIT_COMMITTER_NAME="\$CORRECT_NAME"
    export GIT_COMMITTER_EMAIL="\$CORRECT_EMAIL"
fi
if [ "\$GIT_AUTHOR_EMAIL" = "\$OLD_EMAIL" ]
then
    export GIT_AUTHOR_NAME="\$CORRECT_NAME"
    export GIT_AUTHOR_EMAIL="\$CORRECT_EMAIL"
fi
' --tag-name-filter cat -- --branches --tags
EOF
}

function CompressGitData() {
    $RAY_SUDO git reflog expire --all --expire=now
    $RAY_SUDO git gc --prune=now --aggressive
}

function RemoveAllGitConmmitLog() {
    #Checkout
    $RAY_SUDO git checkout --orphan latest_branch
    #Add all the files
    $RAY_SUDO git add -A
    #Commit the changes
    $RAY_SUDO git commit -am "${1:-'commit message'}"
    #Delete the branch
    $RAY_SUDO git branch -D master
    #Rename the current branch to master
    $RAY_SUDO git branch -m master
    #Finally, force update your repository
    $RAY_SUDO git push -f origin master

    CompressGitData
}