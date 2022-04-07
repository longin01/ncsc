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

realip=`hostname -I|awk '{print $1}'`

cat > /etc/nginx/vhosts/cms.conf << "EOF"
server {
    listen   80;
    server_name localhost;
    #禁ip访问，只能域名
    if ($host = 'localtest'){
    return 403;
    }
    set $base "/home/wwwroot/cms";
    index index.php index.html index.htm;
    access_log  /var/log/nginx/cms.log  main;
    root /home/wwwroot/cms;

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

#location ~ \.php$ {
# 404
#        try_files $fastcgi_script_name =404;

        # default fastcgi_params
  #      include fastcgi_params;

        # fastcgi settings
        #fastcgi_pass 127.0.0.1:9000;
        #fastcgi_index  index.php;
   #     fastcgi_buffers  8 16k;
   #     fastcgi_buffer_size  32k;

        #fastcgi_param DOCUMENT_ROOT  $realpath_root;
        #fastcgi_param SCRIPT_FILENAME  $realpath_root$fastcgi_script_name;
# fastcgi_param PHP_ADMIN_VALUE  "open_basedir=$base/:/usr/lib/php/:/usr/lib64/php:/tmp/";
      #  fastcgi_param PHP_ADMIN_VALUE  "open_basedir=$document_root/:/usr/lib/php/:/usr/lib64/php:/tmp/:/home/wwwroot/cim";         
      
  # }

#php5静态路由
        location ~ .+\.php($|/) {  
                    set $script $uri;  
                    set $path_info "/";  
                    if ($uri ~ "^(.+\.php)(/.+)") {  
                        set $script     $1;  
                        set $path_info  $2;  
                    }  
      
            fastcgi_pass 127.0.0.1:9000;  
            fastcgi_index index.php?IF_REWRITE=1;  
            include fastcgi_params;  
            fastcgi_param PATH_INFO $path_info;  
            fastcgi_param SCRIPT_FILENAME $document_root/$script;  
            fastcgi_param SCRIPT_NAME $script;  
}


}
EOF

realip=`hostname -I|awk '{print $1}'`
sed -i "s#localtest#${realip}#g" /etc/nginx/vhosts/cms.conf


[ ! -d /home/wwwroot/cms ] && mkdir -p /home/wwwroot/cms

cat>/home/wwwroot/cms/index.php<<EOF
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
echo "extension=/home/wwwroot/cms/ixed.7.2.lin" >> /etc/php.ini

#添加到启动项目
echo "将nginx,php-fpm添加到开机启动项目"

systemctl enable php-fpm
systemctl restart php-fpm

sleep 3

#服务启动
systemctl enable nginx php-fpm
systemctl restart nginx php-fpm

#输出信息
#echo "浏览器访问 http://`hostname -I|awk '{print $1}'`/"

yum install -y git
cd /home/wwwroot
mv cms cms_bak
git clone https://longin01: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@github.com/longin01/ncys.git cms
chmod -R 777 cms
rm -rf lnmp.sh
