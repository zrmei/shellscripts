function ss() {
    $RAY_SUDO systemctl start "$@" || return 1
}

function sr() {
    $RAY_SUDO systemctl reload "$@" || return 1
}

function sp() {
    $RAY_SUDO systemctl stop "$@" || return 1
}

function st() {
    $RAY_SUDO systemctl status "$@" || return 1
}

function lnmpctl() {
    local ssudo
    if ! HasRootPremission; then
        ssudo=sudo
    fi

    $ssudo lnmp "$@"
}

function wwwroot() {
    cd /home/wwwroot/$1 || return 1
}

function wwwlogs() {
    cd /home/wwwlogs || return 1
}

function locateip() {
    local ip=$1
     | \
        iconv -f gbk -t utf-8 | \
        grep -oP '(?<=<ul class="ul1"><li>).*?(?=</li></ul>)' | \
        sed  's#</li><li>#\n#g'
}