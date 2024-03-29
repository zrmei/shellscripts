function ss() {
	if IsCommandExists systemctl; then
    	$RAY_SUDO systemctl start "$@" || return 1
	else
		$RAY_SUDO service "$@" start || return 1
	fi
}

function sl() {
	if IsCommandExists systemctl; then
    	$RAY_SUDO systemctl daemon-reload
		if [ $# -gt 0 ]; then
			$RAY_SUDO systemctl reload "$1" || return 1
		fi
	else
		$RAY_SUDO service "$1" reload || return 1
	fi
}

function sr() {
	if IsCommandExists systemctl; then
    	$RAY_SUDO systemctl daemon-reload
		if [ $# -gt 0 ]; then
			$RAY_SUDO systemctl restart "$1" || return 1
		fi
	else
		$RAY_SUDO service "$1" restart || return 1
	fi
}

function sp() {
	if IsCommandExists systemctl; then
    	$RAY_SUDO systemctl stop "$@" || return 1
	else
		$RAY_SUDO service "$@" stop || return 1
	fi
}

function st() {
	if IsCommandExists systemctl; then
		$RAY_SUDO systemctl status "$1" || return 1
	else
		$RAY_SUDO service "$1" status || return 1
	fi
}

function jo() {
	if IsCommandExists journalctl; then
    	$RAY_SUDO journalctl -f -u "$@" || return 1
	fi
}

function lnmctl() {
    local ssudo
    if ! HasRootPremission; then
        ssudo=sudo
    fi

	if [ "$1" = "nginx" ]; then
		if ! $ssudo nginx -t; then
			return $?
		fi
	fi

    $ssudo lnmp "$@"
}

function wwwroot() {
    cd $LNMP_DOC_ROOT_PATH/$1 2>/dev/null || return 1
}

function wwwlogs() {
    cd $LNMP_LOG_ROOT_PATH  2>/dev/null || return 1
}

function locateip() {
	local ip=$1
	curl "http://www.ip138.com/ips138.asp?ip=$ip&action=2" \
	   -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' \
	   -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36' \
	   -H 'DNT: 1' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' \
	   -H 'Accept-Encoding: gzip, deflate' -H 'Accept-Language: en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7' \
	   --compressed 2>/dev/null | \
	   iconv -f gbk -t utf-8 | \
	   grep -oP '(?<=<ul class="ul1"><li>).*?(?=</li></ul>)' | \
	   sed  's#</li><li>#\n#g'
 }

function mypublicip() {
	curl 'http://2018.ip138.com/ic.asp' \
		-H 'Connection: keep-alive' -H 'Cache-Control: max-age=0'  -H 'Upgrade-Insecure-Requests: 1' \
		-H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36' \
		-H 'DNT: 1' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' \
		-H 'Accept-Encoding: gzip, deflate' -H 'Accept-Language: en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7' \
		--compressed 2>/dev/null | \
		iconv -f gbk -t utf-8 | \
		grep -oP "(?<=<center>).*?(?=</center>)" | \
		tr ' ' '\n'
}

function mypublicip2() {
	curl ifconfig.me 2>/dev/null | xargs echo
}

function findFastMirror() {
     curl -s http://mirrors.ubuntu.com/mirrors.txt | \
     xargs -n1 -I {} sh -c 'echo `curl -r 0-102400 -s -w %{speed_download} -o /dev/null {}/ls-lR.gz` {}' | \
     sort -g -r | head -1 | awk '{ print $2  }'
 }
