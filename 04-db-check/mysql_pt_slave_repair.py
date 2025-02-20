import re, time, os, sys
import pymysql
from pymysql.constants import CLIENT
from mysql_reverse_sql import *
from pymysqlreplication.event import GtidEvent
import argparse
import signal
import logging

'''
pt-slave-repair是对原有pt-slave-restart工具的补充，它提供自动修复MySQL主从同步复制的报错数据，以及恢复中断的sql thread复制线程。
https://github.com/hcymysql/pt-slave-repair

pip3 install --upgrade python-daemon pymysql mysql-replication  -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com/pypi/simple/

# 原理
# 1） 当检测到同步报错1062（主键冲突、重复）和1032（数据丢失）时，首先要进行binlog环境检查，如果binlog_format不等于ROW并且binlog_row_image不等于FULL，则退出主程序。
#     如果错误号非1062或1032，则直接退出主程序。
# 2） 获取show slave status信息，得到binlog、position、gtid信息
# 3） 连接到主库上解析binlog，如果是DELETE删除语句，则直接跳过
# 4)  关闭slave_parallel_workers多线程并行复制
# 5)  如果开启GITD复制模式，启用SET gtid_next方式；如果开启位置点复制模式，启动SET GLOBAL SQL_SLAVE_SKIP_COUNTER=1方式）
# 6） 如果是UPDATE/INSERT语句，则把BINLOG解析为具体的SQL，并且反转SQL，将其转换为REPLACE INTO
# 7） 将解析后的REPLACE INTO语句反向插入slave上，使其数据保持一致，然后执行第5步操作；
# 8） 将slave设置为read_only只读模式
# 9） 依次类推，最终使其show slave status同步为双YES（同步正常）。

# repl账号最小化权限
GRANT SUPER, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO `repl`@`%`;
GRANT SELECT, INSERT, UPDATE, DELETE ON `yourDB`.* TO `repl`@`%`;
GRANT SELECT ON `performance_schema`.* TO `repl`@`%`;

# 连接到同步报错的slave从库上执行（请用MySQL复制的账号，例如repl，并赋予工具运行的权限）
# 后台运行
nohup python3 ./mysql_pt_slave_repair.py -H 127.0.0.1 -P 3316 -u repl -p repl12345* -d test > /dev/null &

# -e, --enable-binlog Enable binary logging of the restore data
# 1) -e 选项，默认修复完的数据不会记录在binlog文件里，如果你的slave是二级从库（后面还接着一个slave），那么开启这个选项。
# 2) 开启后台守护进程后，会自动在当前目录下创建一个log目录和{db_name}_INFO.log文件，该文件保存着日志信息。
'''

# 创建ArgumentParser对象
parser = argparse.ArgumentParser(description=
"""
自动修复MySQL主从同步报错数据 \n
 - The automatic repair of data synchronization errors(1032/1062) between MySQL master and slave. 
""", formatter_class=argparse.RawTextHelpFormatter)

# 添加命令行参数
parser.add_argument('-H', '--slave_ip', type=str, help='Slave IP', required=True)
parser.add_argument('-P', '--slave_port', type=int, help='Slave Port', required=True)
parser.add_argument('-u', '--slave_user', type=str, help='Slave Repl User', required=True)
parser.add_argument('-p', '--slave_password', type=str, help='Slave Repl Password', required=True)
parser.add_argument('-d', '--db_name', type=str, help='Your Database Name', required=True)
parser.add_argument('-e', '--enable-binlog', dest='enable_binlog', action='store_true', default=False, help='Enable binary logging of the restore data')
parser.add_argument('-v', '--version', action='version', version='pt-slave-repair工具版本号: 1.0.8，更新日期：2024-08-13')

# 解析命令行参数
args = parser.parse_args()

# 获取变量值
slave_ip = args.slave_ip
slave_port = args.slave_port
slave_user = args.slave_user
slave_password = args.slave_password
enable_binlog = args.enable_binlog
db_name = args.db_name

