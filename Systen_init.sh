#!/bin/bash
# Author: sw
# system: centos
# 系统基础优化脚本
######################

# 优化PS
echo 'PS1="\[\e[37;40m\][\[\e[36;40m\]\u\[\e[37;40m\]@\h \[\e[36;40m\]\w\[\e[0m\]]\\$ "' > /etc/profile.d/PS1.sh

# 配置yum源
mkdir /etc/yum.repos.d/bak
mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak

curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
     ##centos 7
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo

# 系统最小化安装，安装所需要的软件
yum -y install wget vim lrzsz bash-completion net-tools lsof psmisc tree unzip ntp iptables

# 更改Linux系统时区
#rm -rf /etc/localtime
#ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
#timedatectl set-timezone 'Asia/Shanghai'
# 设置ntp
ntpdate -u cn.pool.ntp.org
hwclock --systohc
timedatectl set-timezone Asia/Shanghai

# 设置 ulimit
ulimit -SHn 65535
# 调整文件描述符数量
/bin/cp /etc/security/limits.conf /etc/security/limits.conf.bak
cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF

# systemd 启动的程序，需要修改
# /bin/cp /etc/systemd/system.conf /etc/systemd/system.conf.bak
# sed -i 's/#DefaultLimitNOFILE=/DefaultLimitNOFILE=65535/' system.conf
# sed -i 's/#DefaultLimitNPROC=/DefaultLimitNPROC=65535/' system.conf
# systemctl daemon-reexec
# 可以通过修改相关进程的service文件，通常在/etc/systemd/system/目录下
# 在“[Service]”下面添加“LimitNOFILE=20480000”


# 关闭selinux 和 firewalld
echo "=========close selinux==========="
setenforce 0
sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config
echo "selinux is disabled"

systemctl disable firewalld
systemctl stop firewalld
echo "firewalld is disabled"

# 精简开机自启动服务（只启动crond,sshd,network,syslog）
# 设置所有运行
# echo '级别3自启动服务关闭############'
# for i in `chkconfig --list |grep 3:on |awk '{print $1}'`
# do
#         chkconfig --level 3 $i off
# done
# ##########仅设置crond,sshd,network,syslog自启动#########
# for i in {crond,sshd,network,rsyslog}
# do
#         chkconfig --level 3 $i on
# done

# 内核参数优化
cat >> /etc/sysctl.conf << EOF
net.ipv4.neigh.default.gc_stale_time=120
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_announce=2
 
net.core.netdev_max_backlog =  32768
net.core.somaxconn = 32768
net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.conf.lo.arp_announce=2
 
net.ipv4.tcp_synack_retries = 2  #参数的值决定了内核放弃连接之前发送SYN+ACK包的数量
net.ipv4.tcp_syn_retries = 1 #表示在内核放弃建立连接之前发送SYN包的数量
net.ipv4.tcp_max_syn_backlog = 262144 #这个参数表示TCP三次握手建立阶段接受SYN请求列队的最大长度，默认1024，将其设置的大一些可以使出现Nginx繁忙来不及accept新连接的情况时，Linux不至于丢失客户端发起的链接请求
net.ipv4.tcp_syncookies = 1  #解决syn攻击,用于设置开启SYN Cookies，当出现SYN等待队列溢出时，启用cookies进行处理

net.ipv4.tcp_tw_reuse = 1    #参数设置为 1 ，表示允许将TIME_WAIT状态的socket重新用于新的TCP链接，这对于服务器来说意义重大，因为总有大量TIME_WAIT状态的链接存在
net.ipv4.tcp_timestamps = 1  #开启时间戳，配合tcp复用。如遇到局域网内的其他机器由于时间戳不同导致无法连接服务器，有可能是这个参数导致。注：阿里的slb会清理掉tcp_timestamps
net.ipv4.tcp_tw_recycle = 1 #这个参数用于设置启用timewait快速回收
net.ipv4.tcp_max_tw_buckets = 6000 #参数设置为 1 ，表示允许将TIME_WAIT状态的socket重新用于新的TCP链接，该参数默认为180000，过多的TIME_WAIT套接字会使Web服务器变慢
net.ipv4.tcp_mem = 94500000 915000000 927000000 
net.ipv4.tcp_fin_timeout = 1 #当服务器主动关闭链接时，选项决定了套接字保持在FIN-WAIT-2状态的时间。默认值是60秒
net.ipv4.tcp_keepalive_time = 600 #当keepalive启动时，TCP发送keepalive消息的频度；默认是2小时，将其设置为10分钟，可以更快的清理无效链接
net.ipv4.ip_local_port_range = 1024 65000#定义UDP和TCP链接的本地端口的取值范围
fs.file-max=65535  #表示最大可以打开的句柄数
EOF
/sbin/sysctl -p
echo "sysctl set OK!"

# 更改默认的ssh服务端口，禁止root用户远程连接，禁止空密码连接，设置5分钟自动下线
/bin/cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
#sed -i 's/\#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
# sed -i 's/\#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
service sshd restart

# 锁定关键系统文件
#chmod 600 /etc/passwd
#chmod 600 /etc/shadow
#chmod 600 /etc/group
#chmod 600 /etc/gshadow

历史命令显示操作时间
if ! grep HISTTIMEFORMAT /etc/bashrc; then
echo 'export HISTTIMEFORMAT="%F %T `whoami` "' >> /etc/bashrc
fi


# reboot
# 清空/etc/issue, 去除系统及内核版本登录前的屏幕显示
