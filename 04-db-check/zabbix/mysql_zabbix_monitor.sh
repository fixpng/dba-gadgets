#!/bin/sh
source /etc/profile
[[ -f ~/.bash_profile ]] && source ~/.bash_profile

# zabbix mysql 监控脚本
# zabbix_agentd.d/mysql_monitor.conf
# UserParameter=mysql_monitor[*], /bin/bash /etc/zabbix/scripts/mysql_monitor.sh $1


#日志
function log(){

	sqlFile=/tmp/.mysql_monitor.sql  
	tempLog=/tmp/.mysql_monitor_tmp.log
	fullTempLog=/tmp/.mysql_monitor_full_tmp.log

	monitorLog=/tmp/.mysql_monitor.log
	monitorHistLog=/tmp/.mysql_monitor_hist.log

	touch ${sqlFile};     chmod 777 ${sqlFile} 2>/dev/null
	touch ${tempLog};     chmod 777 ${tempLog} 2>/dev/null
	touch ${fullTempLog}; chmod 777 ${fullTempLog} 2>/dev/null
	
	touch ${monitorLog};     chmod 777 ${monitorLog}   2>/dev/null
	touch ${monitorHistLog}; chmod 777 ${monitorHistLog} 2>/dev/null
}

#帮助
function help(){

	echo
	echo  "Usage:"
	echo  "    /bin/bash $0 check"
	echo  "    /bin/bash $0 discovery"
	echo  "    /bin/bash $0 port=xx check"
	echo  "    /bin/bash $0 port=xx item=xx"	
	echo
	exit 0
}

#实例发现函数
function discovery(){	

    port=$(awk -F'|' '{print $2}' ${monitorLog} 2>/dev/null|awk '{print $1}'|uniq)
    end=$(echo $port | awk '{print $NF}')

    echo '{'
    echo '  "data": ['

    for var in ${port[@]}
    do
        echo -e "   {\"{#PORT}\": \"${var}\"}\c"
        [[ ${var} != ${end} ]] && echo ","
    done

    echo '  ]'
    echo '}'
    exit 0	
}

#基本检查
function checkBasic(){

	mysql ${connect} -P${port} -NB -e "select 'mysql_alive',1 from dual;"
	
	conn_cur=$(mysql ${connect} -P${port} -NB -e "show status like 'Threads_connected';" |awk '{print $NF}')&& echo "conn_cur ${conn_cur}" 
	conn_max=$(mysql ${connect} -P${port} -NB -e "show variables like 'max_connections';"|awk '{print $NF}')&& echo "conn_max ${conn_max}" 
	echo "${conn_cur} ${conn_max} "|awk '{printf ( "conn_ratio " "%.0f\n",$1/$2*100)}'	
	
	mysql ${connect} -P${port} -NB -e "show status like 'Threads_running';"   |awk '{print "conn_active  " $NF}'	
	mysql ${connect} -P${port} -NB -e "select 'conn_active_sec' item,ifnull(max(time),count(*)) from information_schema.processlist where command not in ('Binlog Dump','Binlog Dump GTID','Sleep','Connect','Daemon') and user not in ('system user');"
	mysql ${connect} -P${port} -NB -e "select 'trans_active' item,count(*) from information_schema.innodb_trx where trx_state='RUNNING';"
	mysql ${connect} -P${port} -NB -e "select 'trans_active_sec' item,ifnull(max(p.time),count(*)) from information_schema.processlist p join information_schema.innodb_trx t on p.id=t.trx_mysql_thread_id where p.command <> 'Sleep' and t.trx_state='RUNNING';"
	mysql ${connect} -P${port} -NB -e "select 'trans_uncommited' item,count(*) from information_schema.processlist p join information_schema.innodb_trx t on p.id=t.trx_mysql_thread_id where p.command = 'Sleep' and t.trx_state='RUNNING';"
	mysql ${connect} -P${port} -NB -e "select 'trans_uncommited_sec' item,ifnull(max(p.time),count(*)) from information_schema.processlist p join information_schema.innodb_trx t on p.id=t.trx_mysql_thread_id where p.command = 'Sleep' and t.trx_state='RUNNING';"
	mysql ${connect} -P${port} -NB -e "select 'lock_flush_sec' item,ifnull(max(time),count(*)) from information_schema.processlist where state='Waiting for table flush';"
	mysql ${connect} -P${port} -NB -e "select 'lock_metadata_sec' item,ifnull(max(time),count(*)) from information_schema.processlist where state='Waiting for table metadata lock';"
	mysql ${connect} -P${port} -NB -e "select 'db_size_gb' item,round(sum((data_length+index_length)/1024/1024/1024)) as dbSize from information_schema.tables;"
	mysql ${connect} -P${port} -NB -e "select 'tab_no_primary_key' item,count(*) from information_schema.tables t1 left outer join information_schema.TABLE_CONSTRAINTS t2  on t1.table_schema = t2.TABLE_SCHEMA and t1.table_name = t2.TABLE_NAME and t2.CONSTRAINT_NAME in('PRIMARY') where t1.TABLE_SCHEMA not in ('information_schema','performance_schema','mysql','sys') and t2.table_name is null;"
}

