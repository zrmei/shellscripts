RRequire base.public base.private functions.os

function CreateGitProject() {
    local project_name=$1

    if IsEmpty $project_name; then
        echo "useage: $0 [project_name]"
        return $RAY_RET_FAILED
    fi

    if ! grep -q ^git /etc/passwd; then
        local Password_default=`MakePassword 30`
        echo -n "passwd for git: "; ray_echo_Green "$Password_default";

        $RAY_SUDO useradd  -d /home/git -s $(command -v git-shell) -m git
        AddSudoPremission git
        echo "git:$Password_default" | $RAY_SUDO chpasswd

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
    if ! ConformInfo "Do you sure to compress git data"; then
        return $RAY_RET_FAILED
    fi

    $RAY_SUDO git reflog expire --all --expire=now
    $RAY_SUDO git gc --prune=now --aggressive
}

function RemoveAllGitConmmitLog() {
    if ! ConformInfo "Do you sure to remove all commit logs";then
        return $RAY_RET_FAILED
    fi

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

    ray_printStatusOk "remove commit logs"
}

function InstallMyPublicKey() {
    if IsDir /home/git; then
        $SUDO mkdir -p /home/git/.ssh


        local key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCraBe30CqzHKbLa60qtuLZCbV6XYshMZAnqgnW3597/9gnggtCfoAhFVEKP0VyF+yWOE4TVDHNq2aYdh1PTfG35J/1N8Pm8Czr6TzVpcLEID/ZWC46g2PP5HX0/io4AiTGS+0hnBQgQEowi9ko6nuqryKwgoYXS7/YNu1Ud+KKMSFWQtSad3WIz2oIgHxPRl4Tx0SvxBc0oQYbLVr4DjK7nL25B4SVYg4YESNdbss9lm6RnzLnIquu3FeCgTupYLl+opAbGF+Qi5por7TFCZqsItl7Ztkqiny3yiAXfM3NFdMZzIXWQDIxNh1PLoaM0jmKVOiy977phoGR4Gp8fMVb ray@ray-mei"
        $SUDO bash -c " echo \"$key\" >> /home/git/.ssh/authorized_keys"
        $SUDO chown -R git:git /home/git/.ssh
        $SUDO chmod 700 /home/git/.ssh
        $SUDO chmod 644 /home/git/.ssh/authorized_keys

        ray_printStatusOk "key has been installed!"
    else
        ray_printStatusFailed "can not attach the home dir for git"
    fi
}