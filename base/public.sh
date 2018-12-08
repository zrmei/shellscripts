RRequire base.defines base.private

#######################################
# test a arg is a empty str
# eg: IsEmpty ''
#
#######################################
function IsEmpty() {
    if [ -z "$1" ]; then
        return $RAY_RET_SUCCESS
    fi

    return $RAY_RET_FAILED
}

#######################################
# test a arg is a empty str
# eg: IsEmpty ''
#######################################
function IsSameStr() {
    if [ "$1" = "$2" ]; then
        return $RAY_RET_SUCCESS
    fi

    return $RAY_RET_FAILED
}

function HasRootPremission() {
    if [ "$(id -u)" != "0" ]; then
        return $RAY_RET_FAILED
    fi

    return $RAY_RET_SUCCESS
}

if ! HasRootPremission; then
    RAY_SUDO=sudo
fi

#######################################
# test if a commond is existed
# eg: IsCommandExists git
# if the command git is not exited,
# then it will return not 0 value
#######################################
function IsCommandExists() {
    local CMDS
    for cmd in "$@"; do
        if ! type $cmd >/dev/null 2>&1; then
            CMDS="$CMDS $cmd"
        fi
    done

    if [ ! -z "$CMDS" ]; then
        return $RAY_RET_FAILED
    fi

    return $RAY_RET_SUCCESS
}

if IsCommandExists vim; then
    RAY_EDIT=vim
    elif IsCommandExists vi; then
    RAY_EDIT=vi
    elif IsCommandExists nano; then
    RAY_EDIT=nano
fi

function IsDir() {
    if [ -d $1 ]; then
        return $RAY_RET_SUCCESS
    fi

    return $RAY_RET_FAILED
}

function IsFile() {
    if [ -f $1 ]; then
        return $RAY_RET_SUCCESS
    fi

    return $RAY_RET_FAILED
}

#######################################
# create a dir with owner is cur user
# eg: CreateDir /tmp/haha
#######################################
function CreateDir() {
    if ! IsDir $1; then
        $RAY_SUDO mkdir -p $1
        $RAY_SUDO chown `whoami`:`whoami` $1
    fi

    IsDir $1
    return $?
}

function CreateFile() {
    if ! IsFile $1; then
        $RAY_SUDO mkdir -p $(dirname $1)
        $RAY_SUDO touch $1
        $RAY_SUDO chown `whoami`:`whoami` $1
    fi

    IsFile $1
    return $?
}

#######################################
# make a random str
# @param width default is 30
#######################################
function MakePassword() {
    local width=30

    if ! IsEmpty $1; then
        width=$1
    fi

    cat /dev/urandom | tr -dc 'a-zA-Z0-9/\-=[];,._+{}:<>@%^&*()' | fold -w $width | head -n 1
}

#######################################
# Only used in zsh
# @param string tip
#######################################
function ConformInfo() {
    local options="[Y/N]"
    local choice

    read "choice?$1 [Y/N] Y:"

    if [[ $choice:u = "Y" ]] || IsEmpty $choice; then
        return $RAY_RET_SUCCESS
    fi

    return $RAY_RET_FAILED
}

function IsZsh() {
    if [[ `ps -p $$ -oargs=` =~ "zsh" ]]; then
        return $RAY_RET_SUCCESS
    fi

    return $RAY_RET_FAILED
}

function FindInDir() {
    local findpath
    local params
    local print_help

    while [ $# -gt 0 ]; do
        case "$1" in
            -d) findpath="$2"; shift 2;;
            --dir=*) findpath="${1#*=}"; shift 1;;
            -r) params="$2"; shift 2 ;;
            --regex=*) params="${1#*=}"; shift 1;;

            --help) print_help=true; break ;;

            -*) ray_echo_Red "unknown option: $1"; return $RAY_RET_FAILED;;
            *)
                if IsEmpty $findpath; then
                    findpath="$1"
                    elif IsEmpty $params; then
                    params="$1"
                fi

                shift 1
            ;;
        esac
    done

    if IsSameStr $print_help "true"; then
    cat <<EOF
better than default find:
    -d, --dir       setup dir where to search
    -r, --regex     setup find regex

    --help          show this help
EOF
        return $RAY_RET_SUCCESS
    fi

    find $findpath -regextype "posix-extended" -regex ".*/$params"
}

function ssh_tunnel() {
    local port host user dist_host print_help

    while [ $# -gt 0 ]; do
        case "$1" in
            -p) port="$2"; shift 2;;
            --port=*) port="${1#*=}"; shift 1;;

            -h) host="$2"; shift 2;;
            --host=*) host="${1#*=}"; shift 1 ;;

            -u) user="$2"; shift 2;;
            --user=*) user="${1#*=}"; shift 1 ;;

            -d) dist_host="$2"; shift 2;;
            --dist-host=*) dist_host="${1#*=}"; shift 1 ;;

            --help) print_help=true; break ;;

            -*) ray_echo_Red "unknown option: $1"; return $RAY_RET_FAILED;;
            *)
                if IsEmpty $port; then
                    port="$1";
                    elif IsEmpty $host; then
                    host="$1"
                    elif IsEmpty $user; then
                    user="$1"
                fi

                shift 1
            ;;
        esac
    done

    if IsSameStr $print_help "true"; then
    cat <<EOF
useage: $0 [args...]
    -p, --port      setup remote port
    -h, --host      setup proxy host, ip or hosts
                    are configured in /etc/ssh/ssh_config
    -d, --dist-host setup remote host, default is 127.0.0.1

    --help          show this help
EOF
        return $RAY_RET_SUCCESS
    fi

    local lower_port=1025
    local upper_port=60000
    local used_port=$(netstat -lnt | awk '{print $4}' | cut -d: -f2| tr "\t\r\n" " ")

    for (( local_port = lower_port ; local_port <= upper_port ; local_port++ )); do
        if ! echo $used_port | grep -qE "\W$local_port\W"; then break; fi
    done

    if ! IsEmpty $user; then
        local op=-l
    fi

    echo "shh tunnel start on local $local_port  ..."
    ssh -N -L $local_port:${dist_host:-127.0.0.1}:$port $host $op $user
}

function isNumber() {
    if ! [[ $1 =~ ^[0-9]+$ ]] ; then
        return $RAY_RET_FAILED
    fi

    return $RAY_RET_SUCCESS
}

function ShowHosts() {
    if IsFile /etc/ssh/ssh_config; then
        grep -Pi 'host(name)? (?!\*)' /etc/ssh/ssh_config | awk '{printf "%-20s", $2; getline; print $2;}'
    fi
}