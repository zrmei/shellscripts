RRequire base.public base.private functions.os

function mkTemplateVHost() {

    local plugin=thinkphp

    if [ "$4" = "yii" -o "$4" = "yii2" ]; then
        plugin=yii2
    else
        plugin=$4
    fi

    if ! IsEmpty $plugin; then
        plugin="include rewrite/$plugin.conf;";

    else
        plugin=<<EOF

    location / {
        try_files \$uri \$uri/ index.php\$request_uri;
    }
EOF
    fi

    $RAY_SUDO touch $1
    $RAY_SUDO chown `whoami`:`whoami` $1
    cat > $1 <<EOF
map \$sent_http_content_type \$expires {
    default                    off;
    text/html                  epoch;
    text/css                   max;
    application/javascript     max;
    ~image/                    max;
}

#upstream backend {
#    server backend1.example.com       weight=5;
#    server backend2.example.com:8080;
#    server unix:/tmp/backend3;
#}

server {
    listen $3;
    index index.html index.htm index.php;
    root /home/wwwroot/$2;
    server_name _;

    expires \$expires;

    include enable-php.conf;
    $plugin

    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    fastcgi_hide_header X-Powered-By;
    add_header X-Powered-By PHP/5.2.16;

    #add_header strict-transport-security: max-age=16070400; includeSubDomains;

    location = /github/postreceive {
        proxy_set_header Host            \$host;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_pass http://127.0.0.1:17293;
    }

    #location @backend_server {
    #    fastcgi_connect_timeout     60s;
    #    fastcgi_read_timeout        60s;
    #    fastcgi_send_timeout        60s;
    #    fastcgi_ignore_client_abort on;
    #    fastcgi_param  HTTP_REFERER     \$http_referer;
    #
    #    proxy_set_header Host            \$http_host;
    #    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    #    proxy_set_header X-Real-IP       \$remote_addr;
    #    proxy_set_header User-Agent      \$http_user_agent;
    #    proxy_pass http://backend;
    #}

    location ~* \\.(eot|otf|ttf|woff|woff2)$ {
        expires max;
        add_header Access-Control-Allow-Origin *;
        access_log  off;
    }

    location ~ /.well-known {
        allow all;
    }

    location ~ /\\. {
        deny all;
    }

    #location ~* \\.(gif|jpg|jepg|png|bmp)$ {
    #    valid_referers none blocked;
    #    if (\$invalid_referer) {
    #        return 403;
    #    }
    #}

    access_log  /home/wwwlogs/access.$2.log;
    error_log   /home/wwwlogs/error.$2.log  error;
}
EOF
    $RAY_SUDO chmod 644 $1
    $RAY_SUDO chown root:root $1
}

function ResetMysqlPassword() {
    if ! IsCommandExists lnmp; then
        ray_echo_Red "this only for mysql instaled by lnmp"
        return $RAY_RET_FAILED
    fi

    if [ -s /usr/local/mariadb/bin/mysql ]; then
        DB_Name="mariadb"
        DB_Ver=`/usr/local/mariadb/bin/mysql_config --version`
        elif [ -s /usr/local/mysql/bin/mysql ]; then
        DB_Name="mysql"
        DB_Ver=`/usr/local/mysql/bin/mysql_config --version`
    else
        echo "MySQL/MariaDB not found!"
        return $RAY_RET_FAILED
    fi

    while :;do
        DB_Root_Password=""
        read -r "DB_Root_Password?Enter New ${DB_Name} root password: "
        if [ "${DB_Root_Password}" = "" ]; then
            echo "Error: Password can't be NULL!!"
        else
            break
        fi
    done

    echo "Stoping ${DB_Name}..."
    $RAY_SUDO /etc/init.d/${DB_Name} stop
    echo "Starting ${DB_Name} with skip grant tables"
    $RAY_SUDO /usr/local/${DB_Name}/bin/mysqld_safe --skip-grant-tables >/dev/null 2>&1 &
    sleep 5
    echo "update ${DB_Name} root password..."
    if echo "${DB_Ver}" | grep -Eqi '^8.0.|^5.7.|^10.2.'; then
        /usr/local/${DB_Name}/bin/mysql -u root << EOF
    FLUSH PRIVILEGES;
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_Root_Password}';
EOF
    else
        /usr/local/${DB_Name}/bin/mysql -u root << EOF
    update mysql.user set password = Password('${DB_Root_Password}') where User = 'root';
EOF
    fi

    if [ $? -eq 0 ]; then
        echo "Password reset succesfully. Now killing mysqld softly"
        $RAY_SUDO killall mysqld
        sleep 5
        echo "Restarting the actual ${DB_Name} service"
        $RAY_SUDO /etc/init.d/${DB_Name} start
        echo "Password successfully reset to '${DB_Root_Password}'"
    else
        echo "Reset ${DB_Name} root password failed!"
    fi
}

