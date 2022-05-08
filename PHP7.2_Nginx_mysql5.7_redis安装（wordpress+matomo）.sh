#!/bin/bash

##更换阿里云源
#mv /etc/yum.repos.d/cobbler-config.repo /etc/yum.repos.d/cobbler-config.repo.bak
yum install -y wget
/bin/cp -rf /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo_bak
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all
yum makecache
yum update -y

##安装rz、sz命令
yum -y install lrzsz bash-completion vim wget net-tools rsync

##关闭Selinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

##设置最大连接数
echo "ulimit -HSn 102400" >> /etc/rc.local
echo 'export HISTTIMEFORMAT="%F %T # "' >> /etc/profile

cat >> /etc/security/limits.conf << EOF
*   soft   nofile   65535  
*   hard   nofile   65535 
EOF

##阿里云校时服务器
yum install ntpdate ntp -y
/usr/sbin/ntpdate ntp1.aliyun.com 
echo "* 5 * * * root /usr/sbin/ntpdate ntp1.aliyun.com > /dev/null 2>&1" >> /etc/crontab
systemctl restart crond.service

##关闭防火墙
systemctl disable firewalld.service
systemctl stop firewalld.service

#修改ssh默认端口
#echo "Port=4122" >>/etc/ssh/sshd_config

#服务启动
systemctl enable sshd
systemctl restart sshd

#基础环境安装

yum -y install make cmake gcc gcc-c++ gcc-g77 flex bison file libtool libtool-libs autoconf kernel-devel patch wget crontabs libjpeg libjpeg-devel libpng libpng-devel libpng10 libpng10-devel gd gd-devel libxml2 libxml2-devel zlib zlib-devel glib2 glib2-devel unzip tar bzip2 bzip2-devel libzip-devel libevent libevent-devel ncurses ncurses-devel curl curl-devel libcurl libcurl-devel e2fsprogs e2fsprogs-devel krb5 krb5-devel libidn libidn-devel openssl openssl-devel vim-minimal gettext gettext-devel ncurses-devel gmp-devel pspell-devel unzip libcap diffutils ca-certificates net-tools libc-client-devel psmisc libXpm-devel git-core c-ares-devel libicu-devel libxslt libxslt-devel xz expat-devel libaio-devel rpcgen libtirpc-devel perl lrzsz telnet vim

echo "基础环境安装完成"

sleep 3

echo "准备安装Nginx环境......"

#删除旧nginx、httpd
yum autoremove -y nginx httpd*
rm -rf /etc/httpd /etc/nginx
rm -rf /home/wwwroot

#配置nginx对应的YUM源

cat > /etc/yum.repos.d/nginx.repo << "EOF"
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/rhel/7/$basearch/
gpgcheck=0
enabled=1
EOF

yum -y install nginx

cat > /etc/nginx/nginx.conf << "EOF"
user  nginx nginx;
worker_processes auto;
worker_cpu_affinity auto;

#error_log  logs/error.log  crit;
#
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

worker_rlimit_nofile 51200;

events
{
    use epoll;
    multi_accept on;
    worker_connections 51200;
}