# 获取当前脚本所在目录（包括打包后的情况）
if getattr(sys, 'frozen', False):
    # 打包后的情况
    current_dir = os.path.dirname(sys.executable)
else:
    # 未打包的情况
    current_dir = os.path.dirname(os.path.abspath(__file__))


# 创建log目录（如果不存在）
log_dir = os.path.join(current_dir, "log")
if not os.path.exists(log_dir):
    os.makedirs(log_dir)

# 设置日志文件路径为log目录下的文件
log_file_path = os.path.join(log_dir, f"{db_name}_INFO.log")

# 创建日志处理器
logger = logging.getLogger()
logger.setLevel(logging.INFO)

file_handler = logging.FileHandler(log_file_path)
file_handler.setLevel(logging.INFO)
log_formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
file_handler.setFormatter(log_formatter)
logger.addHandler(file_handler)

console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
log_formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
console_handler.setFormatter(log_formatter)
logger.addHandler(console_handler)


def signal_handler(sig, frame):
    logger.info('程序被终止')
    sys.exit(0)

# 注册信号处理函数
signal.signal(signal.SIGINT, signal_handler)  # Ctrl+C
signal.signal(signal.SIGTSTP, signal_handler)  # Ctrl+Z


class MySQL_Check(object):
    def __init__(self, host, port, user, password):
        self._host = host
        self._port = int(port)
        self._user = user
        self._password = password
        self._connection = None
        try:
            self._connection = pymysql.connect(host=self._host, port=self._port, user=self._user, passwd=self._password)
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
            sys.exit('error! MySQL can\'t connect!')


    def chek_repl_status(self):
        cursor = self._connection.cursor()

        try:
            if cursor.execute('SHOW SLAVE HOSTS') >= 1 and cursor.execute('SHOW SLAVE STATUS') == 0:
                print(f"{self._host}:{self._port} 这是一台主库，环境不匹配！")
                sys.exit(2)
            elif cursor.execute('SHOW SLAVE HOSTS') == 0 and cursor.execute('SHOW SLAVE STATUS') == 1:
                #print(f"cursor.execute('SHOW SLAVE HOSTS'):  {cursor.execute('SHOW SLAVE HOSTS')}")
                #print("这是一台从库")
                pass
            elif cursor.execute('SHOW SLAVE HOSTS') >= 1 and cursor.execute('SHOW SLAVE STATUS') == 1:
                pass
            else:
                print(f"{self._host}:{self._port} 这台机器你没有设置主从复制，环境不匹配！")
                sys.exit(2)
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
            sys.exit('MySQL Replication Health is NOT OK!')
        finally:
            cursor.close()


    def get_slave_status(self):
        cursor = self._connection.cursor(cursor=pymysql.cursors.DictCursor)  # 以字典的形式返回操作结果

        try:
            cursor.execute('SHOW SLAVE STATUS')
            slave_status_dict = cursor.fetchone()
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
        finally:
            cursor.close()

        return slave_status_dict


    def get_gtid_status(self):
        cursor = self._connection.cursor()

        try:
            cursor.execute('SHOW GLOBAL VARIABLES WHERE variable_name = \'gtid_mode\'')
            gtid_result = cursor.fetchone()
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
        finally:
            cursor.close()

        return gtid_result


    def get_para_workers(self):
        cursor = self._connection.cursor()

        try:
            cursor.execute('SHOW GLOBAL VARIABLES WHERE variable_name = \'slave_parallel_workers\'')
            s_workers_result = cursor.fetchone()
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
        finally:
            cursor.close()

        return s_workers_result


    def turn_off_parallel(self):
        self._connection = pymysql.connect(host=self._host, port=self._port, user=self._user, passwd=self._password, client_flag=CLIENT.MULTI_STATEMENTS)
        cursor = self._connection.cursor()

        try:
            cursor.execute('STOP SLAVE SQL_THREAD; SET GLOBAL slave_parallel_workers = 0; START SLAVE SQL_THREAD')
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
            return False
        finally:
            cursor.close()

        return True


    def turn_on_parallel(self, slave_parallel_workers):
        self._connection = pymysql.connect(host=self._host, port=self._port, user=self._user, passwd=self._password, client_flag=CLIENT.MULTI_STATEMENTS)
        cursor = self._connection.cursor()

        try:
            cursor.execute(f'STOP SLAVE SQL_THREAD; SET GLOBAL slave_parallel_workers = {slave_parallel_workers}; START SLAVE SQL_THREAD')
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
            return False
        finally:
            cursor.close()

        return True


    def get_slave_error(self):
        cursor = self._connection.cursor(cursor=pymysql.cursors.DictCursor)  # 以字典的形式返回操作结果

        try:
            cursor.execute('select LAST_ERROR_NUMBER,LAST_ERROR_MESSAGE,LAST_ERROR_TIMESTAMP '
                           'from performance_schema.replication_applier_status_by_worker '
                           'ORDER BY LAST_ERROR_TIMESTAMP desc limit 1')
            error_dict = cursor.fetchone()
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
        finally:
            cursor.close()

        return error_dict


    def fix_error_enable_binlog(self, repair_sql):
        cursor = self._connection.cursor()
        affected_rows = 0

        try:
            # 开始事务
            self._connection.begin()

            cursor.execute(repair_sql)
            affected_rows = cursor.rowcount

            # 提交事务
            self._connection.commit()
        except pymysql.Error as e:
            # 回滚事务
            self._connection.rollback()
            print("Error %d: %s" % (e.args[0], e.args[1]))
        finally:
            cursor.close()

        return affected_rows


    def fix_error_disable_binlog(self, repair_sql):
        cursor = self._connection.cursor()
        affected_rows = 0

        try:
            cursor.execute("SET SESSION SQL_LOG_BIN = OFF")  # 在事务外设置 sql_log_bin 的值
            # 开始事务
            self._connection.begin()
            cursor.execute(repair_sql)
            affected_rows = cursor.rowcount

            # 提交事务
            self._connection.commit()
        except pymysql.Error as e:
            # 回滚事务
            self._connection.rollback()
            print("Error %d: %s" % (e.args[0], e.args[1]))
        finally:
            cursor.close()

        return affected_rows


    def unset_super_read_only(self):
        self._connection = pymysql.connect(host=self._host, port=self._port, user=self._user, passwd=self._password)
        cursor = self._connection.cursor()
        try:
            cursor.execute('SET GLOBAL SUPER_READ_ONLY = 0')
            cursor.execute('SET GLOBAL READ_ONLY = 0')
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
            return False
        finally:
            cursor.close()
        return True


    def set_super_read_only(self):
        self._connection = pymysql.connect(host=self._host, port=self._port, user=self._user, passwd=self._password)
        cursor = self._connection.cursor()
        try:
            cursor.execute('SET GLOBAL SUPER_READ_ONLY = 1')
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
            return False
        finally:
            cursor.close()
        return True


    def skip_gtid(self, gtid_value):
        self._connection = pymysql.connect(host=self._host, port=self._port, user=self._user, passwd=self._password, client_flag=CLIENT.MULTI_STATEMENTS)
        cursor = self._connection.cursor()
        try:
            skip_gtid_sql = 'STOP SLAVE; SET gtid_next = \'{0}\'; BEGIN;COMMIT; SET gtid_next = \'AUTOMATIC\' ' \
                         .format(gtid_value)
            cursor.execute(skip_gtid_sql)
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
            return False
        finally:
            cursor.close()

        return True


    def skip_position(self):
        self._connection = pymysql.connect(host=self._host, port=self._port, user=self._user, passwd=self._password, client_flag=CLIENT.MULTI_STATEMENTS)
        cursor = self._connection.cursor()
        try:
            skip_pos_sql = 'STOP SLAVE; SET GLOBAL SQL_SLAVE_SKIP_COUNTER=1'
            cursor.execute(skip_pos_sql)
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
            return False
        finally:
            cursor.close()

        return True


    def start_slave(self):
        self._connection = pymysql.connect(host=self._host, port=self._port, user=self._user, passwd=self._password)
        cursor = self._connection.cursor()
        try:
            start_slave_sql = 'START SLAVE'
            cursor.execute(start_slave_sql)
        except pymysql.Error as e:
            print("Error %d: %s" % (e.args[0], e.args[1]))
            return False
        finally:
            cursor.close()

        return True

