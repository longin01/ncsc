yum install -y git
cd /home/wwwroot
rm -rf *
git clone https://longin01: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@github.com/longin01/ncyu.git cms

rm -rf cms/application/data/install/install.lock
chmod -R 777 cms/runtime
chmod -R 777 cms
