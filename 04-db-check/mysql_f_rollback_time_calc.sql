'''
f_rollback_time_calc 函数 - 估算 MySQL 已取消事务的回滚时间
https://github.com/hcymysql/RollbackTimeCalc

当你<ctrl+c>或者kill掉一个大事务时,你想知道这个事务需要多久才能回滚完,那么你可以利用RollbackTimeCalc函数得到。
通过show processlist得到线程ID
估算 MySQL 已取消事务的回滚时间
select f_rollback_time_calc(ID,5);
'''
use mysql; 

DELIMITER $$

CREATE FUNCTION f_rollback_time_calc(processID INT, timeInterval INT)

RETURNS VARCHAR(225)

DETERMINISTIC

BEGIN  
  DECLARE RollbackModifiedBeforeInterval INT;  
  DECLARE RollbackModifiedAfterInterval INT;

  DECLARE RollbackPendingRows INT;  
  DECLARE Result varchar(20);

      SELECT trx_rows_modified INTO RollbackModifiedBeforeInterval from information_schema.innodb_trx where trx_mysql_thread_id = processID and trx_state = 'ROLLING BACK';

      do sleep(timeInterval);

      SELECT trx_rows_modified INTO RollbackModifiedAfterInterval from information_schema.innodb_trx where trx_mysql_thread_id = processID and trx_state = 'ROLLING BACK';

      set Result=SEC_TO_TIME(round((RollbackModifiedAfterInterval*timeInterval)/(RollbackModifiedBeforeInterval-RollbackModifiedAfterInterval)));

      SELECT trx_rows_modified INTO RollbackPendingRows from information_schema.innodb_trx where trx_mysql_thread_id = processID and trx_state = 'ROLLING BACK';

      RETURN(CONCAT('回滚估计时间 : ', Result, ' 待回滚行数 ', RollbackPendingRows));

END$$

DELIMITER ;