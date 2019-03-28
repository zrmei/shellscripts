RRequire base.public base.private

if [ -f /etc/os-release ]; then
    . /etc/os-release
fi

function IsDebian() {
    if cat /etc/issue /etc/*-release | grep -Eqi "(Debian|Ubuntu)"; then
        return $RAY_RET_SUCCESS
    fi

    return $RAY_RET_FAILED
}

function IsRedHat() {
    if cat /etc/issue /etc/*-release | grep -Eqi "(CentOS|Red Hat Enterprise Linux Server)"; then
        return $RAY_RET_SUCCESS
    fi

    return $RAY_RET_FAILED
}

#@param number version 5,6,7
function CheckCentOSVersion() {
    if [[ $# -eq 0 ]]; then
        ray_echo_Red "no enough arguments in ${FUNCNAME[0]}"
        exit $RAY_RET_FAILED
    fi

    if ! IsRedHat; then
        return $RAY_RET_FAILED
    fi

    local RHEL_Ver=0
    if grep -Eqi "release 5." /etc/redhat-release; then
        RHEL_Ver=5
        elif grep -Eqi "release 6." /etc/redhat-release; then
        RHEL_Ver=6
        elif grep -Eqi "release 7." /etc/redhat-release; then
        RHEL_Ver=7
    fi

    local operator=-eq
    local version=$1
    if [[ $# -eq 2 ]]; then
        operator=$1
        version=$2
    fi

    if [ $RHEL_Ver $operator $version ]; then
        return $RAY_RET_SUCCESS
    fi

    return $RAY_RET_FAILED
}

function AddSudoPremission() {
    if [[ $# -eq 0 ]]; then
        ray_echo_Red "no enough arguments in ${FUNCNAME[0]}"
        return $RAY_RET_FAILED
    fi

    $RAY_SUDO chmod u+w /etc/sudoers
    for user in $@; do
        $RAY_SUDO sed -i -e "\$a$user\tALL=(ALL:ALL)\tNOPASSWD: ALL" /etc/sudoers
    done
    $RAY_SUDO chmod u-w /etc/sudoers

    return $RAY_RET_SUCCESS
}

function addFirewallPort() {
    if [[ $# -eq 0 ]] || ! isNumber $1; then
        ray_echo_Red "no enough arguments in ${FUNCNAME[0]} or $1 is not number"
        return $RAY_RET_FAILED
    fi

    local ECHO=ray_printStatusOkBlue

    if IsDebian; then
        if IsCommandExists ufw && IsServiceActive ufw; then
            if $RAY_SUDO ufw status | grep -Eq "(^$1/tcp)|( $1/tcp)"; then
                :
            else
                ray_none_output $RAY_SUDO ufw allow $1/tcp 
                ray_none_output $RAY_SUDO ufw reload
            fi

            if $RAY_SUDO ufw status | grep -Eq "(^$1/tcp)|( $1/tcp)"; then
                ECHO=ray_printStatusOk
            else
                ECHO=ray_printStatusFailed
            fi
        else
            ray_printStatusWarn "service ufw is not running..."
            return $RAY_RET_FAILED
        fi
    elif IsRedHat; then
        if CheckCentOSVersion -ge 7; then
            if IsCommandExists firewall-cmd && IsServiceActive firewalld; then
                ray_none_output $RAY_SUDO firewall-cmd --permanent --zone=public --add-port=$1/tcp
                ray_none_output $RAY_SUDO firewall-cmd --reload

                if $RAY_SUDO firewall-cmd --zone=public --list-ports | grep -Eq "(^$1/tcp)|( $1/tcp)"; then
                    ECHO=ray_printStatusOk
                else
                    ECHO=ray_printStatusFailed
                fi
            else
                ray_printStatusWarn "service firewalld is not running..."
            fi
        else
            if IsCommandExists iptables; then
                ray_none_output $RAY_SUDO iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport $1 -j ACCEPT
                ray_none_output $RAY_SUDO /etc/init.d/iptables save
                ray_none_output $RAY_SUDO service iptables reload
            else
                ray_printStatusWarn "service iptables is not running..."
                return $RAY_RET_FAILED
            fi
        fi
    fi

    $ECHO "set firewall allow $1"

    return $RAY_RET_SUCCESS
}

function AddFirewallPorts() {
    if [[ "$1" = "-h" || "$1" = "--help" ]]; then
        echo "$0 port1 port2 port3 ...";
        return $RAY_RET_SUCCESS
    fi

    for port in $@; do
        if ! addFirewallPort $port; then
            return $RAY_RET_FAILED
        fi
    done

    return $RAY_RET_SUCCESS
}

function InstallApps() {
    local INSTALL_ONLINE
    local INSTALLED_TEST
    local INSTALL_OFFLINE

    if IsDebian; then
        INSTALL_ONLINE="apt-get install -y"
        INSTALL_OFFLINE="dpkg -i -f"
        INSTALLED_TEST="dpkg -s"
    elif IsRedHat; then
        INSTALL_ONLINE="yum install -y"
        INSTALL_OFFLINE="yum -y --nogpgcheck localinstall"
        INSTALLED_TEST="rpm -qa | grep"
    fi

    for app in $@; do
        if [[ $app =~ .*?(\.deb|\.rpm)$ && -f $app ]]; then
            eval "$RAY_SUDO $INSTALL_OFFLINE $app"
        else
            eval "$RAY_SUDO $INSTALL_ONLINE  $app"
        fi

        if ! eval "$INSTALLED_TEST $app"; then
            return $RAY_RET_FAILED
        fi
    done

    return $RAY_RET_SUCCESS
}

function RemoveFilesBeforeWeek() {
    local find_dir=${1:-.}

    if ! IsDir "$find_dir"; then
        return $RAY_RET_FAILED
    fi

    for file in `find $find_dir -ctime +7 | sort -r`; do
        $RAY_SUDO rm -rf $file
    done
}

function ChangeHostName() {
    local oldName="$(hostname)"
    local Name=$1
    $RAY_SUDO hostname $Name

    if IsFile /etc/hostname; then
        $RAY_SUDO bash -c "sed -i 's/$oldName/$Name/g' /etc/hostname;"
    fi
    if IsFile /etc/hosts; then
        $RAY_SUDO bash -c "sed -i 's/$oldName/$Name/g' /etc/hosts;"
    fi
}

function UpdateDateTime() {
    $RAY_SUDO ntpdate time.nist.gov
}

function TimeWaitOptimize() {
    if cat /etc/sysctl.conf | grep -q "#Time_Wait_Optimize"; then
        return $RAY_RET_SUCCESS
    fi

	$RAY_SUDO bash -c 'cat >>/etc/sysctl.conf<<EOF
#Time_Wait_Optimize
fs.file-max = 65535

net.core.netdev_max_backlog = 32768
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.somaxconn = 32768
net.core.wmem_default = 8388608
net.core.wmem_max = 16777216

net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30 
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 80000
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_sack = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_wmem = 4096 87380 16777216

net.netfilter.nf_conntrack_tcp_timeout_established = 120
net.nf_conntrack_max = 65536

vm.overcommit_memory = 1
EOF
'
	$RAY_SUDO /sbin/sysctl -p 2>&1 >/dev/null
}

function CheckTCPStatus() {
    netstat -n | awk '/^tcp/ {++S[$NF]} END {for(a in S) printf "%-11s %d\n", a, S[a]}'
}

function FindFileGreaterthan() {
    if IsEmpty $1 || isNumber "$1"; then
        $RAY_SUDO find / -size +${1:-50}M -type f -printf "%15s\t%p\n" 2>/dev/null | sort -n -r | less
    fi
}

function SetupBanner() {
    if IsDebian; then
        $RAY_SUDO rm -f /etc/update-motd.d/*
        $RAY_SUDO bash -c "cat >/etc/update-motd.d/10-help-text<<EOF
#!/bin/bash
cat $RAY_SCRIP_FILE_PATH/extras/ssh_banner
EOF";
        $RAY_SUDO chmod +x /etc/update-motd.d/10-help-text
    else
        if grep -q '#my_ssh_banner' /etc/ssh/sshd_config; then
            return $RAY_RET_SUCCESS
        fi

        $RAY_SUDO bash -c "cat >>/etc/ssh/sshd_config<<EOF
#my_ssh_banner
Banner $RAY_SCRIP_FILE_PATH/extras/ssh_banner
EOF"
    fi
    $RAY_SUDO service sshd reload
}

function BuildDeployKey() {
local args=( "$@" )

while [ "$#" -gt 0 ]; do
    case "$1" in
        -f) local out_file="$2"; shift 2;;
        -C) local comment="$2"; shift 2;;

        --out-file=*) local out_file="${1#*=}"; shift 1;;
        --comment=*) local comment="${1#*=}"; shift 1;;

        --help) cat <<EOF
useage: BuildDeployKey [option] [args...]

options:
    -C,--comment   
    -f,--out-file
    --help
EOF;
            exit 0;;
        -*) echo "unknown option: $1\n"; exit 1;;
    esac
done

    local name=${comment:-"$(hostname)gh.com"}
    local key_file=${out_file:-$HOME/.ssh/id_rsa}
    echo "file path: ${key_file}"
    ssh-keygen -t rsa -q -C "$name" -f "${key_file}" -N ""
}

function FastGithub() {
    if ! grep -q "#github" /etc/hosts; then
    $RAY_SUDO bash -c '
cat >>/etc/hosts<<EOF
#github
13.229.188.59   github.com
13.250.177.223  github.com
151.101.196.133 assets-cdn.github.com
151.101.24.133  assets-cdn.github.com
151.101.77.194  github.global.ssl.fastly.net
151.101.229.194 github.global.ssl.fastly.net
185.31.16.1185  github.global.ssl.fastly.net
74.125.237.1    dl-ssl.google.com
173.194.127.200 groups.google.com
192.30.252.131  github.com
185.31.16.185   github.global.ssl.fastly.net
74.125.128.95   ajax.googleleapis.com
EOF
'
    fi
}