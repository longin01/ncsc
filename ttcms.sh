#!/bin/bash
rm -rf ttcms.sh
yum -y install curl wget git
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
yum -y install docker-ce-19.03.15-3.el7
systemctl enable docker && systemctl start docker
systemctl daemon-reload
systemctl restart docker
mkdir -p /usr/local/html && cd /usr/local/html && rm -rf cms
git clone https://github.com/longin01/ncys.git cms
chmod -R 777 /usr/local/html/cms
docker stop ttcms >/dev/null 2>&1
docker rm ttcms >/dev/null 2>&1
docker run -itd --name ttcms -p 80:80 -v /usr/local/html/cms:/usr/local/html/cms -v /sys/fs/cgroup:/sys/fs/cgroup --restart=always --privileged=true karolynpabelickdhj54/ttcms:1.0 /usr/sbin/init
echo "Everything is ok!"
echo "Open the website: http://`hostname -I|awk '{print $1}'`"
