#!/bin/bash
# MySQL状态转储脚本
# 此脚本收集MySQL数据库状态信息，包括进程列表、引擎状态、事务和锁信息
# 每分钟通过cron运行一次，并按端口和数据类型组织存储日志
#
# 使用方法:
#   1. 将此脚本放在 /root/scripts/ (或相应修改 work_dir 变量)
#   2. 为每个要监控的MySQL实例设置MySQL login-paths
#      示例: mysql_config_editor set --login-path=3306 --host=localhost --user=root --port=3306
#   3. 添加到crontab: * * * * * /bin/bash /root/scripts/mysql_state_dump.sh &> /root/scripts/mysql_state_dump.log
#   4. 脚本将自动检测正在运行的MySQL实例并收集其状态
#   5. 日志存储在 /opt/log/[端口]/ 下，不同数据类型有子目录
#   6. 日志轮转保留30天的数据，然后清理旧文件
# 
# 输出目录:
#   /opt/log/[端口]/processlist/ - 包含进程列表信息
#   /opt/log/[端口]/engine/ - 包含InnoDB引擎状态
#   /opt/log/[端口]/trx/ - 包含活动事务信息
#   /opt/log/[端口]/lock/ - 包含锁信息（基于MySQL版本）
#
# crontab 条目:
# * * * * * /bin/bash /root/scripts/mysql_state_dump.sh &> /root/scripts/mysql_state_dump.log

. /etc/profile

## 配置参数
date_time=`date +%Y%m%d`  # 日志文件的日期格式
base_log_dir='/opt/log'    # 所有日志的基础目录
work_dir='/root/scripts'   # 脚本所在目录


# 获取当前运行的MySQL实例端口
db_ports=`ps -ef | grep -v -E "mysqld_safe|awk" | awk '/mysqld /,/port=/''{for(i=1;i<=NF;i++){if($i~/port=/) print gsub(/--port=/,""),$i}}' | awk '{print $2}'`

for db_port in $db_ports
do
    ## 设置日志目录
    log_dir=$base_log_dir/$db_port
    if [ ! -d $log_dir/processlist ];then
        mkdir -p $log_dir/{processlist,engine,trx,lock}
    fi

    ## 收集状态信息
    # 基础信息
    mysql --login-path=$db_port -e "select current_timestamp(3) start_time; select * from information_schema.processlist where info is not null ORDER BY time desc" >> $log_dir/processlist/$date_time.txt
    mysql --login-path=$db_port -e "select current_timestamp(3) start_time; show engine innodb status" >> $log_dir/engine/$date_time.txt
    mysql --login-path=$db_port -e "select current_timestamp(3) start_time; SELECT t.*,e.SQL_TEXT FROM information_schema.innodb_trx t LEFT JOIN PERFORMANCE_SCHEMA.threads x ON t.trx_mysql_thread_id = x.processlist_id LEFT JOIN PERFORMANCE_SCHEMA.events_statements_current e ON x.thread_id = e.thread_id" >> $log_dir/trx/$date_time.txt

    # 根据MySQL版本收集锁信息
    ver=`mysql --login-path=$db_port -NB -e "select SUBSTRING_INDEX(@@version,'.',2);"`
    if [ $ver = '8.0' ];then
        # MySQL 8.0 版本的锁查询
        mysql --login-path=$db_port -e "select current_timestamp(3) start_time; select * from sys.innodb_lock_waits select * from performance_schema.metadata_locks" >> $log_dir/lock/$date_time.txt
    elif [ $ver = '5.7' ];then
        # MySQL 5.7 版本的锁查询
        mysql --login-path=$db_port -e "select current_timestamp(3) start_time; select * from sys.innodb_lock_waits" >> $log_dir/lock/$date_time.txt
    else
        # MySQL 5.6及更早版本的锁查询
        mysql --login-path=$db_port -e "select current_timestamp(3) start_time; SELECT r.trx_id waiting_trx_id,r.trx_mysql_thread_id waiting_thread,TIMESTAMPDIFF(SECOND,r.trx_wait_started,CURRENT_TIMESTAMP) wait_time,r.trx_query waiting_query,l.lock_table waiting_table_lock,b.trx_id blocking_trx_id,b.trx_mysql_thread_id blocking_thread,SUBSTRING(p.HOST,1,INSTR(p. HOST, ':') -1 ) blocking_host,SUBSTRING(p. HOST, INSTR(p. HOST, ':') +1) blocking_port,IF (p.COMMAND = 'Sleep', p.TIME, 0) idel_in_trx,b.trx_query blocking_query FROM information_schema.INNODB_LOCK_WAITS w INNER JOIN information_schema.INNODB_TRX b ON b.trx_id = w.blocking_trx_id INNER JOIN information_schema.INNODB_TRX r ON r.trx_id = w.requesting_trx_id INNER JOIN information_schema.INNODB_LOCKS l ON w.requested_lock_id = l.lock_id LEFT JOIN information_schema. PROCESSLIST p ON p.ID = b.trx_mysql_thread_id ORDER BY wait_time DESC" >> $log_dir/lock/$date_time.txt
    fi

    ## 清理超过30天的日志文件
    find $log_dir/processlist -mtime +30 -exec rm -f  {} \;
    find $log_dir/engine -mtime +30 -exec rm -f  {} \;
    find $log_dir/trx -mtime +30 -exec rm -f  {} \;
    find $log_dir/lock -mtime +30 -exec rm -f  {} \;
