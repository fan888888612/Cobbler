# Cobbler
修改 autoinstall.sh 这些参数
SERVER_IP=192.168.70.3 #服务器IP
DHCP_SUBNET=192.168.70.0 #网络号
DHCP_ROUTER=192.168.70.2 #网关
DHCP_DNS=192.168.70.2 #DNS
DHCP_RANGE='192.168.70.100 192.168.70.200' #分配IP范围
ROOT_PASSWORD=cobbler #密码
ISO='/dev/cdrom' #CentOS7镜像位置

#手动安装
#开机 选择CentOS-7-x86_64即可安装

#自动化安装  指定ip gateay dns（--mac: 客户端mac地址） 客户端开机即可自动安装
#cobbler system add --name=nginx_server --mac=00:0C:29:8A:A7:92 --profile=CentOS-7-x86_64 --ip-address=192.168.70.118 --subnet=255.255.255.0 --gateway=192.168.70.2 --interface=eth0 --static=1 --hostname=www.sundayle.com --name-servers="223.5.5.5 223.6.6.6" --kickstart=/var/lib/cobbler/kickstarts/CentOS-7-x86_64.cfg