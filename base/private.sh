RRequire base.defines

# print a color text out to stdin
function ray_color_Text() {
  echo -e " \e[0;$2m$1\e[0m"
}

function ray_echo_Red() {
  echo $2 $(ray_color_Text "$1" "31") 1>&2
}

function ray_echo_Green() {
  echo $2 $(ray_color_Text "$1" "32")
}

function ray_echo_Yellow() {
  echo $2 $(ray_color_Text "$1" "33")
}

function ray_echo_Blue() {
  echo $2 $(ray_color_Text "$1" "34")
}

function ray_printStatusStart() {
    ray_echo_Green '[+] ' -n; printf "%-59s" "$1";
}

function ray_printStatusOk() {
    printf "%-59s" "$1"; echo -n "[  "; ray_echo_Green "OK" -n; echo "  ]"
}

function ray_printStatusOkBlue() {
    printf "%-59s" "$1"; echo -n "[  "; ray_echo_Blue "OK" -n; echo "  ]"
}

function ray_printStatusWarn() {
    printf "%-59s" "$1"; echo -n "[ "; ray_echo_Yellow "WARN" -n; echo " ]"
}

function ray_printStatusFailed() {
    printf "%-59s" "$1" 1>&2; echo -n "[" 1>&2; ray_echo_Red "FAILED" -n; echo "]" 1>&2
}

function ray_none_output() {
    if [ ! -z "$STD_OUTPUT" ]; then
        $@
        return $?
    else
        RAY_LOG_FILE=${RAY_LOG_FILE:=`date +"ray_none_output-%F.log"`}
        $@ >>/tmp/$RAY_LOG_FILE 2>&1
        return $?
    fi
}