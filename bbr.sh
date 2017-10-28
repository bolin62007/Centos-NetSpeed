#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS 6+,Debian7+,Ubuntu12+
#	Description: BBR+BBR魔改版+Lotsever
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
	if [[ "${release}" == "centos" ]]; then
		centos_bbr
	elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
		debian_bbr
	fi
	detele_kernel
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

#编译并启用BBR魔改
startbbrmod(){
	if [[ "${release}" == "centos" ]]; then
		yum install -y make gcc
		mkdir bbrmod && cd bbrmod
		wget -N --no-check-certificate http://${github}/bbr/tcp_tsunami.c
		echo "obj-m:=tcp_tsunami.o" > Makefile
		make -C /lib/modules/$(uname -r)/build M=`pwd` modules CC=/usr/bin/gcc
		chmod +x ./tcp_tsunami.ko
		cp -rf ./tcp_tsunami.ko /lib/modules/$(uname -r)/kernel/net/ipv4
		insmod tcp_tsunami.ko
		depmod -a
	else
		apt-get update
		if [[ "${release}" == "ubuntu" && "${version}" = "14" ]]; then
			apt-get -y install build-essential
			apt-get -y install software-properties-common
			add-apt-repository ppa:ubuntu-toolchain-r/test -y
			apt-get update
		fi
		apt-get -y install make gcc-4.9
		wget -N --no-check-certificate http://${github}/bbr/tcp_tsunami.c
		echo "obj-m:=tcp_tsunami.o" > Makefile
		make -C /lib/modules/$(uname -r)/build M=`pwd` modules CC=/usr/bin/gcc-4.9
		install tcp_tsunami.ko /lib/modules/$(uname -r)/kernel
		cp -rf ./tcp_tsunami.ko /lib/modules/$(uname -r)/kernel/net/ipv4
		depmod -a
	fi
	
	sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
	echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=tsunami" >> /etc/sysctl.conf
	sysctl -p
    cd  && rm -rf bbrmod
	echo -e "${Info}魔改版BBR启动成功！"
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

#检查Linux版本
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

#检查安装bbr魔改版的系统要求
check_sys_bbrmod(){
	check_sys
	check_version
	if [[ "${release}" == "centos" ]]; then
		if [[ ${version} -gt "5" ]]; then
			installbbr
		else
			echo -e "${Error} BBR魔改版不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	elif [[ "${release}" == "debian" ]]; then
		if [[ ${version} -gt "7" ]]; then
			installbbr
		else
			echo -e "${Error} BBR魔改版不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	elif [[ "${release}" == "ubuntu" ]]; then
		if [[ ${version} -ge "14" ]]; then
			installbbr
		else
			echo -e "${Error} BBR魔改版不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	else
		echo -e "${Error} BBR魔改版不支持当前系统 ${release} ${version} ${bit} !" && exit 1
	fi
}

#检查安装bbr的系统要求
check_sys_bbr(){
	check_sys
	check_version
	if [[ "${release}" == "centos" ]]; then
		if [[ ${version} -ge "6" ]]; then
			installbbr
		else
			echo -e "${Error} BBR不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	elif [[ "${release}" == "debian" ]]; then
		if [[ ${version} -ge "7" ]]; then
			installbbr
		else
			echo -e "${Error} BBR不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	elif [[ "${release}" == "ubuntu" ]]; then
		if [[ ${version} -ge "12" ]]; then
			installbbr
		else
			echo -e "${Error} BBR不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	else
		echo -e "${Error} BBR不支持当前系统 ${release} ${version} ${bit} !" && exit 1
	fi
}

#检查安装Lotsever的系统要求
check_sys_Lotsever(){
	check_sys
	check_version
	if [[ "${release}" == "centos" ]]; then
		if [[ ${version} -ge "6" ]]; then
			Lotsever
		else
			echo -e "${Error} Lotsever不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	elif [[ "${release}" == "debian" ]]; then
		if [[ ${version} -ge "7" ]]; then
			Lotsever
		else
			echo -e "${Error} Lotsever不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	elif [[ "${release}" == "ubuntu" ]]; then
		if [[ ${version} -ge "12" ]]; then
			Lotsever
		else
			echo -e "${Error} Lotsever不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	else
		echo -e "${Error} Lotsever不支持当前系统 ${release} ${version} ${bit} !" && exit 1
	fi
}

#centos更换bbr内核
centos_bbr(){
	rpm --import http://${github}/bbr/${release}/RPM-GPG-KEY-elrepo.org
	yum install -y http://${github}/bbr/${release}/${version}/${bit}/kernel-ml-4.11.8.rpm
	yum remove -y kernel-headers
	yum install -y http://${github}/bbr/${release}/${version}/${bit}/kernel-ml-headers-4.11.8.rpm
	yum install -y http://${github}/bbr/${release}/${version}/${bit}/kernel-ml-devel-4.11.8.rpm
}

#Debian/ubuntu更换bbr内核
debian_bbr(){
	mkdir bbr && cd bbr
	wget -N --no-check-certificate http://${github}/bbr/debian-ubuntu/linux-headers-4.11.8-all.deb
	wget -N --no-check-certificate http://${github}/bbr/debian-ubuntu/${bit}/linux-headers-4.11.8.deb
	wget -N --no-check-certificate http://${github}/bbr/debian-ubuntu/${bit}/linux-image-4.11.8.deb
	
	dpkg -i linux-headers-4.11.8-all.deb
	dpkg -i linux-headers-4.11.8.deb
	dpkg -i linux-image-4.11.8.deb
	cd .. && rm -rf bbrmod
}

#删除多余内核
detele_kernel(){
	if [[ "${release}" == "centos" ]]; then
		kernel_version=`uname -r | cut -d- -f1`
		rpm_total=`rpm -qa | grep kernel | grep -v "4.11.8" | grep -v "noarch" | wc -l`
		if [ "${rpm_total}" > "1" ]; then
			echo -e "检测到 ${rpm_total} 个其余内核，开始卸载..."
			for((integer = 1; integer <= ${rpm_total}; integer++)); do
				rpm_del=`rpm -qa | grep kernel | grep -v "4.11.8" | grep -v "noarch" | head -${integer}`
				echo -e "开始卸载 ${rpm_del} 内核..."
				yum remove -y ${rpm_del}>/dev/null 2>&1
				echo -e "卸载 ${rpm_del} 内核卸载完成，继续..."
			done
			rpm_total=`rpm -qa | grep kernel | grep -v "4.11.8" | grep -v "noarch" | wc -l`
			if [ "${rpm_total}" = "0" ]; then
				echo -e "内核卸载完毕，继续..."
			else
				echo -e " 内核卸载异常，请检查 !" && exit 1
			fi
		else
			echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
		fi
	elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
		deb_total=`dpkg -l | grep linux-image | awk '{print $2}' | grep -v "4.11.8" | wc -l`
		if [ "${deb_total}" > "1" ]; then
			echo -e "检测到 ${deb_total} 个其余内核，开始卸载..."
			for((integer = 1; integer <= ${deb_total}; integer++)); do
				deb_del=`dpkg -l|grep linux-image | awk '{print $2}' | grep -v "4.11.8" | head -${integer}`
				echo -e "开始卸载 ${deb_del} 内核..."
				apt-get purge -y ${deb_del}>/dev/null 2>&1
				echo -e "卸载 ${deb_del} 内核卸载完成，继续..."
			done
			deb_total=`dpkg -l|grep linux-image | awk '{print $2}' | grep -v "4.11.8" | wc -l`
			if [ "${deb_total}" = "0" ]; then
				echo -e "内核卸载完毕，继续..."
			else
				echo -e " 内核卸载异常，请检查 !" && exit 1
			fi
		else
			echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
		fi
	fi
}

start(){
	startbbrmod
}

install(){
	check_sys_bbrmod
}

check_sys
check_version
action=$1
[ -z $1 ] && action=install
case "$action" in
	install|start)
	${action}
	;;
	*)
	echo "输入错误 !"
	echo "用法: { install | start }"
	;;
esac