#状态检查
function checkStatus(){

	statusBeforeLog=/tmp/.mysql${port}_status_before.log   && touch ${statusBeforeLog} && chmod 777 ${statusBeforeLog}  2>/dev/null
	statusCurrentLog=/tmp/.mysql${port}_status_current.log && touch ${statusCurrentLog}&& chmod 777 ${statusCurrentLog} 2>/dev/null

	echo "show global status"|mysql ${connect} -P${port} >${statusCurrentLog}

	if [[ -n $(grep -w Uptime ${statusBeforeLog}) ]];then
		interval=$(grep -w Uptime ${statusBeforeLog} ${statusCurrentLog}|awk '{print $NF}'|xargs|awk '{print ($2-$1)}')&&[[ ${interval} == 0 ]]&&interval=1;echo "interval ${interval}"
		grep -w Queries         ${statusBeforeLog} ${statusCurrentLog}|awk '{print $NF}'|xargs|awk -v interval="${interval:=1}" '{printf ("Queries "  "%.0f\n",($2-$1)/interval)}'
		grep -w Com_select      ${statusBeforeLog} ${statusCurrentLog}|awk '{print $NF}'|xargs|awk -v interval="${interval:=1}" '{printf ("select "   "%.0f\n",($2-$1)/interval)}'
		grep -w Com_delete      ${statusBeforeLog} ${statusCurrentLog}|awk '{print $NF}'|xargs|awk -v interval="${interval:=1}" '{printf ("delete "   "%.0f\n",($2-$1)/interval)}'
		grep -w Com_insert      ${statusBeforeLog} ${statusCurrentLog}|awk '{print $NF}'|xargs|awk -v interval="${interval:=1}" '{printf ("insert "   "%.0f\n",($2-$1)/interval)}'
		grep -w Com_update      ${statusBeforeLog} ${statusCurrentLog}|awk '{print $NF}'|xargs|awk -v interval="${interval:=1}" '{printf ("update "   "%.0f\n",($2-$1)/interval)}'
		grep -w Com_begin       ${statusBeforeLog} ${statusCurrentLog}|awk '{print $NF}'|xargs|awk -v interval="${interval:=1}" '{printf ("begin "    "%.0f\n",($2-$1)/interval)}'		
		grep -w Com_commit      ${statusBeforeLog} ${statusCurrentLog}|awk '{print $NF}'|xargs|awk -v interval="${interval:=1}" '{printf ("commit "   "%.0f\n",($2-$1)/interval)}'		
		grep -w Com_rollback    ${statusBeforeLog} ${statusCurrentLog}|awk '{print $NF}'|xargs|awk -v interval="${interval:=1}" '{printf ("rollback " "%.0f\n",($2-$1)/interval)}'
		grep -w Com_dealloc_sql ${statusBeforeLog} ${statusCurrentLog}|awk '{print $NF}'|xargs|awk -v interval="${interval:=1}" '{printf ("deallock " "%.0f\n",($2-$1)/interval)}'		
		grep -w Bytes_sent      ${statusBeforeLog} ${statusCurrentLog}|awk '{print $NF}'|xargs|awk -v interval="${interval:=1}" '{printf ("net_sent_kb " "%.0f\n",($2-$1)/interval/1024)}'	
		grep -w Bytes_received  ${statusBeforeLog} ${statusCurrentLog}|awk '{print $NF}'|xargs|awk -v interval="${interval:=1}" '{printf ("net_received_kb " "%.0f\n",($2-$1)/interval/1024)}'

		grep MemTotal /proc/meminfo | awk '{printf "mem_max_size_gb " "%.0f\n",$2/1024/1024}'
		max_buffer_size=$(grep -w Innodb_buffer_pool_pages_total ${statusCurrentLog}|awk '{printf "%.0f\n", $2*16/1024/1024}') && echo "buffer_max_size_gb ${max_buffer_size}"
		free_buffer_size=$(grep -w Innodb_buffer_pool_pages_free ${statusCurrentLog}|awk '{printf "%.0f\n", $2*16/1024/1024}') 
		echo "${free_buffer_size} ${max_buffer_size}"|awk '{ print "buffer_used_size_gb " ($2-$1) }'
		echo "${free_buffer_size} ${max_buffer_size}"|awk '{printf("buffer_used_ratio " "%.0f\n", ($2-$1)/$2*100)}'
	fi

	echo "show global status"|mysql ${connect} -P${port} >${statusBeforeLog}	
	

	(echo "show slave status\G;"|mysql ${connect} -P${port}|grep -w "Seconds_Behind_Master:"|| echo 0)|awk '{print "replica_delay_sec " $NF}'
	echo "show slave status\G;" |mysql ${connect} -P${port}|grep -w "Slave_IO_Running:" |grep -c No|awk '{print "error_io_thread  " $1}'
	echo "show slave status\G;" |mysql ${connect} -P${port}|grep -w "Slave_SQL_Running:"|grep -c No|awk '{print "error_sql_thread " $1}'		
	
}

