#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: Centos 6/7
#	Description: BBR+BBRMOD+锐速
#	Version: 1.0
#	Author: 千影
#	Blog: https://www.94ish.me/
#=================================================
sh_ver="1.0.0"
github="raw.githubusercontent.com/chiakge/Centos-NetSpeed/master"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

#安装BBR内核
installbbr(){
	rpm --import http://${github}/bbr/RPM-GPG-KEY-elrepo.org
	yum install -y http://${github}/bbr/centos/${version}/${bit}/kernel-ml-4.11.8.rpm
	yum remove -y kernel-headers
	yum install -y http://${github}/bbr/centos/${version}/${bit}/kernel-ml-headers-4.11.8.rpm
	yum install -y http://${github}/bbr/centos/${version}/${bit}/kernel-ml-devel-4.11.8.rpm
	BBR_grub
	echo -e "${Tip} 重启VPS后，请重新运行脚本开启魔改BBR ${Red_background_prefix} bash bbr.sh start ${Font_color_suffix}"
	stty erase '^H' && read -p "需要重启VPS后，才能开启BBR，是否现在重启 ? [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
			echo -e "${Info} VPS 重启中..."
			reboot
	fi
}

#更新引导
BBR_grub(){
	if [[ "${release}" == "centos" ]]; then
        if [[ ${version} = "6" ]]; then
            if [ ! -f "/boot/grub/grub.conf" ]; then
                echo -e "${Error} /boot/grub/grub.conf 找不到，请检查."
                exit 1
            fi
            sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
        elif [[ ${version} = "7" ]]; then
            if [ ! -f "/boot/grub2/grub.cfg" ]; then
                echo -e "${Error} /boot/grub2/grub.cfg 找不到，请检查."
                exit 1
            fi
            grub2-set-default 0
        fi
    elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
        /usr/sbin/update-grub
    fi
}

startbbr(){
	yum install -y make gcc
	mkdir bbrmod && cd bbrmod
	wget http://${github}/bbr/tcp_tsunami.c
	echo "obj-m:=tcp_tsunami.o" > Makefile
	make -C /lib/modules/$(uname -r)/build M=`pwd` modules CC=/usr/bin/gcc
	chmod +x ./tcp_tsunami.ko
	cp -rf ./tcp_tsunami.ko /lib/modules/$(uname -r)/kernel/net/ipv4
	insmod tcp_tsunami.ko
	depmod -a
	
	sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
	echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=tsunami" >> /etc/sysctl.conf
	sysctl -p
    cd  && rm -rf bbrmod
	echo "魔改版BBR启动成功！"
}

#检查系统
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
}

#检查Centos版本
check_version(){
	if [[ -s /etc/redhat-release ]]; then
		version=`grep -oE  "[0-9.]+" /etc/redhat-release | cut -d . -f 1`
	else
		version=`grep -oE  "[0-9.]+" /etc/issue | cut -d . -f 1`
	fi
	bit=`uname -m`
	if [[ ${bit} = "x86_64" ]]; then
		bit="x64"
	else
		bit="x32"
	fi	
}


check_sys
check_version
[[ ${release} != "centos" ]]  && echo -e "${Error} 本脚本不支持当前系统 ${release} ${version} ${bit} !" && exit 1
action=$1
[ -z $1 ] && action=install
case "$action" in
	install|start)
	${action}bbr
	;;
	*)
	echo "输入错误 !"
	echo "用法: { install | start }"
	;;
esac