#!/bin/bash
# hardware_info 服务器状态（还是 node_exporter 省事）
#yum -y install bc sysstat net-tools lrzsz
#文件路径
path="/root/monitor.txt"
#内存阈值
mem_mo='60'

#获取主机名
system_hostname=$(hostname | awk '{print $1}')
#获取服务器IP
system_ip=$(ip a|grep "global"|awk '{print $2}' |awk -F/ '{print $1}')
#获取服务器系统
system=$(cat /etc/os-release | grep "^NAME" | awk -F\" '{print $2}')
#获取服务器系统版本
version=$(cat /etc/redhat-release | awk '{print $4$5}')
#获取总内存
#free -m|awk '/Mem/ {printf ("%.f\n",$2/1024)}'
mem_total=$(free -m | grep Mem| awk -F " " '{print $2}')
#获取已用内存
mem_use=$(free -m | grep Mem| awk -F " " '{print $3}')
#获取可用内存
mem_free=$(free -m | grep "Mem" | awk '{print $7}')
#取CPU核数
Cpu_num=`grep processor /proc/cpuinfo|wc -l`
#cpu使用率
Cpu_use=`top -n 1 -b |grep 'Cpu(s)' |awk '{print $2}'`
#获取当前平均一分钟负载
load_1=`uptime | awk '{print $8}' | sed -e 's/\,//g' | awk -F " " '{print $1}'`
#获取当前平均五分钟负载
load_5=`uptime | awk '{print $9}' | sed -e 's/\,//g' | awk -F " " '{print $1}'`
#获取当前平均十五分钟负载
load_15=`uptime | awk '{print $10}'`
#磁盘I/O
disk_io=`iostat -d -x -k 1 1 | grep -Ev "^$|Linux|Device" |grep sda| awk '{print $1,$14"ms"}'`
#过滤磁盘使用率大于50%目录，并加入描述
disk_1=$(df -Ph | awk '{if(+$5>50) print "分区:"$1,"总空间:"$2,"使用空间:"$3,"剩余空间:"$4,"磁盘使用率:"$5}')
#拆分
#disk_fq=$(df -Ph | awk '{if(+$5>50) print "分区:"$1}')
#disk_to=$(df -Ph | awk '{if(+$5>50) print "总空间:"$2}')
#disk_us=$(df -Ph | awk '{if(+$5>50) print "使用空间:"$3}')
#disk_fe=$(df -Ph | awk '{if(+$5>50) print "剩余空间:"$4}')
#disk_ul=$(df -Ph | awk '{if(+$5>50) print "磁盘使用率:"$5}')
#disk_ux=$(df -Ph | awk '{if(+$5>50) print $5}')
disk_fq=$(df -h | grep "root" | awk '{print "分区:"$1}')
disk_to=$(df -Ph | grep "root" | awk '{print "总空间:"$2}')
disk_us=$(df -Ph | grep "root" | awk '{print "使用空间:"$3}')
disk_fe=$(df -Ph | grep "root" | awk '{print "剩余空间:"$4}')
disk_ul=$(df -Ph | grep "root" | awk '{print "磁盘使用率:"$5}')
disk_ux=$(df -Ph | grep "root" | awk '{print $5}')

echo -e " " > $path
echo -e "主机名:"$system_hostname >> $path
echo -e "服务器IP:"$system_ip >> $path
echo -e "服务器系统:"$system >> $path
echo -e "服务器系统版本:"$version >> $path
echo -e "总内存:"$mem_total >> $path
echo -e "已使用内存:"$mem_use >> $path
echo -e "可用内存:"$mem_free >> $path
echo -e "cpu核数:"$Cpu_num >> $path
echo -e "cpu使用率:"$Cpu_use >> $path
echo -e "磁盘IO:"$disk_io >> $path
if [[ $(echo $disk_ux | sed s/%//g) -gt 50 ]]
   then
    echo $disk_fq >>$path
    echo $disk_to >>$path
    echo $disk_us >>$path
    echo $disk_fe >>$path
    echo $disk_ul >>$path
    echo 磁盘巡检状态:不正常 >>$path
   else
    echo $disk_fq >>$path
    echo $disk_to >>$path
    echo $disk_us >>$path
    echo $disk_fe >>$path
    echo $disk_ul >>$path
    echo 磁盘巡检状态:正常 >>$path
 fi
PERCENT=$(printf "%d%%" $(($mem_use*100/$mem_total)))
PERCENT_1=$(echo $PERCENT|sed 's/%//g')
if [[ $PERCENT_1 -gt $mem_mo ]]
    then
     echo -e 总内存大小:$mem_total MB>> $path
     echo -e 已用内存:$mem_use MB >> $path
     echo -e 内存剩余大小:$mem_free MB >> $path
     echo -e 内存使用率:$PERCENT >> $path
     echo -e 内存巡检状态:不正常 >> $path
    else
     echo -e 总内存大小:$mem_total MB>> $path
     echo -e 已用内存:$mem_use MB >> $path
     echo -e 内存剩余大小:$mem_free MB >> $path
     echo -e 内存使用率:$PERCENT >> $path
     echo 内存巡检状态:正常 >> $path
fi
echo -e 平均1分钟负载:$load_1"\n"平均5分钟负载:$load_5"\n"平均15分钟:$load_15 >> $path