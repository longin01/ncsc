#!/bin/bash
#创建脚本目录
mkdir -p /shell
chmod -R 777 /shell

cat>/shell/nginx_ip_attack.sh<<"EOF"
#!/bin/bash
#修改nginx日志日期显示格式
#sed -i.old 's#time_local#time_iso8601#g' /etc/nginx/nginx.conf

#nginx平滑重启
#nginx -s reload

#将当天的访问日志放到cms.log文本
Scme=`date -R|awk 'NR==1{print $2"/"$3"/"$4}'`
Scmn=`date +%Y%m%d`
Scmi=`date +%Y-%m-%d`
cd /var/log/nginx/
mkdir -p nginx_log
cat cms.log cms.log-$Scmn | grep $Scme > nginx_log/cms.log

#一至十二月
#Jan Feb Mar
#Apr May Jun
#Jul Aug Sep
#Oct Nov Dec
#查看具体某天日志内容
#cat cms.log | grep '01/Mar/2021' > nginx_log/cms.log
#查看具体某几天日志内容
#cat cms.log cms.log.1 | grep -e '01/Mar/2021' -e '28/Feb/2021' > nginx_log/cms.log

#统计$Scmn.txt里面访问次数大于50的前10个最多访问ip及次数
cat nginx_log/cms.log | cut -d ' ' -f 1 | sort |uniq -c | sort -nr | awk '{if($1>50) print $0 }'| head -n 10 > nginx_log/ipnum_$Scmn.txt && cat nginx_log/ipnum_$Scmn.txt -n

cat nginx_log/cms.log |awk '{print $1}'|sort |uniq > nginx_log/ip_$Scmn.txt

#通过shell统计每个ip访问次数
for i in `cat nginx_log/ip_$Scmn.txt`
do
iptj=`cat nginx_log/cms.log |grep $i | grep -v 400 |wc -l`
echo "ip地址: "$i" 在 $Scmi 全天(24小时)累计成功请求"$iptj"次，平均每分钟请求次数为："$(($iptj/1440)) >> nginx_log/result.txt
done
cat nginx_log/result.txt && mv -f nginx_log/result.txt nginx_log/result_$Scmn.txt
EOF

Scmn=`date +%Y%m%d`
echo "`sh /shell/nginx_ip_attack.sh`" > /shell/nginx_result_$Scmn.txt && rm -rf /shell/nginx_ip_attack.sh
cat /shell/nginx_result_$Scmn.txt
