RAY_SCRIP_FILE_PATH="$(dirname "$(readlink -f "$0")")"

function RRequire() {
    for module in $@; do
        local file=${module//./\/}
        if [ ! -f $RAY_SCRIP_FILE_PATH/$file.sh ]; then
            return 1
        fi

        if [[ "$RAY_IMPORTED" = *"$module"* || "$RAY_IMPORTED" = "all" ]]; then
            continue
        fi

        RAY_IMPORTED="$RAY_IMPORTED $module"

        . $RAY_SCRIP_FILE_PATH/$file.sh
    done

    return 0
}

if [ "$1" = "all" ]; then
    for file in `find $RAY_SCRIP_FILE_PATH  -mindepth 2 -name "*.sh"`; do
        . $file
    done
    RAY_IMPORTED="all"
fi

function ShowFunctions() {
    local width=`tput cols`
    local step=`expr $width / 25`

    local my_type='A-Z'
    if [ "$1" = "all" ]; then
        my_type='A-Za-z'
    fi

    for file in `find $RAY_SCRIP_FILE_PATH/functions -name "*.sh" -print | sort`; do
        local num=1
        local name=$file
        name=${name//$RAY_SCRIP_FILE_PATH\//}
        name=${name//.sh/}
        name=${name//\//.}

        echo "$name:"
        for func in `cat $file | grep -Eo " [$my_type](.*?)\(\) " | tr -d '()' | sort`; do
            printf "%-22s" $func
            if (( $num % $step )); then
                echo -n "\t"
            else
                echo -n "\n"
            fi
            num=`expr $num + 1`
        done

        echo "\n"
    done
}


function UpdateRayFunctions() {
    local curPath=$(pwd)

    cd $RAY_SCRIP_FILE_PATH || return $RAY_RET_FAILED

    $RAY_SUDO git fetch --all
    $RAY_SUDO git reset --hard origin/master >/dev/null 2>&1
    $RAY_SUDO git pull

    . $RAY_SCRIP_FILE_PATH/functions.sh all

    cd $curPath
}

function RunExtraScript() {
    local script_name=$1
    shift

    if [ -f $RAY_SCRIP_FILE_PATH/extras/$script_name ]; then
        zsh $RAY_SCRIP_FILE_PATH/extras/$script_name "$@"
    else
        return -1
    fi
}
