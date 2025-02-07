set serveroutput on;
declare
 /* *************************
   * oracle 批量增加序列值
   ***************************/
v_sql varchar2(2000);
v_sql_seq varchar2(2000);
v_cnt number;
v_cnt_seq number;
begin

for i in (select * from user_sequences where (SEQUENCE_NAME like 'SEQ_%' OR SEQUENCE_NAME like 'SQ_%')) loop

	if i.max_value<=1000000 then
		v_cnt_seq := 100;
	elsif (i.max_value<=1000000000 and i.max_value>1000000)  then
		v_cnt_seq := 10000;
    elsif (i.max_value<=10000000000000 and i.max_value>1000000000)  then
		v_cnt_seq := 100000;
	else 
		v_cnt_seq := 10000000;
	end if;

	v_sql_seq:='select '||i.SEQUENCE_NAME||'.nextval from dual';
	execute immediate v_sql_seq into v_cnt;
    dbms_output.put_line(v_cnt);
    -------------------
	v_sql:='alter sequence '||i.SEQUENCE_NAME||' increment by '||to_char(v_cnt_seq);
	execute immediate v_sql;
	execute immediate v_sql_seq into v_cnt;
    dbms_output.put_line(v_cnt);
    ------------------------
	v_sql:='alter sequence '||i.SEQUENCE_NAME||' increment by 1';
	execute immediate v_sql;
	execute immediate v_sql_seq into v_cnt;
    dbms_output.put_line(v_cnt);
	dbms_output.put_line(i.SEQUENCE_NAME||'------------');
end loop;
  -- 返回成功
  dbms_output.put_line('ok');
  EXCEPTION
  WHEN OTHERS THEN
  ROLLBACK;
  -- 返回失败
  dbms_output.put_line('flase!!'||sqlerrm||'->'||dbms_utility.format_error_backtrace);
END;