mysql_conn = MySQL_Check(host=slave_ip, port=slave_port, user=slave_user, password=slave_password)

def parsing_binlog(mysql_host=None, mysql_port=None, mysql_user=None, mysql_passwd=None,
         mysql_database=None, mysql_charset=None, binlog_file=None, binlog_pos=None, gtid_event=None):

    #print(f"gtid_event: {gtid_event}")
    gtid_server_uuid, gtid_number = gtid_event.split(":")
    gtid_number_next = int(gtid_number) + 1

    source_mysql_settings = {
        "host": mysql_host,
        "port": mysql_port,
        "user": mysql_user,
        "passwd": mysql_passwd,
        "database": mysql_database,
        "charset": mysql_charset
    }

    stream = BinLogStreamReader(
        connection_settings=source_mysql_settings,
        server_id=1234567890,
        blocking=False,
        resume_stream=True,
        only_events=[WriteRowsEvent, UpdateRowsEvent, DeleteRowsEvent, GtidEvent],
        log_file=binlog_file,
        log_pos=int(binlog_pos)
    )

    sql_r = []
    found_target = False

    for binlogevent in stream:
        if isinstance(binlogevent, GtidEvent):
            if binlogevent.gtid == gtid_event:
                found_target = True
                #print(f"found_target: {found_target}")
            elif found_target and binlogevent.gtid == f"{gtid_server_uuid}:{gtid_number_next}":
                break

        if found_target and isinstance(binlogevent, (WriteRowsEvent, UpdateRowsEvent, DeleteRowsEvent)):
            result = process_binlogevent(binlogevent)
            sql_r.extend(result)
 
    stream.close()
    #print(sql_r)
    return sql_r