done

## profile
date_time=`date +%Y%m%d`
base_log_dir='/opt/log'
work_dir='/root/scripts'


db_ports=`ps -ef | grep -v -E "mysqld_safe|awk" | awk '/mysqld /,/port=/''{for(i=1;i<=NF;i++){if($i~/port=/) print gsub(/--port=/,""),$i}}' | awk '{print $2}'`

for db_port in $db_ports
do
    ## log_dir
    log_dir=$base_log_dir/$db_port
    if [ ! -d $log_dir/processlist ];then
        mkdir -p $log_dir/{processlist,engine,trx,lock}
    fi

    ## state dump
    # base
    mysql --login-path=$db_port -e "select current_timestamp(3) start_time; select * from information_schema.processlist where info is not null ORDER BY time desc" >> $log_dir/processlist/$date_time.txt
    mysql --login-path=$db_port -e "select current_timestamp(3) start_time; show engine innodb status" >> $log_dir/engine/$date_time.txt
    mysql --login-path=$db_port -e "select current_timestamp(3) start_time; SELECT t.*,e.SQL_TEXT FROM information_schema.innodb_trx t LEFT JOIN PERFORMANCE_SCHEMA.threads x ON t.trx_mysql_thread_id = x.processlist_id LEFT JOIN PERFORMANCE_SCHEMA.events_statements_current e ON x.thread_id = e.thread_id" >> $log_dir/trx/$date_time.txt

    # for version
    ver=`mysql --login-path=$db_port -NB -e "select SUBSTRING_INDEX(@@version,'.',2);"`
    if [ $ver = '8.0' ];then
        mysql --login-path=$db_port -e "select current_timestamp(3) start_time; select * from sys.innodb_lock_waits select * from performance_schema.metadata_locks" >> $log_dir/lock/$date_time.txt
    elif [ $ver = '5.7' ];then
        mysql --login-path=$db_port -e "select current_timestamp(3) start_time; select * from sys.innodb_lock_waits" >> $log_dir/lock/$date_time.txt
    else
        mysql --login-path=$db_port -e "select current_timestamp(3) start_time; SELECT r.trx_id waiting_trx_id,r.trx_mysql_thread_id waiting_thread,TIMESTAMPDIFF(SECOND,r.trx_wait_started,CURRENT_TIMESTAMP) wait_time,r.trx_query waiting_query,l.lock_table waiting_table_lock,b.trx_id blocking_trx_id,b.trx_mysql_thread_id blocking_thread,SUBSTRING(p.HOST,1,INSTR(p. HOST, ':') -1 ) blocking_host,SUBSTRING(p. HOST, INSTR(p. HOST, ':') +1) blocking_port,IF (p.COMMAND = 'Sleep', p.TIME, 0) idel_in_trx,b.trx_query blocking_query FROM information_schema.INNODB_LOCK_WAITS w INNER JOIN information_schema.INNODB_TRX b ON b.trx_id = w.blocking_trx_id INNER JOIN information_schema.INNODB_TRX r ON r.trx_id = w.requesting_trx_id INNER JOIN information_schema.INNODB_LOCKS l ON w.requested_lock_id = l.lock_id LEFT JOIN information_schema. PROCESSLIST p ON p.ID = b.trx_mysql_thread_id ORDER BY wait_time DESC" >> $log_dir/lock/$date_time.txt
    fi

    ## log clean
    find $log_dir/processlist -mtime +30 -exec rm -f  {} \;
    find $log_dir/engine -mtime +30 -exec rm -f  {} \;
    find $log_dir/trx -mtime +30 -exec rm -f  {} \;
    find $log_dir/lock -mtime +30 -exec rm -f  {} \;
done
