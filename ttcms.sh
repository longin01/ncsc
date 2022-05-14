#!/bin/bash
rm -rf ttcms.sh
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
yum -y install curl wget git docker-ce-19.03.15-3.el7
systemctl enable docker && systemctl start docker
systemctl daemon-reload
systemctl restart docker
mkdir -p /usr/local/html && cd /usr/local/html
git clone github.com/longin01/ncys.git cms
chmod -R 777 /usr/local/html/cms
docker run -itd --name centos -p 80:80 -v /usr/local/html/cms:/usr/local/html/cms -v /sys/fs/cgroup:/sys/fs/cgroup --restart=always --privileged=true karolynpabelickdhj54/ttcms:1.0 /usr/sbin/init