ok_count = 0
while True:
    mysql_conn.chek_repl_status()

    # 检测show slave status同步状态
    r_dict = mysql_conn.get_slave_status()

    # 获取GTID状态
    r_gtid = mysql_conn.get_gtid_status()
    r_gtid = r_gtid[1].upper()

    # 获取slave_parallel_workers线程数量
    slave_workers = mysql_conn.get_para_workers()
    slave_workers = int(slave_workers[1])

    if r_dict['Slave_IO_Running'] == 'Yes' and r_dict['Slave_SQL_Running'] == 'Yes':
        ok_count += 1
        if ok_count < 2:
            if r_gtid == "ON" and r_dict['Auto_Position'] != 1:
                logger.warning('\033[1;33m开启基于GTID全局事务ID复制，CHANGE MASTER TO MASTER_AUTO_POSITION = 1 需要设置为1. \033[0m')
            logger.info('\033[1;36m同步正常. \033[0m')

    elif (r_dict['Slave_IO_Running'] == 'Yes' and r_dict['Slave_SQL_Running'] == 'No') \
            or (r_dict['Slave_IO_Running'] == 'No' and r_dict['Slave_SQL_Running'] == 'No'):
        logger.error('\033[1;31m主从复制报错. Slave_IO_Running状态值是：%s '
                      ' |  Slave_SQL_Running状态值是：%s  \n  \tLast_Error错误信息是：%s'
                      '  \n\n  \tLast_SQL_Error错误信息是：%s \033[0m' \
                      % (r_dict['Slave_IO_Running'], r_dict['Slave_SQL_Running'], \
                         r_dict['Last_Error'], r_dict['Last_SQL_Error']))
        error_dict = mysql_conn.get_slave_error()
        if error_dict is not None: # 判断performance_schema参数是否开启
            logger.error('错误号是：%s' % error_dict['LAST_ERROR_NUMBER'])
            logger.error('错误信息是：%s' % error_dict['LAST_ERROR_MESSAGE'])
            logger.error('报错时间是：%s\n' % error_dict['LAST_ERROR_TIMESTAMP'])
        logger.info('-' * 100)
        logger.info('开始自动修复同步错误的数据......\n')

        # binlog环境检查
        check_binlog_settings(mysql_host=slave_ip, mysql_port=slave_port, mysql_user=slave_user,
                              mysql_passwd=slave_password, mysql_charset="utf8mb4")

        # 获取slave info信息
        master_host = r_dict['Master_Host']
        master_user = r_dict['Master_User']
        master_port = int(r_dict['Master_Port'])
        relay_master_log_file = r_dict['Relay_Master_Log_File']
        exec_master_log_pos = r_dict['Exec_Master_Log_Pos']
        retrieved_gtid_set = r_dict['Retrieved_Gtid_Set']
        executed_gtid_set = r_dict['Executed_Gtid_Set']
        last_sql_errno = int(r_dict['Last_SQL_Errno'])
        #print(f"retrieved_gtid_set: {retrieved_gtid_set}")
        #print(f"executed_gtid_set: {executed_gtid_set}")

        executed_gtid_list = []
        # 提取每个 GTID 的集合
        retrieved_gtid_list = re.findall(r'(\w+-\w+-\w+-\w+-\w+:\d+-\d+|\w+-\w+-\w+-\w+-\w+:\d+)', retrieved_gtid_set)
        if executed_gtid_set == "" or executed_gtid_set is None:
            executed_gtid_list = [retrieved_gtid_set]
        else:
            executed_gtid_list = re.findall(r'(\w+-\w+-\w+-\w+-\w+:\d+-\d+|\w+-\w+-\w+-\w+-\w+:\d+)', executed_gtid_set)
        #print(f"retrieved_gtid_list: {retrieved_gtid_list}")
        #print(f"executed_gtid_list: {executed_gtid_list}") #调试

        gtid_domain = None
        gtid_range_value = None
        gtid_range = None
        gtid_number = 0

        # 检查 Executed_Gtid_Set 是否在 Retrieved_Gtid_Set 中
        for gtid in executed_gtid_list:
            if any(gtid.split(':')[0] in retrieved for retrieved in retrieved_gtid_list):
                gtid_parts = gtid.split(':')
                gtid_domain = gtid_parts[0]
                gtid_range = gtid_parts[1]

                if '-' in gtid_range:
                    gtid_range_parts = gtid_range.split('-')
                    gtid_range_value = gtid_range_parts[-1]

        # 获取修复数据的SQL语句
        if last_sql_errno in (1062, 1032):
            if gtid_range is not None and '-' not in str(gtid_range):
                gtid_number = int(gtid_range) + 1
            if gtid_range_value is not None:
                gtid_number = int(gtid_range_value) + 1
            gtid_TXID = f"{gtid_domain}:{gtid_number}"

            try:
                repair_sql_list = parsing_binlog(mysql_host=master_host, mysql_port=master_port, mysql_user=master_user, mysql_passwd=slave_password,
                                    mysql_charset='utf8mb4', binlog_file=relay_master_log_file, binlog_pos=exec_master_log_pos, gtid_event=gtid_TXID)
                if repair_sql_list is None:
                    logger.error("没有捕获到正确的GTID事件，请检查change master to的时候master_auto_position是等于1吗？show slave status看看Auto_Position的值是不是为1。")
                    sys.exit(1)
            except Exception as e:
                # 在捕获到异常时使用 sys.exit() 终止程序
                logger.error(f"An error occurred: {str(e)}")
                sys.exit(1)
            for count, repair_sql in enumerate(repair_sql_list, 1):
                logger.info(f"修复数据的SQL语句: {repair_sql}")

                # 判断修复数据的SQL是否有DELETE
                pattern = re.compile(r'^delete', re.IGNORECASE)
                if pattern.match(repair_sql): #如果匹配上了DELETE，直接跳过错误，不做处理。
                    # 判断从库是否开启了基于GTID的复制
                    if r_gtid != "ON": #基于Position位置点复制
                        mysql_conn.turn_off_parallel()
                        time.sleep(0.3)
                        skip_pos_r = mysql_conn.skip_position()
                        if skip_pos_r:
                            logger.info("成功修复了 【%d】 行数据" % count)

                    else: #基于GTID事务号复制
                        if gtid_range is not None and '-' not in str(gtid_range):
                            gtid_number = int(gtid_range) + 1
                        if gtid_range_value is not None:
                            gtid_number = int(gtid_range_value) + 1
                        gtid_TXID = f"{gtid_domain}:{gtid_number}"

                        """
                        参考pt-slave-restart实现原理，要关闭多线程并行复制，然后再跳过出错的GTID事件号。
                        pt-slave-restart will not skip transactions when multiple replication threads are being used (slave_parallel_workers > 0). 
                        pt-slave-restart does not know what the GTID event is of the failed transaction of a specific slave thread. 
                        """
                        mysql_conn.turn_off_parallel()
                        time.sleep(0.3)

                        # 跳过出错的GTID事件号
                        skip_gtid_r = mysql_conn.skip_gtid(gtid_TXID)
                        if skip_gtid_r:
                            count += 1
                            logger.info("成功修复了 【%d】 行数据" % count)

                else: #如果匹配上了UPDATE/INSERT，修复错误数据。
                    # 先关闭只读
                    mysql_conn.unset_super_read_only()
                    if enable_binlog:
                        try:
                            fix_result = mysql_conn.fix_error_enable_binlog(repair_sql)
                        except Exception as e:
                            # 在捕获到异常时使用 sys.exit() 终止程序
                            logger.error(f"An error occurred: {str(e)}")
                            sys.exit(1)
                    else:
                        try:
                            fix_result = mysql_conn.fix_error_disable_binlog(repair_sql)
                        except Exception as e:
                            # 在捕获到异常时使用 sys.exit() 终止程序
                            logger.error(f"An error occurred: {str(e)}")
                            sys.exit(1)
                    if fix_result > 0:
                        # 判断从库是否开启了基于GTID的复制
                        if r_gtid != "ON":  # 基于Position位置点复制
                            mysql_conn.turn_off_parallel()
                            time.sleep(0.3)
                            skip_pos_r = mysql_conn.skip_position()
                            if skip_pos_r:
                                logger.info("成功修复了 【%d】 行数据" % count)
                        else:  # 基于GTID事务号复制
                            if gtid_range is not None and '-' not in str(gtid_range):
                                gtid_number = int(gtid_range) + 1
                            if gtid_range_value is not None:
                                gtid_number = int(gtid_range_value) + 1
                            gtid_TXID = f"{gtid_domain}:{gtid_number}"

                            """
                            参考pt-slave-restart实现原理，要关闭多线程并行复制，然后再跳过出错的GTID事件号。
                            pt-slave-restart will not skip transactions when multiple replication threads are being used (slave_parallel_workers > 0). 
                            pt-slave-restart does not know what the GTID event is of the failed transaction of a specific slave thread. 
                            """
                            mysql_conn.turn_off_parallel()
                            time.sleep(0.3)

                            skip_gtid_r = mysql_conn.skip_gtid(gtid_TXID)
                            if skip_gtid_r:
                                logger.info("成功修复了 【%d】 行数据" % count)
                        # 开启只读
                        mysql_conn.set_super_read_only()
                    else:
                        logger.error(f"未更改数据，请查看{db_name}_INFO.log文件以获取错误信息，并进行问题诊断。")
                        # 开启只读
                        mysql_conn.set_super_read_only()
                        break

            # 修复数据后，开启START SLAVE
            mysql_conn.start_slave()
            # 再开启多线程并行复制
            mysql_conn.turn_on_parallel(slave_workers)

        else:
            logger.info('只处理错误号1032和1062同步报错的数据修复。')
            break

    time.sleep(1)
# END while True
##################################################################################################