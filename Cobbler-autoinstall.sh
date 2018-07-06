# 系统：CentOS 7 64
# IP地址：192.168.70.3
# 子网掩码：255.255.255.0
# 网关：192.168.70.2
# DNS：233.5.5.5 233.6.6.6
# 所有服务器均支持PXE网络启动 
# 实现目的：通过配置Cobbler服务器，全自动批量安装部署Linux系统 
# https://www.sundayle.com/2018/07/01/cobbler/
SERVER_IP=192.168.70.3 #服务器IP
DHCP_SUBNET=192.168.70.0 #网络号
DHCP_ROUTER=192.168.70.2 #网关
DHCP_DNS=192.168.70.2 #DNS
DHCP_RANGE='192.168.70.100 192.168.70.200' #分配IP范围
ROOT_PASSWORD=cobbler #密码
ISO='/dev/cdrom' #CentOS7镜像位置

# 关闭SELINUX
sed -i 's#SELINUX=.*#SELINUX=disabled#' /etc/selinux/config

# 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld
# 安装 Cobbler 等依赖
cp -r /etc/yum.repos.d /etc/yum.repos.d.bak
rm -rf /etc/yum.repos.d/*
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum makecache
yum install cobbler cobbler-web dhcp rsync xinetd httpd tftp-server pykickstart -y

# 启动 Cobbler httpd
systemctl start httpd cobblerd
# 配置
## 备份和启用动态修改配置文件功能 
sed -i 's#allow_dynamic_settings: 0#allow_dynamic_settings: 1#' /etc/cobbler/settings 
systemctl restart httpd cobblerd

## server
cobbler setting edit --name=server --value="$SERVER_IP"

## next_server
cobbler setting edit --name=next_server --value="$SERVER_IP"

## 启用xinetd.
sed -i "/disable/ {s#yes#no#}" /etc/xinetd.d/tftp
systemctl start xinetd
systemctl start rsyncd

## get-loaders
cobbler get-loaders

# root密码为cobbler
PASSWORD=`openssl passwd -1 -salt GJMgaR1+jQ $ROOT_PASSWORD`
#$1$cobbler$M6SE55xZodWc9.vAKLJs6.
cobbler setting edit --name=default_password_crypted --value="$PASSWORD"

## debmirror
yum install debmirror -y
sed -i 's!@dists="sid";!#@dists="sid";!'  /etc/debmirror.conf
sed -i 's!@arches="i386";!#@arches="i386";!'  /etc/debmirror.conf

## fence-agents
yum install -y fence-agents

## 避免重装系统
cobbler setting edit --name=pxe_just_once --value=1

## DHCP配置
cp /etc/cobbler/dhcp.template{,.ori}
cobbler setting edit --name=manage_dhcp --value=1
cp /etc/cobbler/dhcp.template{,.bak}
## 网络段
sed -i "s/192.168.1.0/$DHCP_SUBNET/" /etc/cobbler/dhcp.template
##网关
sed -i "s/192.168.1.5/$DHCP_ROUTER/" /etc/cobbler/dhcp.template
##dns
sed -i "s/192.168.1.1;/$DHCP_DNS;/" /etc/cobbler/dhcp.template
##分配ip范围
sed -i "s/192.168.1.100 192.168.1.254/$DHCP_RANGE/" /etc/cobbler/dhcp.template

grep -A 7 "^subnet " /etc/cobbler/dhcp.template 
#subnet 192.168.70.0 netmask 255.255.255.0 {
#     option routers             192.168.70.2;
#     option domain-name-servers 192.168.70.2;
#     option subnet-mask         255.255.255.0;
#     range dynamic-bootp        192.168.70.100 192.168.70.200;
#     default-lease-time         21600;
#     max-lease-time             43200;
#     next-server                $next_server;

## 重启服务
systemctl restart cobblerd httpd xinetd rsyncd
systemctl enable cobblerd httpd xinetd rsyncd
cobbler sync

## 检查配置
cobbler check
grep -E "^(server|next_server|manage_dhcp|pxe_just_once|default_password_crypted)" /etc/cobbler/settings 
#default_password_crypted: "$1$cobbler$M6SE55xZodWc9.vAKLJs6."
#manage_dhcp: 1
#next_server: $SERVER_IP
#pxe_just_once: 1
#server: $SERVER_IP

# 导入iso
mkdir /mnt/cobbler
mount  -t iso9660 -o loop,ro $ISO /mnt/cobbler
cobbler import --path=/mnt/cobbler --name=CentOS-7-x86_64 --arch=x86_64

# 下载ks
wget -O /var/lib/cobbler/kickstarts/CentOS-7-x86_64.cfg https://raw.githubusercontent.com/sundayle/Cobbler/master/CentOS-7-x86_64.cfg

#指定ks
cobbler profile edit --name=CentOS-7-x86_64 --kickstart=/var/lib/cobbler/kickstarts/CentOS-7-x86_64.cfg

#eth0
cobbler profile edit --name=CentOS-7-x86_64 --kopts='net.ifnames=0 biosdevname=0'
cobbler sync
cobbler validateks

#手动安装
#开机 选择CentOS-7-x86_64即可安装

#自动化安装  指定ip gateay dns（--mac: 客户端mac地址） 客户端开机即可自动安装
#cobbler system add --name=nginx_server --mac=00:0C:29:8A:A7:92 --profile=CentOS-7-x86_64 --ip-address=192.168.70.118 --subnet=255.255.255.0 --gateway=192.168.70.2 --interface=eth0 --static=1 --hostname=www.sundayle.com --name-servers="223.5.5.5 223.6.6.6" --kickstart=/var/lib/cobbler/kickstarts/CentOS-7-x86_64.cfg