#调用函数
function check(){

	#清理日志记录
	> ${fullTempLog}

	for port in ${portList[@]}
	do
		connect="--login-path=${port}"
		mysql ${connect} -P${port} -NB -e "select 'mysql_alive',1 from dual;"&>/dev/null
		[[ $? != 0 ]]&& echo "ERROR 1045 (28000): Access denied for: mysql ${connect} -P${port}" \
		&& echo "$(date "+%Y-%m-%d %H:%M:%S") | ${port} | mysql_alive 0" >> ${fullTempLog} && break

		checkBasic   >${tempLog}
		checkStatus >>${tempLog}

		#将时间写入日志中
		sed  -i "s/^/$(date "+%Y-%m-%d %H:%M:%S") | ${port} | &/g" ${tempLog}&&cat ${tempLog} >> ${fullTempLog}
	done

	#将记录对齐并写入日志记录文件中
	cat ${fullTempLog}|column -t > ${monitorLog}

	#将记录写入历史日志记录文件中
	cat ${monitorLog} && cat ${monitorLog} >> ${monitorHistLog}

	#清除超过30天的历史记录
	old_record_time=$(head -n 1 ${monitorHistLog} 2>/dev/null|awk '{print $1}')
	[[ $(date +%Y%m%d --date='30 days ago') > ${old_record_time//-/} ]] && sed -i "/^${old_record_time}/"d  ${monitorHistLog} 2>/dev/null
}

#主函数
function main(){

	unalias mysql &>/dev/null
	portList=$(netstat -anp 2>/dev/null| grep -w mysqld | grep -w LISTEN | awk '{print $4}'| awk -F ':' '{print $NF}' |  tail -n 1)

	for i in $@
	do
		case $i in

		check*) check && exit 0	
		;;

		discovery) discovery && exit 0	
		;;

		port*) portList=$(echo $i | awk -F = '{print $2}'|sed "s/,/ /g")
			[[ -z ${portList} ]] && echo "keyword: \" port \" don't have value " && exit 1
		;;

		item*) item=$(echo $i | awk -F = '{print $2}')  
			[[ -z ${item} ]] && echo "keyword: \" item \" don't have value" && exit 1
		;;

		*) echo "keyword: \" $i \" not found " && exit 1
		;;
		esac
	done

	[[ -z $@ ]] && help
	[[ -n ${portList} ]] && [[ ${item} == check_interval ]] && echo $(date +%s -d "$(head -n1 ${monitorLog}|awk '{print $1" " $2}')")  $(date +%s)|awk '{print $2-$1}'
	[[ -n ${portList} ]] && [[ -n ${item} ]] && grep -w ${portList} ${monitorLog}|awk -F '|' '{print $NF}'|sed 's/^[ \t]*//g'|grep -w ^${item}|sort -k2,2nr|head -n 1|awk '{print $NF}'
}

log
main $*