function MakeDirsOwnToWeb() {
    if [ $# -eq 0 ]; then
        ray_echo_Red "please choose a dir"
        return $RAY_RET_FAILED
    fi

    local User

    if IsDebian; then
        User="www-data"
        elif IsRedHat; then
        User="www"
    fi

    local from_ps=`ps -aux  2>/dev/null | grep -v grep | grep -vE ' [SRD\+]s ' | grep php-fpm | tail -n 1 | awk '{print $1}'`

    if IsEmpty $from_ps; then
        if IsCommandExists lnmp; then
            from_ps=`cat /usr/local/php/etc/php-fpm.conf | grep  "listen.owner" | awk -F"[=#]" '{print $2}' | tr -d ' '`
        fi
    fi

    if ! IsEmpty $from_ps && ! IsEmpty "$(awk -F: '{ print $1 }' /etc/passwd | grep ^$from_ps$)"; then
        User=$from_ps;
    fi

    for dir in $@; do
        if IsDir $dir; then
            $RAY_SUDO  chown -R $User:$User $dir
            $RAY_SUDO  chmod -R 755 $dir
        else
            ray_echo_Red "$dir is not a dir!"
        fi
    done

    return $RAY_RET_SUCCESS
}


function TailAccessLog() {
    if [ $# -eq 0 ]; then
        ray_echo_Red "useage: $0 [vhost] [lines]"
        return $RAY_RET_FAILED
    fi

    if IsFile $LNMP_LOG_ROOT_PATH/access.$1.log; then
        tail -n ${2:-10} $LNMP_LOG_ROOT_PATH/access.$1.log
    fi
}

function CountAccessIP() {
    if [ $# -eq 0 ]; then
        ray_echo_Red "useage: $0 [vhost] [lines]"
        return $RAY_RET_FAILED
    fi

    if IsFile $LNMP_LOG_ROOT_PATH/access.$1.log; then
        cat $LNMP_LOG_ROOT_PATH/access.$1.log | awk '{print  $1}' | sort | uniq -c | sort -rn | head -n ${2:-10}
    fi
}

function TailErrorLog() {
    if [ $# -eq 0 ]; then
        ray_echo_Red "useage: $0 [vhost] [lines]"
        return $RAY_RET_FAILED
    fi

    if IsFile $LNMP_LOG_ROOT_PATH/error.$1.log; then
        tail -n ${2:-10} $LNMP_LOG_ROOT_PATH/error.$1.log
    fi
}

function TailErrorNginxLog() {
    if [ $# -eq 0 ]; then
        ray_echo_Red "useage: $0 [lines]"
        return $RAY_RET_FAILED
    fi

    if IsFile $LNMP_LOG_ROOT_PATH/nginx_error.log; then
        tail -n ${1:-10} $LNMP_LOG_ROOT_PATH/nginx_error.log
    fi
}

function VimVHost() {
    if [ "$1" = "-h" -o "$1" = "--help" ] || IsEmpty "$1"; then
        echo "useage: CreateVHost [filename] [port] [frame]"
        return $RAY_RET_FAILED
    fi

    local vhost_path=${NGINX_VHOST_CONF_PATH:-/usr/local/nginx/conf/vhost}

    if ! IsDir $vhost_path; then
        return $RAY_RET_FAILED
    fi

    local vhost=${vhost_path}/$1.conf

    if IsSameStr "$1" "nginx"; then
        vhost=$NGINX_NGINX_CONF_PATH
    fi

    if ! IsFile $vhost; then
        if ! ConformInfo "Are you sure to create vhost named $1?"; then
            return $RAY_RET_FAILED
        fi
        mkTemplateVHost $vhost "$@"
    fi

    $RAY_SUDO $RAY_EDIT $vhost

    return $RAY_RET_SUCCESS
}

function ListVHosts() {
    local conf
    local port
    local server_name
    local vhost_path=${NGINX_VHOST_CONF_PATH:-/usr/local/nginx/conf/vhost}

    if ! IsDir $vhost_path; then
        return $RAY_RET_FAILED
    fi

    for conf in $vhost_path/*.conf; do
        port=`cat $conf | grep 'listen' | awk '{print $2}' | tr "\n;" ' '`
        server_name=`cat $conf | grep 'server_name'  | awk '{$1=""; print $0}' | tr "\n;" ' '`
        printf "WebHost: %-20s \nport: %s \nserver_name: %s\n\n" "$(basename ${conf%.conf})" "$port" "$server_name"
    done

    return $RAY_RET_SUCCESS
}

function nginx_status() {
    wget -O- http://127.0.0.1/nginx_status 2>/dev/null
}
