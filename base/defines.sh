#function return value if success
RAY_RET_SUCCESS=0
#function return value if failed
RAY_RET_FAILED=1
#when an instance startup, all log will be send to new file
unset RAY_LOG_FILE

if [ -z "$NGINX_VHOST_CONF_PATH" ]; then
    NGINX_VHOST_CONF_PATH=/usr/local/nginx/conf/vhost
fi

if [ -z "$NGINX_NGINX_CONF_PATH" ]; then
    NGINX_NGINX_CONF_PATH=/usr/local/nginx/conf/nginx.conf
fi

if [ -z "$LNMP_DOC_ROOT_PATH" ]; then
    LNMP_DOC_ROOT_PATH=/home/wwwroot
fi

if [ -z "$LNMP_LOG_ROOT_PATH" ]; then
    LNMP_LOG_ROOT_PATH=/home/wwwlogs
fi