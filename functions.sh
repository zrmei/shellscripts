RAY_SCRIP_FILE_PATH=$(dirname $(readlink -f "$0"))

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

    for file in `find $RAY_SCRIP_FILE_PATH/functions -name "*.sh" -print | sort`; do
        local num=1
        local name=$file
        name=${name//$RAY_SCRIP_FILE_PATH\//}
        name=${name//.sh/}
        name=${name//\//.}

        echo "$name:"

        for func in `cat $file | grep -Eo " [A-Za-z](.*?)\(\) " | tr -d '()' | sort`; do
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

    if IsRedHat && CheckCentOSVersion -le 6; then
        $RAY_SUDO crontab -l | { cat; echo "15 05 * * 0 /usr/bin/env bash -c \"cd $RAY_SCRIP_FILE_PATH && if ! git pull; then git fetch --all; git reset --hard origin/master; git pull; fi\""; } | uniq | $RAY_SUDO crontab -
        cd $curPath
        return $RAY_RET_SUCCESS
    fi

    if ! IsFile updateShellscripts.service; then
        $RAY_SUDO touch $RAY_SCRIP_FILE_PATH/updateShellscripts.service
        $RAY_SUDO chown $(whoami):$(whoami) $RAY_SCRIP_FILE_PATH/updateShellscripts.service

        cat > $RAY_SCRIP_FILE_PATH/updateShellscripts.service <<EOF
[Unit]
Description=update shellscripts

[Service]
WorkingDirectory=$RAY_SCRIP_FILE_PATH
ExecStart=/usr/bin/env bash -c "git fetch --all; git reset --hard origin/master; git pull;"
Type=oneshot

[Install]
WantedBy=multi-user.target
EOF

        $RAY_SUDO touch $RAY_SCRIP_FILE_PATH/updateShellscripts.timer
        $RAY_SUDO chown $(whoami):$(whoami) $RAY_SCRIP_FILE_PATH/updateShellscripts.timer

        cat > $RAY_SCRIP_FILE_PATH/updateShellscripts.timer <<EOF
[Unit]
Description=update shellscripts

[Timer]
OnCalendar=Sun, 05:15

[Install]
WantedBy=timers.target
EOF

        SystemdEnable $RAY_SCRIP_FILE_PATH/updateShellscripts.service
        SystemdEnable $RAY_SCRIP_FILE_PATH/updateShellscripts.timer

        $RAY_SUDO systemctl restart updateShellscripts.timer
    fi

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