http
{
    include       mime.types;
    default_type  application/octet-stream;


log_format  main  '$remote_addr - $remote_user [$time_local] "$request" $http_host '
		  '$status $request_length $body_bytes_sent "$http_referer" '
                   '"$http_user_agent"  $request_time $upstream_response_time';

    access_log off;
    #access_log logs/access.log main buffer=16k;

    server_names_hash_bucket_size 128;
    client_header_buffer_size 32k;
    large_client_header_buffers 4 32k;
    client_max_body_size 500M; 

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 60; 
    server_tokens off;
   # server_tag off;
   # server_info off;

    fastcgi_connect_timeout 300;
    fastcgi_send_timeout 300;
    fastcgi_read_timeout 300;
    fastcgi_buffer_size 64k;
    fastcgi_buffers 8 64k;
    fastcgi_busy_buffers_size 128k;
    fastcgi_temp_file_write_size 256k;

    gzip on;
    gzip_min_length  1k;
    gzip_buffers     4 16k;
    gzip_http_version 1.1;
    gzip_comp_level 5;
#   gzip_types     text/plain application/javascript application/x-javascript text/javascript text/css application/xml application/xml+rss;
    gzip_types text/plain application/x-javascript text/css application/xml text/javascript application/x-httpd-php image/jpeg image/gif image/png;
    gzip_vary on;


    include vhosts/*.conf;
}

EOF


[ ! -d /etc/nginx/vhosts ] && mkdir -p /etc/nginx/vhosts

cat > /etc/nginx/vhosts/wordpress.conf << "EOF"
server {
    listen   80;
    server_name localhost;
    #禁ip访问，只能域名
    if ($host = 'localhost'){
    return 403;
    }
    set $base "/home/wwwroot/wordpress";
    index index.php index.html index.htm;
    access_log  /var/log/nginx/wordpress.log  main;
    root /home/wwwroot/wordpress;

#匹配成功后跳转到百度，执行永久301跳转
#rewrite ^/(.*) http://www.baidu.com/ permanent;

#仅cms端配置，推流内网ip+Nginx端口
#location /thumb {
#         proxy_pass http://192.168.11.163:8088/thumb;
#                 proxy_set_header Host $http_host;
#
#        }

#wordpress、tv端都要配置
#location ~* \.(m3u8|ts|aac)$ {
#         proxy_cache off;                    # 禁用代理缓存
#         expires -1;                         # 禁用页面缓存
#         proxy_pass http://192.168.11.163:8088;  # 反代目标 URL，推流内网ip+Nginx端口
#         sub_filter 'http://192.168.11.163:8088' 'http://$host/';   # 替换 m3u8 文件里的资源链接
#         sub_filter_last_modified off;       # 删除原始响应里的浏览器缓存值
#         sub_filter_once off;                # 替换所有匹配内容
#         sub_filter_types *;                 # 匹配任何 MIME 类型
#}

#仅tv端配置，cms后台管理地址+端口
#location /api {
#         proxy_pass http://172.18.249.2:8000/api;
#         }
#   location /attaches {
#         proxy_pass http://172.18.249.2:8000/attaches;
#         }
#   location /uploads {
#         proxy_pass http://172.18.249.2:8000/uploads;
#         }

#server {
#    listen   443 ssl;
#    server_name  localhost;
#    set $base "/home/wwwroot/wordpress";
#    index index.php index.html index.htm;
#    access_log  /var/log/nginx/wordpress.log  main;

#   root /home/wwwroot/wordpress;

#    ssl_certificate "/etc/pki/tls/wordpress/2020.pem";
#    ssl_certificate_key "/etc/pki/tls/wordpress/2020.key";
#    ssl_session_timeout 5m;
#    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
#    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
#    ssl_prefer_server_ciphers on;

location / {  

        if (!-e $request_filename) {
 	rewrite ^(.*)$ /index.php?s=$1 last;
 	break;
        }
}
    #error_page  404              /404.html;
    #error_page  500 502 503 504  /50x.html;

    location = /50x.html {
        root   html;
    }

location ~ \.php$ {
# 404
#        try_files $fastcgi_script_name =404;

        #default fastcgi_params
        include fastcgi_params;

        #fastcgi settings
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index  index.php;
        #fastcgi_buffers  8 16k;
        #fastcgi_buffer_size  32k;

        fastcgi_param DOCUMENT_ROOT  $realpath_root;
        fastcgi_param SCRIPT_FILENAME  $realpath_root$fastcgi_script_name;
      #fastcgi_param PHP_ADMIN_VALUE  "open_basedir=$base/:/usr/lib/php/:/usr/lib64/php:/tmp/";
      fastcgi_param PHP_ADMIN_VALUE  "open_basedir=$document_root/:/usr/lib/php/:/usr/lib64/php:/tmp/:/home/wwwroot/wordpress";         
      
  }

#location = /favicon.ico {
#log_not_found off;
#access_log off;
#    }
# robots.txt
# location = /robots.txt {
#        log_not_found off;
#        access_log off;
#    }
#
# assets, media
#location ~* \.(?:css(\.map)?|js(\.map)?|jpe?g|png|gif|ico|cur|heic|webp|tiff?|mp3|m4a|aac|ogg|midi?|wav|mp4|mov|webm|mpe?g|avi|ogv|flv|wmv)$ {
#        expires 7d;
#        access_log off;
#    }
#
# svg, fonts
#location ~* \.(?:svgz?|ttf|ttc|otf|eot|woff2?)$ { 
#        add_header Access-Control-Allow-Origin "*";
#        expires 7d;
#        access_log off;
#    }
#
}
EOF

realip=`hostname -I|awk '{print $1}'`
sed -i "s#localhost#${realip}#g" /etc/nginx/vhosts/wordpress.conf

[ ! -d /home/wwwroot/wordpress ] && mkdir -p /home/wwwroot/wordpress

cat>/home/wwwroot/wordpress/index.php<<EOF
<?php
echo phpinfo();
?>
EOF

cat > /etc/nginx/vhosts/matomo.conf << "EOF"
server {
    listen   81;
    server_name localhost;
    set $base "/home/wwwroot/matomo";
    index index.php index.html index.htm;
    access_log  /var/log/nginx/matomo.log  main;
    root /home/wwwroot/matomo;

#location ~* \.(m3u8|ts|aac)$ {
#         proxy_cache off;                    # 禁用代理缓存
#         expires -1;                         # 禁用页面缓存
#         proxy_pass http://172.18.249.4:8088;  # 反代目标 URL，推流内网ip+Nginx端口
#         sub_filter 'http://172.18.249.4:8088' 'http://$host/';   # 替换 m3u8 文件里的资源链接
#         sub_filter_last_modified off;       # 删除原始响应里的浏览器缓存值
#         sub_filter_once off;                # 替换所有匹配内容
#         sub_filter_types *;                 # 匹配任何 MIME 类型
#}

#server {
#    listen   443 ssl;
#    server_name  localhost;
#    set $base "/home/wwwroot/matomo";
#    index index.php index.html index.htm;
#    access_log  /var/log/nginx/matomo.log  main;

#   root /home/wwwroot/matomo;

#    ssl_certificate "/etc/pki/tls/matomo/2020.pem";
#    ssl_certificate_key "/etc/pki/tls/matomo/2020.key";
#    ssl_session_timeout 5m;
#    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
#    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
#    ssl_prefer_server_ciphers on;

location / {  

        if (!-e $request_filename) {
 	rewrite ^(.*)$ /index.php?s=$1 last;
 	break;
        }
}
    #error_page  404              /404.html;
    #error_page  500 502 503 504  /50x.html;

    location = /50x.html {
        root   html;
    }

location ~ \.php$ {
# 404
#        try_files $fastcgi_script_name =404;

        #default fastcgi_params
        include fastcgi_params;

        #fastcgi settings
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index  index.php;
        #fastcgi_buffers  8 16k;
        #fastcgi_buffer_size  32k;

        fastcgi_param DOCUMENT_ROOT  $realpath_root;
        fastcgi_param SCRIPT_FILENAME  $realpath_root$fastcgi_script_name;
      #fastcgi_param PHP_ADMIN_VALUE  "open_basedir=$base/:/usr/lib/php/:/usr/lib64/php:/tmp/";
      fastcgi_param PHP_ADMIN_VALUE  "open_basedir=$document_root/:/usr/lib/php/:/usr/lib64/php:/tmp/:/home/wwwroot/matomo";         
      
  }
#location = /favicon.ico {
#log_not_found off;
#access_log off;
#    }
# robots.txt
# location = /robots.txt {
#        log_not_found off;
#        access_log off;
#    }
#
# assets, media
#location ~* \.(?:css(\.map)?|js(\.map)?|jpe?g|png|gif|ico|cur|heic|webp|tiff?|mp3|m4a|aac|ogg|midi?|wav|mp4|mov|webm|mpe?g|avi|ogv|flv|wmv)$ {
#        expires 7d;
#        access_log off;
#    }
#
# svg, fonts
#location ~* \.(?:svgz?|ttf|ttc|otf|eot|woff2?)$ { 
#        add_header Access-Control-Allow-Origin "*";
#        expires 7d;
#        access_log off;
#    }
#
}
EOF

realip=`hostname -I|awk '{print $1}'`
sed -i "s#localhost#${realip}#g" /etc/nginx/vhosts/matomo.conf

[ ! -d /home/wwwroot/matomo ] && mkdir -p /home/wwwroot/matomo

cat>/home/wwwroot/matomo/index.php<<EOF
<?php
echo phpinfo();
?>
EOF

#归属nginx权限
chown -R nginx:nginx /home/wwwroot/

#启动nginx
systemctl enable nginx
systemctl restart nginx

sleep 3

#开始安装php环境
echo "开始安装php环境"

##删除PHP旧版
yum autoremove php-* php72w* mod_php72w wphp74 php74-php* -y
find /etc -name "*php*" |xargs  rm -rf
find /etc -name "*php74*" |xargs  rm -rf
rm -rf /usr/bin/php

yum install epel-release -y
rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm

yum -y install --enablerepo=webtatic php72w-devel mod_php72w php72w-devel php72w-common php72w-fpm php72w-mcrypt php72w-mbstring php72w-ldap php72w-gd php72w-opcache php72w-pecl-memcached php72w-mysqlnd php72w-bcmath php72w-odbc php72w-opcache php72w-soap php72w-xml.x86_64 php72-tokenizer php72w-pecl-redis

#备份php.ini，遇同名文件强制覆盖
/bin/cp -rf /etc/php.ini /etc/php.ini.old

#更改时区
sed -i 's#;date.timezone =#date.timezone = Asia\/Shanghai#g' /etc/php.ini

#设定文件上传时间为无限制
sed -i 's#max_execution_time = 30#max_execution_time = 0#g' /etc/php.ini

# 设定POST数据所允许的最大大小
sed -i 's#post_max_size = 8M#post_max_size = 150M#g' /etc/php.ini

#设定上传的文件的最大大小
sed -i 's#upload_max_filesize = 2M#upload_max_filesize = 100M#g' /etc/php.ini

#添加SG11模块
echo "extension=/home/wwwroot/wordpress/ixed.7.2.lin" >> /etc/php.ini

#添加到启动项目
echo "将nginx,php-fpm添加到开机启动项目"

systemctl enable php-fpm
systemctl restart php-fpm

sleep 3

echo "开始安装redis"

##############################################################
# File Name: install_redis.sh
# Version: V1.0
# Author: taxi_zhai
# Organization: opensource
# Created Time : 2019-12-16 23:59:59
# Description:
##############################################################

yum install -y https://repo.ius.io/ius-release-el7.rpm
yum install -y redis5
#sed -i.bak 's/bind 127.0.0.1/bind 0.0.0.0/g' /etc/redis.conf
sed -i.bak 's/daemonize no/daemonize yes/g' /etc/redis.conf
systemctl enable redis
systemctl restart redis

#哨兵配置文件路径
#cat /etc/redis-sentinel.conf

#修改默认端口
#sed -i.bak 's/port 6379/port 6380/g' /etc/redis.conf

sleep 3

#安装MySQL
yum remove mysql mysql-server mysql-libs mysql-common mariadb* mysql-community* -y
rm -rf /var/log/mysqld.log
rm -rf /var/lib/mysql
rm -rf /etc/my.cnf

#导入密钥
rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022

#ubuntu版
#wget -q -O - https://repo.mysql.com/RPM-GPG-KEY-mysql-2022 | apt-key add -

yum -y install wget
wget https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
yum -y install mysql57-community-release-el7-11.noarch.rpm
yum -y install mysql-community-server
systemctl enable mysqld

#创建数据目录
mkdir -p /data/mysql

#添加mysql配置
cat>/etc/my.cnf<<"EOF"
# For advice on how to change settings please see
# http://dev.mysql.com/doc/refman/5.7/en/server-configuration-defaults.html

[mysqld]
#
# Remove leading # and set to the amount of RAM for the most important data
# cache in MySQL. Start at 70% of total RAM for dedicated server, else 10%.
# innodb_buffer_pool_size = 128M
#
# Remove leading # to turn on a very important data integrity option: logging
# changes to the binary log between backups.
# log_bin
#
# Remove leading # to set options mainly useful for reporting servers.
# The server defaults are faster for transactions and fast SELECTs.
# Adjust sizes as needed, experiment to find the optimal values.
# join_buffer_size = 128M
# sort_buffer_size = 2M
# read_rnd_buffer_size = 2M
port = 3306
datadir=/data/mysql
skip-name-resolve
default-storage-engine = InnoDB
socket=/var/lib/mysql/mysql.sock
symbolic-links=0
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid

# 字符集配置
character_set_server=utf8

# gtid配置
server_id = 1
#gtid_mode = on
#enforce-gtid-consistency = true
#log-slave-updates = on

#binlog日志配置
binlog_format = row
log_bin = /data/mysql/mysql-bin
expire_logs_days = 30
#max_binlog_size = 100m
#binlog_cache_size = 4m
#max_binlog_cache_size = 512m

# 连接数限制
max_connections = 500
max_connect_errors = 20
back_log = 500
open_files_limit = 65535
interactive_timeout = 3600
wait_timeout = 3600
max_allowed_packet=1000M
lower_case_table_names=1

#自动提交
autocommit=1
sync_binlog=1

# InnoDB 优化
innodb_buffer_pool_size=2G
innodb_log_file_size = 256M
innodb_log_buffer_size = 4M
innodb_log_buffer_size = 3M
innodb_data_file_path = ibdata1:100M:autoextend
innodb_log_files_in_group = 3
innodb_open_files = 800
innodb_file_per_table = 1
innodb_write_io_threads = 8
innodb_read_io_threads = 8
innodb_purge_threads = 1
innodb_lock_wait_timeout = 120
innodb_strict_mode=1
innodb_large_prefix = on

#自增配置
sql_mode=NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
EOF

#重启数据库
systemctl restart mysqld

#定义mysql默认密码为变量
PASSWORD=$(less /var/log/mysqld.log | grep 'temporary password' | grep -o -E ': .+' | awk '{print $2}')

#修改mysql密码
mysql --connect-expired-password -uroot -p$PASSWORD -e "set global validate_password_policy=0;"
mysql --connect-expired-password -uroot -p$PASSWORD -e "set global validate_password_length=4;"
mysqladmin -uroot -p$PASSWORD password hKBY^LDkBGTCimMl

#mysql忘记密码
#echo "skip-grant-tables">>/etc/my.cnf
#systemctl restart mysqld
#mysql -e "update mysql.user set authentication_string=password('hKBY^LDkBGTCimMl') where user='root' and Host = 'localhost';"
#mysql -uroot -phKBY^LDkBGTCimMl -e 'flush privileges;'
#mysql -uroot -phKBY^LDkBGTCimMl -e "alter user 'root'@'localhost' identified by 'hKBY^LDkBGTCimMl';"
#sed -i 's/skip-grant-tables/#skip-grant-tables/g' /etc/my.cnf
#systemctl restart mysqld

#授予mysql远程权限(root)
#mysql -uroot -phKBY^LDkBGTCimMl -e 'GRANT ALL PRIVILEGES ON *.* TO "root"@"%" IDENTIFIED BY "hKBY^LDkBGTCimMl";'
mysql -uroot -phKBY^LDkBGTCimMl -e 'create database cms;'
mysql -uroot -phKBY^LDkBGTCimMl -e 'create database wordpress;'
#mysql -uroot -phKBY^LDkBGTCimMl -e 'Flush privileges;'

#导入数据库
#mysql -uroot -phKBY^LDkBGTCimMl wordpress < /home/wwwroot/wordpress/zycms.sql

#服务启动
systemctl enable nginx php-fpm mysqld
systemctl restart nginx php-fpm mysqld

#输出信息
echo "浏览器访问 http://`hostname -I|awk '{print $1}'`/"

yum install -y git
cd /home/wwwroot
mv wordpress wordpress_bak
git clone https://longin01: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@github.com/longin01/ncys.git wordpress
mv matomo matomo_bak
git clone https://longin01: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@github.com/longin01/ncyt.git matomo
chmod -R 777 wordpress matomo
