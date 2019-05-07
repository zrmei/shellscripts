RRequire base.public

if CheckCentOSVersion -lt 7 && ! IsDebian; then
    return $RAY_RET_FAILED
fi

function SystemdEnable() {
    local service_name
    local _status
    for service in "$@"; do
        service_name=$(basename $service)
        _status=$(ray_none_output systemctl status $service_name | grep Loaded | awk '{print $2}')

        if [ "$_status" = 'loaded' ]; then
            echo -n "loaded from: "
            $RAY_SUDO systemctl status $1 | grep Loaded | awk '{print $3}' | tr -d '();'
        else
            echo "created from: $(readlink -f "$service")"
            ray_none_output $RAY_SUDO systemctl enable -f "$(readlink -f "$service")"
        fi
    done
}

function clearBrokenLinks() {
    if [ ! -d /etc/systemd/system ]; then
        return $RAY_RET_SUCCESS
    fi

    for line in `find /etc/systemd/system -type l -print | xargs -n 1 file \
                        | grep 'broken symbolic link' | awk  -F':' '{print $1}'`; do
        $RAY_SUDO rm -f $line
    done
}

function SystemdDisable() {
    local service_name
    local _status
    for service in "$@"; do
        service_name=$(basename $service)
        _status=$(systemctl status $service_name 2>/dev/null | grep Loaded | awk '{print $2}')
        if [ "$_status" = 'loaded' ]; then
            if IsServiceActive $service_name; then
                $RAY_SUDO systemctl stop $service_name
            fi

            ray_none_output $RAY_SUDO systemctl disable $service_name
        fi

        echo "remove from: $service_name"
    done

    clearBrokenLinks

    return $RAY_RET_SUCCESS
}

#active inactive
function IsServiceActive() {
    local active=$(systemctl is-active $1)

    if [ "$active" = "active" ]; then
        return $RAY_RET_SUCCESS
    else
        return $RAY_RET_FAILED
    fi
}

function ReloadSystemdUnits() {
    if ! IsZsh; then
        echo "this function use feature only in zsh"
        return $RAY_RET_FAILED
    fi

    local systemdInit="systemd-init.sh"
    local script_path="."
    local print_help="false"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -f) systemdInit="$2"; shift 2;;
            --script-name=*) systemdInit="${1#*=}"; shift 1;;
            -h|--help) print_help="true"; break ;;
            -*) ray_echo_Red "unknown option: $1"; return $RAY_RET_FAILED;;
            *)  script_path="$1"; shift 1;;
        esac
    done

    if IsSameStr "$print_help" "true"; then
        cat <<EOF
useage: $0 [options] [path]

options:
    -f,--script-name    build service(s) or timer(s) script default[systemd-init.sh]
    -h,--help           show this help

example:
    $0 <where-script-locate-path> -f <script-name>
EOF
        return $RAY_RET_SUCCESS
    fi

    if ! IsDir $script_path; then
        return $RAY_RET_FAILED
    fi

    script_path="$(readlink -f $script_path)"

    $RAY_SUDO systemctl daemon-reload
    local unit
    for unit in `FindInDir $script_path '.*?\.(service|timer)'`; do
        SystemdDisable $unit
        $RAY_SUDO rm -f $unit
    done

    local cur_path=$(pwd)
    cd "$script_path"
    $RAY_SUDO /usr/bin/env zsh $script_path/$systemdInit
    cd "$cur_path"

    for unit in `find $script_path -name "[a-z]*.service"`; do
        SystemdEnable $unit
    done

    for unit in `find $script_path -name "[A-Z]*.service"`; do
        SystemdEnable $unit
        $RAY_SUDO systemctl restart $(basename $unit)
    done

    for unit in `find $script_path -name "*.timer"`; do
        SystemdEnable $unit
        $RAY_SUDO systemctl restart $(basename $unit)
    done
}

function CreateSystemdScript() {
    local script_path="$(pwd)/systemd-init.sh"

    cat > $script_path << CAT_EOF
#!/usr/bin/env zsh

if [[ "\$(id -u)" != "0" ]]; then
    sudo \$0 \$@
    exit \$?
fi

CurPath=\$(dirname \$(readlink -f "\$0"))
WWWDir=\$(dirname \$CurPath)

cat > sample.service <<EOF
[Unit]
Description=sample

[Service]
WorkingDirectory=\$WWWDir
ExecStart=/usr/bin/env bash -c "echo 'ok'"
Type=oneshot
#BindsTo=
#Requires=

[Install]
WantedBy=multi-user.target
EOF

cat >sample.timer <<EOF
[Unit]
Description=sample

[Timer]
Unit=sample.service
OnCalendar=*:*:40
Persistent=true

[Install]
WantedBy=timers.target
EOF
CAT_EOF

    $RAY_SUDO chmod +x $script_path
}
